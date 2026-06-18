@echo off
REM Reabre a barrinha de cache/custo do Claude (single-instance via mutex: nao duplica).
REM Prefere PowerShell 7 (pwsh) se existir; senao usa o Windows PowerShell (powershell).
where pwsh >nul 2>nul && (
  start "" pwsh -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0cache-widget.ps1"
) || (
  start "" powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0cache-widget.ps1"
)
