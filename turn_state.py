#!/usr/bin/env python3
# Marca o estado do turno num arquivo, lido pelo cache_widget.ps1.
#   busy  = usuario enviou prompt, Claude esta respondendo (cache sendo construido)
#   idle  = Claude terminou; a partir daqui o relogio de "esfriamento" do cache conta.
# Chamado por hooks: UserPromptSubmit -> busy ; Stop -> idle. NAO escreve stdout (zero token).
import sys, time, os
state = sys.argv[1] if len(sys.argv) > 1 else "idle"
p = os.path.join(os.path.expanduser("~"), ".claude", ".turn_state")
try:
    with open(p, "w", encoding="utf-8") as f:
        f.write(f"{state} {time.time():.0f}")
except Exception:
    pass
