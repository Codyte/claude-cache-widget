# NAV INDEX
#   Widget flutuante always-on-top do "calor do cache" + uso da conversa Claude ativa (refresh 1s).
#   Supre o statusLine que o VSCode extension NAO executa.
#   Relogio de esfriamento: conta a partir do FIM do turno (hook Stop grava ~/.claude/.turn_state).
#     enquanto Claude responde (busy) -> "respondendo", relogio NAO conta cache.
#     idle: agora - T(fim). <4:30 verde quente | 4:30-5 amarelo | >5 vermelho frio. TTL cache=5min.
#   Linha ctx: context window cheio (input ultimo turno / 200k) + modelo + conv id + barra.
#     Badge HANDOFF (right-aligned): contexto ABSOLUTO >= handoff_warn/force_tokens (config) -> trocar sessao.
#   ATUAL DA MENSAGEM: tokens in/cache/out do ultimo turno + barra empilhada por custo $.
#   TOTAL DA CONVERSA: tokens e $ acumulados da conversa inteira + poupanca por cache + barra.
#   PLANO/ORCAMENTO: utilization% 5h/7d (API OAuth) + custo estimado USD (transcripts reais).
#   Fonte: transcript .jsonl mais recente em ~/.claude/projects; tokens REAIS de message.usage.
#   Single-instance (mutex). Arrastavel. Duplo-clique fecha. Auto-fecha se sessao 30min parada.
[CmdletBinding()] param()
$ErrorActionPreference = 'SilentlyContinue'
# Cultura invariante: separador decimal = ponto (evita "$100,982" parecer 100k em pt-BR).
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'ClaudeCacheWidget', [ref]$created)
if (-not $created) { return }

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$projDir   = Join-Path $env:USERPROFILE '.claude\projects'
$statePath = Join-Path $env:USERPROFILE '.claude\.turn_state'

# === config + precos: fonte unica em config.json / prices.json (ao lado deste script) ===
$cfg = $null; $script:PRICES = $null; $script:PRICEDEF = 'opus'
try{ $cfg = Get-Content (Join-Path $PSScriptRoot 'config.json') -Raw | ConvertFrom-Json }catch{}
try{ $pj = Get-Content (Join-Path $PSScriptRoot 'prices.json') -Raw | ConvertFrom-Json
     $script:PRICES = $pj.models; if($pj.default){ $script:PRICEDEF = [string]$pj.default } }catch{}
$CTX_LIMIT      = if($cfg -and $cfg.context_limit){ [int]$cfg.context_limit } else { 200000 }
$CTX_BY_MODEL   = if($cfg){ $cfg.context_limit_by_model } else { $null }
$IDLE_CLOSE_MIN = if($cfg -and $cfg.idle_close_minutes){ [double]$cfg.idle_close_minutes } else { 30 }
$CACHE_TTL      = if($cfg -and $cfg.cache_ttl_seconds){ [int]$cfg.cache_ttl_seconds } else { 300 }
$HANDOFF_WARN   = if($cfg -and $cfg.handoff_warn_tokens){ [int]$cfg.handoff_warn_tokens } else { 120000 }
$HANDOFF_FORCE  = if($cfg -and $cfg.handoff_force_tokens){ [int]$cfg.handoff_force_tokens } else { 140000 }

Add-Type -Namespace WGdi -Name Rgn -MemberDefinition '[System.Runtime.InteropServices.DllImport("gdi32.dll")] public static extern System.IntPtr CreateRoundRectRgn(int l,int t,int r,int b,int w,int h);'

$M = 14   # margem interna
$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'None'; $form.TopMost = $true; $form.ShowInTaskbar = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(26,26,30)
$form.StartPosition = 'Manual'; $form.Width = 300; $form.Height = 332
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Left = $wa.Right - $form.Width - 18; $form.Top = $wa.Bottom - $form.Height - 18
# posicao persistida: restaura se o arquivo existir e estiver dentro da area visivel
$posPath = Join-Path $env:USERPROFILE '.claude\.cache_widget_pos.json'
try{ if(Test-Path $posPath){ $pp=Get-Content $posPath -Raw|ConvertFrom-Json
  $vs=[System.Windows.Forms.SystemInformation]::VirtualScreen; $x=[int]$pp.x; $y=[int]$pp.y
  if($x -ge $vs.Left -and $x -le ($vs.Right-50) -and $y -ge $vs.Top -and $y -le ($vs.Bottom-50)){ $form.Left=$x; $form.Top=$y } } }catch{}
$form.Add_Shown({ $form.Region = [System.Drawing.Region]::FromHrgn([WGdi.Rgn]::CreateRoundRectRgn(0,0,$form.Width+1,$form.Height+1,20,20)) })

$fb  = New-Object System.Drawing.Font('Segoe UI Semibold', 11)
$fs  = New-Object System.Drawing.Font('Segoe UI', 8.5)
$fh  = New-Object System.Drawing.Font('Segoe UI', 7.5, [System.Drawing.FontStyle]::Bold)
$fsm = New-Object System.Drawing.Font('Segoe UI', 7.2)
$cw  = $form.Width - 2*$M

function New-Lbl($y,$h,$font,$color) {
  $l = New-Object System.Windows.Forms.Label
  $l.AutoSize=$false; $l.Width=$cw; $l.Height=$h; $l.Left=$M; $l.Top=$y
  $l.Font=$font; $l.ForeColor=$color; $l.TextAlign='MiddleLeft'; $l.BackColor=[System.Drawing.Color]::Transparent; $l.Text=''
  $form.Controls.Add($l); return $l
}

$gray = [System.Drawing.Color]::FromArgb(150,150,160)
$dim  = [System.Drawing.Color]::FromArgb(110,110,120)
$lblTop   = New-Lbl 12 22 $fb $gray
$lblCtx   = New-Lbl 38 16 $fs ([System.Drawing.Color]::FromArgb(140,140,150))
$lblRates = New-Lbl 54 14 $fsm $dim

# cores in/cache/out (input e cache azul/teal, output vermelho)
$blueIn=[System.Drawing.Color]::FromArgb(52,152,219)
$blueCa=[System.Drawing.Color]::FromArgb(26,188,156)
$redOut=[System.Drawing.Color]::FromArgb(231,76,60)

# barra de context window: trilho (fundo) + preenchimento (largura = pct)
$track = New-Object System.Windows.Forms.Panel
$track.Left=$M; $track.Top=70; $track.Width=$cw; $track.Height=6
$track.BackColor=[System.Drawing.Color]::FromArgb(40,40,46)
$fill = New-Object System.Windows.Forms.Panel
$fill.Left=0; $fill.Top=0; $fill.Width=0; $fill.Height=6
$fill.BackColor=[System.Drawing.Color]::FromArgb(46,204,113)
$track.Controls.Add($fill)
$form.Controls.Add($track)
$script:pct = 0.0

function New-Auto($color,$y,$font=$fs){
  $l=New-Object System.Windows.Forms.Label
  $l.AutoSize=$true; $l.Font=$font; $l.ForeColor=$color
  $l.BackColor=[System.Drawing.Color]::Transparent; $l.Top=$y; $l.Text=''
  $form.Controls.Add($l); return $l
}

# ===== SECCAO: ATUAL DA MENSAGEM =====
$lblTitleAt = New-Lbl 82 12 $fh $dim
$lblTitleAt.Text = 'ATUAL DA MENSAGEM'

$lblIn=New-Auto $blueIn 96; $lblIn.Left=$M
$lblCa=New-Auto $blueCa 96
$lblOut=New-Auto $redOut 96

# barra empilhada por custo ATUAL
$track2 = New-Object System.Windows.Forms.Panel
$track2.Left=$M; $track2.Top=116; $track2.Width=$cw; $track2.Height=6
$track2.BackColor=[System.Drawing.Color]::FromArgb(40,40,46)
$pIn=New-Object System.Windows.Forms.Panel;  $pIn.Top=0;$pIn.Height=6;$pIn.Left=0;$pIn.Width=0;$pIn.BackColor=$blueIn
$pCa=New-Object System.Windows.Forms.Panel;  $pCa.Top=0;$pCa.Height=6;$pCa.Left=0;$pCa.Width=0;$pCa.BackColor=$blueCa
$pOut=New-Object System.Windows.Forms.Panel; $pOut.Top=0;$pOut.Height=6;$pOut.Left=0;$pOut.Width=0;$pOut.BackColor=$redOut
$track2.Controls.AddRange(@($pIn,$pCa,$pOut))
$form.Controls.Add($track2)

# ===== SECCAO: TOTAL DA CONVERSA =====
$lblTitleTot = New-Lbl 128 12 $fh $dim
$lblTitleTot.Text = 'TOTAL DA CONVERSA (ACUMULADO)'

# custos em dolar acima dos labels (fonte menor)
$lblCostIn=New-Auto $blueIn 141 $fsm
$lblCostCa=New-Auto $blueCa 141 $fsm
$lblCostOut=New-Auto $redOut 141 $fsm

# labels textuais de tokens (fonte normal)
$lblTotIn=New-Auto $blueIn 154 $fs; $lblTotIn.Left=$M
$lblTotCa=New-Auto $blueCa 154 $fs
$lblTotOut=New-Auto $redOut 154 $fs

# barra empilhada por custo TOTAL
$track3 = New-Object System.Windows.Forms.Panel
$track3.Left=$M; $track3.Top=173; $track3.Width=$cw; $track3.Height=6
$track3.BackColor=[System.Drawing.Color]::FromArgb(40,40,46)
$pTotIn=New-Object System.Windows.Forms.Panel;  $pTotIn.Top=0;$pTotIn.Height=6;$pTotIn.Left=0;$pTotIn.Width=0;$pTotIn.BackColor=$blueIn
$pTotCa=New-Object System.Windows.Forms.Panel;  $pTotCa.Top=0;$pTotCa.Height=6;$pTotCa.Left=0;$pTotCa.Width=0;$pTotCa.BackColor=$blueCa
$pTotOut=New-Object System.Windows.Forms.Panel; $pTotOut.Top=0;$pTotOut.Height=6;$pTotOut.Left=0;$pTotOut.Width=0;$pTotOut.BackColor=$redOut
$track3.Controls.AddRange(@($pTotIn,$pTotCa,$pTotOut))
$form.Controls.Add($track3)

# ===== seccao USAGE (uso do plano: 5h / 7d) =====
$div = New-Object System.Windows.Forms.Panel
$div.Left=$M; $div.Top=189; $div.Width=$cw; $div.Height=1
$div.BackColor=[System.Drawing.Color]::FromArgb(45,45,52); $form.Controls.Add($div)

$lblUsage = New-Lbl 195 14 $fh ([System.Drawing.Color]::FromArgb(120,120,130)); $lblUsage.Text="PLANO / OR$([char]0xC7)AMENTO"

function New-Right($y,$h,$font,$color){
  $l=New-Object System.Windows.Forms.Label
  $l.AutoSize=$false; $l.Width=$cw; $l.Height=$h; $l.Left=$M; $l.Top=$y
  $l.Font=$font; $l.ForeColor=$color; $l.TextAlign='MiddleRight'; $l.BackColor=[System.Drawing.Color]::Transparent
  $form.Controls.Add($l); return $l
}
$lit = [System.Drawing.Color]::FromArgb(170,170,180)

# overlays right-aligned nas linhas de titulo: cache-hit% (ATUAL) e burn $/min (TOTAL)
$hitCol=[System.Drawing.Color]::FromArgb(120,180,160)
$lblHit  = New-Right 82  12 $fh $hitCol
$lblBurn = New-Right 128 12 $fh $hitCol
# badge de handoff na linha de contexto (right-aligned): warn (zona amarela) / force (vermelha)
$lblHandoff = New-Right 38 16 $fh $hitCol

# Session (5h)
$lblS    = New-Lbl   212 16 $fs $lit; $lblS.Text='Session (5hr)'
$lblSpct = New-Right 212 16 $fs $lit
$trackS = New-Object System.Windows.Forms.Panel
$trackS.Left=$M;$trackS.Top=232;$trackS.Width=$cw;$trackS.Height=6;$trackS.BackColor=[System.Drawing.Color]::FromArgb(40,40,46)
$fillS = New-Object System.Windows.Forms.Panel; $fillS.Left=0;$fillS.Top=0;$fillS.Height=6;$fillS.Width=0
$trackS.Controls.Add($fillS); $form.Controls.Add($trackS)
$lblSr = New-Lbl 240 13 $fsm $dim

# Weekly (7d)
$lblW    = New-Lbl   256 16 $fs $lit; $lblW.Text='Weekly (7 day)'
$lblWpct = New-Right 256 16 $fs $lit
$trackW = New-Object System.Windows.Forms.Panel
$trackW.Left=$M;$trackW.Top=276;$trackW.Width=$cw;$trackW.Height=6;$trackW.BackColor=[System.Drawing.Color]::FromArgb(40,40,46)
$fillW = New-Object System.Windows.Forms.Panel; $fillW.Left=0;$fillW.Top=0;$fillW.Height=6;$fillW.Width=0
$trackW.Controls.Add($fillW); $form.Controls.Add($trackW)
$lblWr = New-Lbl 284 13 $fsm $dim

function UsageColor($p){ if($p -lt 70){[System.Drawing.Color]::FromArgb(46,204,113)}elseif($p -lt 90){[System.Drawing.Color]::FromArgb(230,126,34)}else{[System.Drawing.Color]::FromArgb(231,76,60)} }
function ResetTxt($iso){
  try{ $t=[datetimeoffset]::Parse($iso); $d=$t-[datetimeoffset]::Now
    if($d.TotalSeconds -le 0){return 'reinicia agora'}
    if($d.TotalDays -ge 1){return ('Reinicia em {0}d' -f [math]::Floor($d.TotalDays))}
    if($d.TotalHours -ge 1){return ('Reinicia em {0}h' -f [math]::Floor($d.TotalHours))}
    return ('Reinicia em {0}m' -f [math]::Floor($d.TotalMinutes)) }catch{return ''}
}
$script:usageTick = 0
$usageCache = Join-Path $env:USERPROFILE '.claude\.usage_cache.json'
# usage_fetch.py mora ao lado deste script (portavel: sem caminho hardcoded por usuario)
$usageFetch = Join-Path $PSScriptRoot 'usage_fetch.py'
# detecta o interpretador Python: launcher 'py' -> 'python' -> 'python3' (primeiro do PATH).
# $null se nenhum existir -> a seccao PLANO/ORCAMENTO fica vazia, resto do widget funciona.
$pythonExe = $null
foreach($cand in 'py','python','python3'){ if(Get-Command $cand -ErrorAction SilentlyContinue){ $pythonExe=$cand; break } }

# arrastar / fechar
$script:drag=$false;$script:dx=0;$script:dy=0
$down={$script:drag=$true;$script:dx=$_.X;$script:dy=$_.Y}
$move={if($script:drag){$form.Left+=$_.X-$script:dx;$form.Top+=$_.Y-$script:dy}}
$up={ if($script:drag){ try{ (@{x=$form.Left;y=$form.Top}|ConvertTo-Json -Compress)|Set-Content $posPath -Encoding ASCII }catch{} }; $script:drag=$false }
foreach($c in @($form,$lblTop,$lblCtx,$lblRates,$lblTitleAt,$lblHit,$lblIn,$lblCa,$lblOut,$lblTitleTot,$lblBurn,$lblCostIn,$lblCostCa,$lblCostOut,$lblTotIn,$lblTotCa,$lblTotOut,$lblUsage,$lblS,$lblW,$lblSr,$lblWr)){ $c.Add_MouseDown($down);$c.Add_MouseMove($move);$c.Add_MouseUp($up);$c.Add_DoubleClick({$form.Close()}) }

# menu de contexto (botao-direito): acoes rapidas, tudo local (zero token)
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.BackColor=[System.Drawing.Color]::FromArgb(32,32,38); $menu.ForeColor=$lit; $menu.ShowImageMargin=$false
[void]$menu.Items.Add('Copiar resumo (custo/tokens)',$null,{ try{ if($script:summary){ [System.Windows.Forms.Clipboard]::SetText($script:summary) } }catch{} })
[void]$menu.Items.Add('Abrir transcript ativo',$null,{ try{ if($script:tPath -and (Test-Path $script:tPath)){ Start-Process notepad.exe $script:tPath } }catch{} })
[void]$menu.Items.Add('Abrir pasta do projeto',$null,{ try{ if($script:tPath -and (Test-Path $script:tPath)){ Start-Process explorer.exe (Split-Path $script:tPath -Parent) } }catch{} })
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
[void]$menu.Items.Add('Fechar widget',$null,{ $form.Close() })
$form.ContextMenuStrip=$menu
foreach($c in $form.Controls){ $c.ContextMenuStrip=$menu }

function Fmt($n){
  if($n -ge 1000000){ return ('{0:0.0}M' -f ($n/1000000)) }
  if($n -ge 1000){ return ('{0:0.0}k' -f ($n/1000)) }
  return [string][int]$n
}

# tokens da conversa (leitura INCREMENTAL: so os bytes novos, mantem totais acumulados)
$script:tPath='';$script:tOffset=0;$script:pending='';$script:model=''
$script:busy=$false   # guarda de reentrancia do timer
$script:scanTick=0;$script:curF=$null   # scan recursivo throttled: full a cada 5 ticks, re-stat barato nos demais
$script:summary=''                      # resumo pronto p/ o menu botao-direito (copiar)
# ultimo turno (ATUAL)
$script:in=0;$script:cr=0;$script:cc=0;$script:out=0;$script:lastPrompt=0
# acumulado (TOTAL)
$script:totIn=0;$script:totCr=0;$script:totCc=0;$script:totOut=0
# janela temporal da conversa (para burn rate)
$script:firstTs=$null;$script:lastTs=$null

# Le SO o que foi anexado ao transcript desde a ultima leitura (offset em bytes).
# Evita reparsear o arquivo inteiro (50MB+) a cada tick -> nada de travar a UI.
function Update-Totals($path,$len){
  if($script:tPath -ne $path){            # nova conversa -> zera estado
    $script:tPath=$path;$script:tOffset=0;$script:pending=''
    $script:totIn=0;$script:totCr=0;$script:totCc=0;$script:totOut=0
    $script:in=0;$script:cr=0;$script:cc=0;$script:out=0;$script:lastPrompt=0
    $script:firstTs=$null;$script:lastTs=$null
  }
  if($len -lt $script:tOffset){ $script:tOffset=0;$script:pending='' }  # arquivo truncado/rotacionado
  if($len -le $script:tOffset){ return }                               # nada novo
  $chunk=''
  try{
    $fs=[System.IO.File]::Open($path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
    [void]$fs.Seek($script:tOffset,[System.IO.SeekOrigin]::Begin)
    $sr=New-Object System.IO.StreamReader($fs)
    $chunk=$sr.ReadToEnd()
    $script:tOffset=$fs.Position
    $sr.Close();$fs.Close()
  }catch{ return }
  $data=$script:pending+$chunk
  $idx=$data.LastIndexOf("`n")
  if($idx -lt 0){ $script:pending=$data; return }   # ainda sem linha completa
  $script:pending=$data.Substring($idx+1)           # guarda a linha parcial p/ a proxima leitura
  foreach($l in ($data.Substring(0,$idx) -split "`n")){
    if($l -notlike '*"usage"*'){ continue }
    try{ $obj=$l|ConvertFrom-Json; if($obj.isSidechain){ continue }   # ignora turnos de sub-agente (nao inflar total)
      $u=$obj.message.usage
      if($obj.message.model){ $script:model=$obj.message.model }
      if($obj.timestamp){ try{ $dt=[datetimeoffset]::Parse($obj.timestamp); if(-not $script:firstTs){$script:firstTs=$dt}; $script:lastTs=$dt }catch{} }
      if($u){
        $i=[int]$u.input_tokens; $r=[int]$u.cache_read_input_tokens; $w=[int]$u.cache_creation_input_tokens; $o=[int]$u.output_tokens
        $script:totIn+=$i;$script:totCr+=$r;$script:totCc+=$w;$script:totOut+=$o
        $script:in=$i;$script:cr=$r;$script:cc=$w;$script:out=$o;$script:lastPrompt=$i+$r+$w } }catch{}
  }
}

# preco real por MTok (input/output/cache-write/cache-read) -> barra por custo $ real
function Get-Price($m){
  $m=([string]$m).ToLower()
  if($script:PRICES){
    foreach($key in $script:PRICES.PSObject.Properties.Name){
      if($m -match [regex]::Escape($key)){ $p=$script:PRICES.$key; return @{ in=[double]$p.in; out=[double]$p.out; cw=[double]$p.cw; cr=[double]$p.cr } }
    }
    $d=$script:PRICES.$($script:PRICEDEF); if($d){ return @{ in=[double]$d.in; out=[double]$d.out; cw=[double]$d.cw; cr=[double]$d.cr } }
  }
  return @{ in=15.0; out=75.0; cw=18.75; cr=1.50 }   # fallback Opus (prices.json ausente)
}

$green=[System.Drawing.Color]::FromArgb(46,204,113)
$yellow=[System.Drawing.Color]::FromArgb(241,196,15)
$red=[System.Drawing.Color]::FromArgb(231,76,60)
$cyan=[System.Drawing.Color]::FromArgb(52,152,219)

$timer=New-Object System.Windows.Forms.Timer; $timer.Interval=1000
$timer.Add_Tick({
 if($script:busy){ return }   # tick anterior ainda rodando -> nao empilha (evita freeze)
 $script:busy=$true
 try{
  # scan recursivo (acha o transcript mais novo) so a cada 5 ticks; nos demais, re-stat barato do atual
  if($script:scanTick -le 0 -or -not $script:curF){
    $script:curF = Get-ChildItem $projDir -Recurse -Filter *.jsonl -File -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $script:scanTick = 5
  } elseif($script:curF){
    $fi = Get-Item $script:curF.FullName -ErrorAction SilentlyContinue   # 1 stat, sub-ms
    if($fi){ $script:curF = $fi }
  }
  $script:scanTick--
  $f = $script:curF
  if(-not $f){ $lblTop.ForeColor=$gray;$lblTop.Text='(sem sessao)';$lblCtx.Text='';$lblRates.Text='';$lblIn.Text='';$lblCa.Text='';$lblOut.Text='';$fill.Width=0;return }
  if(((Get-Date)-$f.LastWriteTime).TotalMinutes -gt $IDLE_CLOSE_MIN){ $timer.Stop(); $form.Close(); return }

  # leitura incremental: so processa os bytes novos do transcript
  Update-Totals $f.FullName $f.Length

  # estado do turno (busy/idle) a partir do marcador; fallback = mtime do transcript
  $st='idle'; $ts=$f.LastWriteTime
  if(Test-Path $statePath){
    $parts=(Get-Content $statePath -Raw).Trim() -split '\s+'
    if($parts.Count -ge 2){ $st=$parts[0]; $ts=[System.DateTimeOffset]::FromUnixTimeSeconds([long]$parts[1]).LocalDateTime }
  }
  $sec=[int]((Get-Date)-$ts).TotalSeconds; if($sec -lt 0){$sec=0}
  $clk='{0}:{1:00}' -f [math]::Floor($sec/60),($sec%60)

  if($st -eq 'busy'){
    $lblTop.ForeColor=$cyan; $lblTop.Text=([char]0x25CF)+" respondendo  $clk"
  } else {
    if($sec -lt ($CACHE_TTL-30)){$lblTop.ForeColor=$green;$state='quente'}
    elseif($sec -lt $CACHE_TTL){$lblTop.ForeColor=$yellow;$state='esfriando'}
    else{$lblTop.ForeColor=$red;$state='frio'}
    $lblTop.Text=([char]0x25CF)+" cache $state $clk"
  }

  # nome do modelo + id da conversa (do nome do arquivo)
  $convId=''; if($script:tPath -match '([^\\/]+)\.jsonl$'){ $convId=$Matches[1].Substring(0,[math]::Min(8,$Matches[1].Length)) }
  $modelNameDisplay = if($script:model -match 'opus'){'Opus'}elseif($script:model -match 'sonnet'){'Sonnet'}elseif($script:model -match 'haiku'){'Haiku'}else{'?'}

  $ctxLim = $CTX_LIMIT
  if($CTX_BY_MODEL){ foreach($k in $CTX_BY_MODEL.PSObject.Properties.Name){ if($script:model -match [regex]::Escape($k)){ $ctxLim=[int]$CTX_BY_MODEL.$k; break } } }
  $script:pct = if($ctxLim){ [math]::Min(1.0, $script:lastPrompt/$ctxLim) } else {0}
  $lblCtx.Text = 'context  ' + (Fmt $script:lastPrompt) + ' / ' + (Fmt $ctxLim) + '   ' + ('{0:0}%' -f ($script:pct*100)) + "  [$modelNameDisplay] ($convId)"
  if($script:pct -lt 0.70){ $fill.BackColor=$green } elseif($script:pct -lt 0.90){ $fill.BackColor=$yellow } else { $fill.BackColor=$red }
  $fill.Width = [int]($track.Width * $script:pct)

  # sinal de HANDOFF por contexto ABSOLUTO (nao % da janela): vide analise de break-even do reboot.
  # warn = zona amarela (faca no proximo boundary de tarefa); force = vermelha (handoff ja).
  if($script:lastPrompt -ge $HANDOFF_FORCE){ $lblHandoff.ForeColor=$red; $lblHandoff.Text=([char]0x21BB)+' handoff' }
  elseif($script:lastPrompt -ge $HANDOFF_WARN){ $lblHandoff.ForeColor=$yellow; $lblHandoff.Text=([char]0x21BB)+' handoff?' }
  else{ $lblHandoff.Text='' }

  # precos / taxas por milhao
  $p=Get-Price $script:model
  $lblRates.Text = 'Taxas/M: in: $' + $p.in + ' | cache: $' + $p.cr + ' | out: $' + $p.out

  # ===== 1. ATUAL DA MENSAGEM =====
  $curCache = $script:cr + $script:cc
  # cache-hit% = fracao do prompt servida do cache read (quente). Alto = barato.
  $hit = if($script:lastPrompt -gt 0){ 100.0*$script:cr/$script:lastPrompt } else {0}
  $lblHit.ForeColor = if($hit -ge 70){$green}elseif($hit -ge 40){$yellow}else{$hitCol}
  $lblHit.Text = if($script:lastPrompt -gt 0){ 'cache-hit {0:0}%' -f $hit } else { '' }
  $lblIn.Text  = 'input: '  + (Fmt $script:in)
  $lblCa.Text  = '  |  cache: '  + (Fmt $curCache)
  $lblOut.Text = '  |  output: ' + (Fmt $script:out)
  $lblCa.Left  = $lblIn.Right
  $lblOut.Left = $lblCa.Right

  # barra empilhada por custo ATUAL (cache read e write com precos distintos)
  $wi=($script:in/1000000)*$p.in; $wc=($script:cr/1000000)*$p.cr + ($script:cc/1000000)*$p.cw; $wo=($script:out/1000000)*$p.out
  $tot=$wi+$wc+$wo; if($tot -le 0){$tot=1}
  $xi=[int]($cw*$wi/$tot); $xc=[int]($cw*$wc/$tot)
  $pIn.Left=0;       $pIn.Width=$xi
  $pCa.Left=$xi;     $pCa.Width=$xc
  $pOut.Left=$xi+$xc;$pOut.Width=[math]::Max(0,$cw-$xi-$xc)

  # ===== 2. TOTAL DA CONVERSA =====
  $totCache = $script:totCr + $script:totCc
  $wTi=($script:totIn/1000000)*$p.in
  $wTc=($script:totCr/1000000)*$p.cr + ($script:totCc/1000000)*$p.cw
  $wTo=($script:totOut/1000000)*$p.out
  $convCost = $wTi + $wTc + $wTo
  # poupanca: cache read pago a cr em vez de in
  $convSaved = ($script:totCr/1000000)*($p.in - $p.cr)
  $lblTitleTot.Text = 'TOTAL CONVERSA ($' + ('{0:F4}' -f $convCost) + ' | POUPADO: $' + ('{0:F4}' -f $convSaved) + ')'

  # burn rate: custo medio $/min ao longo da janela da conversa (API-equiv)
  $burn = 0.0
  if($script:firstTs -and $script:lastTs){
    $durMin = ($script:lastTs - $script:firstTs).TotalMinutes
    if($durMin -gt 0.1){ $burn = $convCost / $durMin }
  }
  $lblBurn.Text = if($burn -gt 0){ '${0:N4}/min' -f $burn } else { '' }
  $msgCost = $wi + $wc + $wo   # custo do turno atual (usado tambem no resumo do menu)

  $lblTotIn.Text  = 'input: '  + (Fmt $script:totIn)
  $lblTotCa.Text  = '  |  cache: '  + (Fmt $totCache)
  $lblTotOut.Text = '  |  output: ' + (Fmt $script:totOut)
  $lblTotCa.Left  = $lblTotIn.Right
  $lblTotOut.Left = $lblTotCa.Right

  $lblCostIn.Text  = '$' + ('{0:F5}' -f $wTi)
  $lblCostCa.Text  = '$' + ('{0:F5}' -f $wTc)
  $lblCostOut.Text = '$' + ('{0:F5}' -f $wTo)
  $lblCostIn.Left  = $lblTotIn.Left
  $lblCostCa.Left  = $lblTotCa.Left + 12
  $lblCostOut.Left = $lblTotOut.Left + 12

  $totT=$wTi+$wTc+$wTo; if($totT -le 0){$totT=1}
  $xTi=[int]($cw*$wTi/$totT); $xTc=[int]($cw*$wTc/$totT)
  $pTotIn.Left=0;         $pTotIn.Width=$xTi
  $pTotCa.Left=$xTi;      $pTotCa.Width=$xTc
  $pTotOut.Left=$xTi+$xTc;$pTotOut.Width=[math]::Max(0,$cw-$xTi-$xTc)

  # ===== USAGE do plano: fetch a cada 60s, render do cache todo tick =====
  if($script:usageTick -le 0){
    if($pythonExe -and (Test-Path $usageFetch)){ Start-Process $pythonExe -WindowStyle Hidden -ArgumentList @($usageFetch) -ErrorAction SilentlyContinue }
    $script:usageTick = 60
  }
  $script:usageTick--

  if(Test-Path $usageCache){
    try{
      $u = Get-Content $usageCache -Raw | ConvertFrom-Json
      $c5 = if($u.cost_5h_usd -ne $null){' (' + [char]0x2248 + '${0:N0} API)' -f [double]$u.cost_5h_usd}else{''}
      $c7 = if($u.cost_7d_usd -ne $null){' (' + [char]0x2248 + '${0:N0} API)' -f [double]$u.cost_7d_usd}else{''}
      # so atualiza cada janela quando o % veio mesmo; senao mantem o ultimo (nao "some")
      if($u.s_pct -ne $null){
        $sp = [double]$u.s_pct
        $lblS.Text = 'Session (5hr)   ' + ('{0:0}%' -f $sp) + $c5
        $fillS.BackColor = UsageColor $sp; $fillS.Width = [int]($trackS.Width * [math]::Min(100,$sp)/100)
        $lblSr.Text = ResetTxt $u.s_reset
      }
      if($u.w_pct -ne $null){
        $wp = [double]$u.w_pct
        $lblW.Text = 'Weekly (7 day)   ' + ('{0:0}%' -f $wp) + $c7
        $fillW.BackColor = UsageColor $wp; $fillW.Width = [int]($trackW.Width * [math]::Min(100,$wp)/100)
        $lblWr.Text = ResetTxt $u.w_reset
      }
    }catch{}
  }

  # ===== resumo auto-explicativo p/ o menu botao-direito (espelha tudo que esta visivel) =====
  $ttl = [math]::Max(0, $CACHE_TTL - $sec); $ttlClk = '{0}:{1:00}' -f [math]::Floor($ttl/60),($ttl%60)
  $cacheStatus =
    if($st -eq 'busy'){ "RESPONDENDO - turno em andamento ($clk decorridos); relogio do cache so conta apos terminar" }
    elseif($sec -lt ($CACHE_TTL-30)){ "QUENTE - cache com ~90% desconto ATIVO; esfria em $ttlClk. Mandar prompt agora aproveita o cache barato" }
    elseif($sec -lt $CACHE_TTL){ "ESFRIANDO - faltam $ttlClk p/ expirar; resubmeta JA p/ nao perder o cache quente" }
    else{ "FRIO - cache expirou (idle $clk); o proximo prompt paga input cheio sem desconto" }
  $handoffMsg =
    if($script:lastPrompt -ge $HANDOFF_FORCE){ "HANDOFF AGORA - contexto $(Fmt $script:lastPrompt) >= $(Fmt $HANDOFF_FORCE); custo/turno e atencao degradam, perto da parede de $(Fmt $ctxLim). Handoff independente de tarefa." }
    elseif($script:lastPrompt -ge $HANDOFF_WARN){ "ZONA AMARELA - contexto $(Fmt $script:lastPrompt) >= $(Fmt $HANDOFF_WARN); faca handoff no PROXIMO fim de tarefa (nao no meio). Sweet spot." }
    else{ "OK - contexto $(Fmt $script:lastPrompt) < $(Fmt $HANDOFF_WARN); continuar e mais barato que rebootar (cache barato vence a re-leitura)." }
  $planSession = if($lblS.Text){ $lblS.Text + '  ' + $lblSr.Text } else { '(sem dados de plano ainda)' }
  $planWeekly  = if($lblW.Text){ $lblW.Text + '  ' + $lblWr.Text } else { '' }

  $script:summary = @"
================= Claude cache / cost widget =============
Capturado em : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Modelo       : $modelNameDisplay ($script:model)
Conversa     : $convId

[ CACHE ]  TTL de 5 min; enquanto "quente" o reuso de contexto custa ~90% menos.
  $cacheStatus

[ CONTEXT WINDOW ]  quanto do limite o proximo prompt ja ocupa.
  $(Fmt $script:lastPrompt) de $(Fmt $ctxLim) tokens = $('{0:0}%' -f ($script:pct*100)) cheio

[ HANDOFF ]  quando trocar de sessao (gatilho em tokens ABSOLUTOS, nao % da janela).
  $handoffMsg

[ PRECOS ]  USD por 1.000.000 de tokens ($modelNameDisplay).
  input novo `$$($p.in)   cache-read `$$($p.cr)   cache-write `$$($p.cw)   output `$$($p.out)

[ ULTIMA MENSAGEM ]  custo so do turno atual.
  input novo  : $(Fmt $script:in) tok  -> `$$('{0:F5}' -f $wi)
  cache       : $(Fmt $curCache) tok  -> `$$('{0:F5}' -f $wc)   (hit $('{0:0}%' -f $hit) = % do prompt servido do cache barato)
  output      : $(Fmt $script:out) tok  -> `$$('{0:F5}' -f $wo)
  CUSTO DO TURNO: `$$('{0:F5}' -f $msgCost)

[ CONVERSA INTEIRA ]  acumulado desde o inicio da sessao.
  input novo  : $(Fmt $script:totIn) tok  -> `$$('{0:F4}' -f $wTi)
  cache       : $(Fmt $totCache) tok  -> `$$('{0:F4}' -f $wTc)
  output      : $(Fmt $script:totOut) tok  -> `$$('{0:F4}' -f $wTo)
  CUSTO TOTAL : `$$('{0:F4}' -f $convCost)
  POUPADO pelo cache: `$$('{0:F4}' -f $convSaved)  (vs pagar tudo como input novo)
  BURN RATE  : `$$('{0:N4}' -f $burn)/min  (custo medio na janela da conversa)

[ PLANO / ORCAMENTO ]  uso das janelas do plano (% e custo API-equivalente).
  $planSession
  $planWeekly
==========================================================
"@
 }catch{} finally{ $script:busy=$false }
})
$timer.Start()
$form.Add_FormClosed({ $timer.Stop(); try{ $mutex.ReleaseMutex() }catch{}; try{ $mutex.Dispose() }catch{} })
[System.Windows.Forms.Application]::Run($form)
