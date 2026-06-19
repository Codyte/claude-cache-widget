# NAV INDEX
#   Instalador do Claude cache/cost widget.
#   1) PARA qualquer instancia ja rodando (libera o mutex single-instance)
#   2) copia os arquivos para -InstallDir (default ~/.claude/cache-widget)
#   3) detecta o interpretador Python (py/python/python3)
#   4) registra 3 hooks no ~/.claude/settings.json (SessionStart launcher, UserPromptSubmit=busy,
#      Stop=idle) — com backup, idempotente. Em Windows PowerShell 5.1 (sem ConvertFrom-Json
#      -AsHashtable) NAO mexe no arquivo: imprime o bloco JSON p/ voce colar.
#   5) LANCA a nova instancia (a menos que -NoLaunch) -> re-rodar = reinicia o widget.
#   Flags: -InstallDir <path>  -NoHooks (so copia/snippet)  -NoLaunch (nao abre o widget)
[CmdletBinding()] param(
  [string]$InstallDir = (Join-Path $env:USERPROFILE '.claude\cache-widget'),
  [switch]$NoHooks,
  [switch]$NoLaunch
)
$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot
$files = 'cache-widget.ps1','cache-widget.cmd','usage_fetch.py','turn_state.py','prices.json','config.json'

# --- para instancias ja rodando (qualquer pwsh/powershell rodando cache[-_]widget.ps1) ---
function Stop-Widget {
  $procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue |
           Where-Object { $_.CommandLine -and $_.CommandLine -match 'cache[-_]widget\.ps1' }
  foreach($p in $procs){
    try{
      Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
      try{ Wait-Process -Id $p.ProcessId -Timeout 5 -ErrorAction SilentlyContinue }catch{}  # espera liberar o mutex
      Write-Host "[ok] widget anterior parado (PID $($p.ProcessId))" -ForegroundColor Green
    }catch{}
  }
}

# --- lanca a nova instancia (escondida), preferindo pwsh ---
function Start-Widget($ps1){
  if($NoLaunch){ return }
  $launcher = if(Get-Command pwsh -ErrorAction SilentlyContinue){ 'pwsh' } else { 'powershell' }
  Start-Process $launcher -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$ps1
  Write-Host "[ok] widget iniciado ($launcher)" -ForegroundColor Green
}

Stop-Widget

# --- 2) copia ---
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
foreach($f in $files){ Copy-Item (Join-Path $src $f) (Join-Path $InstallDir $f) -Force }
Write-Host "[ok] arquivos copiados -> $InstallDir" -ForegroundColor Green
$ps1Path = Join-Path $InstallDir 'cache-widget.ps1'

# --- 3) python ---
$py = $null
foreach($c in 'py','python','python3'){ if(Get-Command $c -ErrorAction SilentlyContinue){ $py=$c; break } }
if(-not $py){
  Write-Warning "Python nao encontrado no PATH. O widget funciona, mas a secao PLANO/ORCAMENTO (uso 5h/7d + custo API) fica vazia ate instalar Python."
  $py = 'python'
}

# comandos dos hooks (forward slashes; aspas internas escapadas)
$ps1 = $ps1Path -replace '\\','/'
$ts  = (Join-Path $InstallDir 'turn_state.py') -replace '\\','/'
$cmdSession = "powershell -NoProfile -Command `"Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','$ps1'`""
$cmdBusy    = "$py `"$ts`" busy"
$cmdIdle    = "$py `"$ts`" idle"

$settings = Join-Path $env:USERPROFILE '.claude\settings.json'

# --- 4a) fallback (PS 5.1 ou -NoHooks): imprime snippet, depois lanca ---
if($NoHooks -or $PSVersionTable.PSVersion.Major -lt 6){
  if(-not $NoHooks){ Write-Warning "Windows PowerShell 5.1 detectado: nao vou editar settings.json automaticamente." }
  Write-Host "`nAdicione estes hooks em $settings (dentro de `"hooks`"):" -ForegroundColor Cyan
  $snippet = [ordered]@{
    SessionStart     = @(@{ hooks = @(@{ type='command'; command=$cmdSession }) })
    UserPromptSubmit = @(@{ hooks = @(@{ type='command'; command=$cmdBusy }) })
    Stop             = @(@{ hooks = @(@{ type='command'; command=$cmdIdle }) })
  }
  ($snippet | ConvertTo-Json -Depth 6) | Write-Host
  Start-Widget $ps1Path
  return
}

# --- 4b) auto-merge (PS 6+): backup + idempotente ---
if(Test-Path $settings){
  $bak = "$settings.bak-$(Get-Date -Format yyyyMMddHHmmss)"
  Copy-Item $settings $bak -Force
  Write-Host "[ok] backup do settings.json -> $bak" -ForegroundColor Green
  $h = Get-Content $settings -Raw | ConvertFrom-Json -AsHashtable
}else{
  $h = @{}
}
if(-not $h.ContainsKey('hooks') -or $null -eq $h.hooks){ $h.hooks = @{} }

function Add-Hook($evt, $marker, $command){
  if(-not $h.hooks.ContainsKey($evt) -or $null -eq $h.hooks[$evt]){ $h.hooks[$evt] = @() }
  foreach($grp in @($h.hooks[$evt])){                        # idempotente: pula se ja existe
    foreach($hk in @($grp.hooks)){
      if($hk.command -and $hk.command.Contains($marker)){ Write-Host "[skip] $evt ja registrado"; return }
    }
  }
  $h.hooks[$evt] = @($h.hooks[$evt]) + @(@{ hooks = @(@{ type='command'; command=$command }) })
  Write-Host "[ok] hook $evt adicionado" -ForegroundColor Green
}

Add-Hook 'SessionStart'     'cache-widget.ps1' $cmdSession
Add-Hook 'UserPromptSubmit' 'turn_state.py'    $cmdBusy
Add-Hook 'Stop'             'turn_state.py'     $cmdIdle

($h | ConvertTo-Json -Depth 12) | Set-Content $settings -Encoding UTF8
Write-Host "[done] hooks instalados em settings.json" -ForegroundColor Green

Start-Widget $ps1Path
Write-Host "Pronto. Re-rodar o install reinicia o widget; reiniciar o Claude Code tambem o reabre." -ForegroundColor Cyan
