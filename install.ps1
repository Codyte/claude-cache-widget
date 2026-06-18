# NAV INDEX
#   Instalador do Claude cache/cost widget.
#   1) copia os arquivos para -InstallDir (default ~/.claude/cache-widget)
#   2) detecta o interpretador Python (py/python/python3)
#   3) registra 3 hooks no ~/.claude/settings.json (SessionStart launcher, UserPromptSubmit=busy,
#      Stop=idle) — com backup, idempotente. Em Windows PowerShell 5.1 (sem ConvertFrom-Json
#      -AsHashtable) NAO mexe no arquivo: imprime o bloco JSON p/ voce colar.
#   Flags: -InstallDir <path>  -NoHooks (so copia + imprime snippet)
[CmdletBinding()] param(
  [string]$InstallDir = (Join-Path $env:USERPROFILE '.claude\cache-widget'),
  [switch]$NoHooks
)
$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot
$files = 'cache-widget.ps1','cache-widget.cmd','usage_fetch.py','turn_state.py','prices.json','config.json'

# 1) copia
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
foreach($f in $files){ Copy-Item (Join-Path $src $f) (Join-Path $InstallDir $f) -Force }
Write-Host "[ok] arquivos copiados -> $InstallDir" -ForegroundColor Green

# 2) python
$py = $null
foreach($c in 'py','python','python3'){ if(Get-Command $c -ErrorAction SilentlyContinue){ $py=$c; break } }
if(-not $py){
  Write-Warning "Python nao encontrado no PATH. O widget funciona, mas a secao PLANO/ORCAMENTO (uso 5h/7d + custo API) fica vazia ate instalar Python."
  $py = 'python'
}

# comandos dos hooks (forward slashes; aspas internas escapadas)
$ps1 = (Join-Path $InstallDir 'cache-widget.ps1') -replace '\\','/'
$ts  = (Join-Path $InstallDir 'turn_state.py')    -replace '\\','/'
$cmdSession = "powershell -NoProfile -Command `"Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','$ps1'`""
$cmdBusy    = "$py `"$ts`" busy"
$cmdIdle    = "$py `"$ts`" idle"

$settings = Join-Path $env:USERPROFILE '.claude\settings.json'

# fallback (PS 5.1 ou -NoHooks): imprime snippet p/ colar manualmente
if($NoHooks -or $PSVersionTable.PSVersion.Major -lt 6){
  if(-not $NoHooks){ Write-Warning "Windows PowerShell 5.1 detectado: nao vou editar settings.json automaticamente." }
  Write-Host "`nAdicione estes hooks em $settings (dentro de `"hooks`"):" -ForegroundColor Cyan
  $snippet = [ordered]@{
    SessionStart      = @(@{ hooks = @(@{ type='command'; command=$cmdSession }) })
    UserPromptSubmit  = @(@{ hooks = @(@{ type='command'; command=$cmdBusy }) })
    Stop              = @(@{ hooks = @(@{ type='command'; command=$cmdIdle }) })
  }
  ($snippet | ConvertTo-Json -Depth 6) | Write-Host
  Write-Host "`nDepois reinicie o Claude Code (ou rode $InstallDir/cache-widget.cmd para abrir agora)." -ForegroundColor Cyan
  return
}

# 3) auto-merge (PS 6+): backup + idempotente
if(Test-Path $settings){
  $bak = "$settings.bak-$(Get-Date -Format yyyyMMddHHmmss)"
  Copy-Item $settings $bak -Force
  Write-Host "[ok] backup do settings.json -> $bak" -ForegroundColor Green
  $h = Get-Content $settings -Raw | ConvertFrom-Json -AsHashtable
}else{
  $h = @{}
}
if(-not $h.ContainsKey('hooks') -or $null -eq $h.hooks){ $h.hooks = @{} }

function Add-Hook($event, $marker, $command){
  if(-not $h.hooks.ContainsKey($event) -or $null -eq $h.hooks[$event]){ $h.hooks[$event] = @() }
  # idempotente: pula se ja existe qualquer hook citando o marker
  foreach($grp in @($h.hooks[$event])){
    foreach($hk in @($grp.hooks)){
      if($hk.command -and $hk.command.Contains($marker)){ Write-Host "[skip] $event ja registrado"; return }
    }
  }
  $h.hooks[$event] = @($h.hooks[$event]) + @(@{ hooks = @(@{ type='command'; command=$command }) })
  Write-Host "[ok] hook $event adicionado" -ForegroundColor Green
}

Add-Hook 'SessionStart'     'cache-widget.ps1' $cmdSession
Add-Hook 'UserPromptSubmit' 'turn_state.py'    $cmdBusy
Add-Hook 'Stop'             'turn_state.py'     $cmdIdle

($h | ConvertTo-Json -Depth 12) | Set-Content $settings -Encoding UTF8
Write-Host "`n[done] instalado. Reinicie o Claude Code, ou rode agora:" -ForegroundColor Green
Write-Host "  $InstallDir\cache-widget.cmd" -ForegroundColor Yellow
