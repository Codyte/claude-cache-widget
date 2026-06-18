#!/usr/bin/env python3
# NAV INDEX
#   Grava ~/.claude/.usage_cache.json com 2 fontes:
#   (1) Plano (rate limit 5h/7d): API OAuth do Claude -> utilization% + resets_at. Token fresco
#       relido do .credentials.json a cada chamada (o CLI o mantem atualizado).
#   (2) Custo estimado em USD (5h/7d): somado dos transcripts reais em ~/.claude/projects usando
#       os tokens REAIS do campo message.usage (input/cache_read/cache_creation/output) x preco do
#       modelo de cada linha, atribuido pelo timestamp da linha. Bem mais preciso que estimar len/4.
#   Roda a cada ~60s, disparado pelo cache_widget.ps1. Qualquer falha = nao mexe no cache.
import json, os, glob, time, urllib.request
from datetime import datetime, timezone

HOME = os.path.expanduser("~")
CRED = os.path.join(HOME, ".claude", ".credentials.json")
PROJ = os.path.join(HOME, ".claude", "projects")
OUT  = os.path.join(HOME, ".claude", ".usage_cache.json")
URL  = "https://api.anthropic.com/api/oauth/usage"

# precos: fonte unica em prices.json (ao lado deste script). Fallback embutido se ausente.
_PRICES_FALLBACK = {
    "opus":   {"in": 15.0, "cr": 1.50, "cw": 18.75, "out": 75.0},
    "sonnet": {"in": 3.0,  "cr": 0.30, "cw": 3.75,  "out": 15.0},
    "haiku":  {"in": 1.0,  "cr": 0.10, "cw": 1.25,  "out": 5.0},
}

def _load_price_table():
    try:
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "prices.json")
        with open(path, encoding="utf-8") as f:
            pj = json.load(f)
        models = pj.get("models") or {}
        if models:
            return models, pj.get("default", "opus")
    except Exception:
        pass
    return _PRICES_FALLBACK, "opus"

_PRICE_TABLE, _PRICE_DEFAULT = _load_price_table()

# preco por TOKEN (USD): in / cache-read / cache-write / out. Match por substring do modelo.
def model_prices(model):
    m = str(model or "").lower()
    row = next((v for k, v in _PRICE_TABLE.items() if k in m), None)
    if row is None:
        row = _PRICE_TABLE.get(_PRICE_DEFAULT) or next(iter(_PRICE_TABLE.values()))
    return {"in": row["in"]/1e6, "cr": row["cr"]/1e6, "cw": row["cw"]/1e6, "out": row["out"]/1e6}

def parse_ts(line_obj):
    ts = line_obj.get("timestamp")
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
    except Exception:
        return None

def fetch_oauth():
    """Plano: utilization% + reset das janelas 5h/7d via API OAuth. Falha -> {}."""
    try:
        tok = json.load(open(CRED, encoding="utf-8"))["claudeAiOauth"]["accessToken"]
    except Exception:
        return {}
    H = {"Authorization": f"Bearer {tok}",
         "anthropic-beta": "oauth-2025-04-20",
         "anthropic-version": "2023-06-01",
         "User-Agent": "claude-cli"}
    try:
        r = urllib.request.urlopen(urllib.request.Request(URL, headers=H), timeout=15)
        d = json.loads(r.read().decode())
    except Exception:
        return {}
    fh = d.get("five_hour") or {}
    sd = d.get("seven_day") or {}
    return {
        "s_pct":   fh.get("utilization"),
        "s_reset": fh.get("resets_at"),
        "w_pct":   sd.get("utilization"),
        "w_reset": sd.get("resets_at"),
    }

def estimate_costs():
    """Custo USD nas ultimas 5h e 7d, a partir dos tokens reais dos transcripts."""
    now = time.time()
    cut5 = now - 5 * 3600
    cut7 = now - 7 * 24 * 3600
    cost5 = cost7 = 0.0
    for path in glob.glob(os.path.join(PROJ, "**", "*.jsonl"), recursive=True):
        try:
            # pula arquivos sem atividade na janela maior (rapido)
            if os.path.getmtime(path) < cut7:
                continue
            with open(path, "r", encoding="utf-8") as f:
                for line in f:
                    if '"usage"' not in line:
                        continue
                    try:
                        obj = json.loads(line)
                        if obj.get("isSidechain"):   # ignora turnos de sub-agente
                            continue
                        u = (obj.get("message") or {}).get("usage")
                        if not u:
                            continue
                        ts = parse_ts(obj)
                        if ts is None or ts < cut7:
                            continue
                        p = model_prices((obj.get("message") or {}).get("model"))
                        c = (int(u.get("input_tokens") or 0) * p["in"]
                             + int(u.get("cache_read_input_tokens") or 0) * p["cr"]
                             + int(u.get("cache_creation_input_tokens") or 0) * p["cw"]
                             + int(u.get("output_tokens") or 0) * p["out"])
                        cost7 += c
                        if ts >= cut5:
                            cost5 += c
                    except Exception:
                        continue
        except Exception:
            continue
    return round(cost5, 4), round(cost7, 4)

def load_prev():
    """Ultimo cache bom (p/ preservar plano quando o OAuth falha/rate-limita)."""
    try:
        return json.load(open(OUT, encoding="utf-8"))
    except Exception:
        return {}

def main():
    prev = load_prev()
    out = dict(prev)            # parte do ultimo bom; so sobrescreve o que vier fresco
    out["at"] = time.time()
    # plano (OAuth): o endpoint /usage e' rate-limited no servidor (429 sob polling de 60s).
    # Dados de plano mudam devagar -> consulta no maximo a cada 5min; se ja temos plano e
    # estamos dentro da janela, nem chama a rede. Em falha/429 preserva o ultimo % e reset.
    have_plan = prev.get("s_pct") is not None
    since_ok  = time.time() - prev.get("oauth_at", 0)    # do ultimo sucesso
    since_try = time.time() - prev.get("oauth_try", 0)   # da ultima tentativa (sucesso ou nao)
    # com plano: renova a cada 5min. Sem plano (recuperando): tenta a cada 2min (nao martela o 429).
    if (have_plan and since_ok >= 300) or ((not have_plan) and since_try >= 120):
        out["oauth_try"] = time.time()
        oauth = fetch_oauth()
        if any(oauth.get(k) is not None for k in ("s_pct", "w_pct")):
            for k in ("s_pct", "s_reset", "w_pct", "w_reset"):
                v = oauth.get(k)
                if v is not None:
                    out[k] = v
            out["oauth_at"] = time.time()
        # se falhou (429/rede): nao mexe -> mantem plano anterior, reenvia apos o backoff
    try:
        c5, c7 = estimate_costs()
        out["cost_5h_usd"] = c5
        out["cost_7d_usd"] = c7
    except Exception:
        pass
    # so grava se temos algo util (evita zerar cache em falha total)
    if len(out) <= 1:
        return
    # escrita atomica: grava no .tmp e troca de uma vez (sem janela de arquivo truncado).
    try:
        tmp = OUT + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(out, f)
        os.replace(tmp, OUT)
    except Exception:
        pass

if __name__ == "__main__":
    main()
