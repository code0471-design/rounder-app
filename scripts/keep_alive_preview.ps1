# ROUNDER — 8888 미리보기 서버 (꺼지면 자동 재시작)
# 사용법: powershell -NoExit -ExecutionPolicy Bypass -File scripts/keep_alive_preview.ps1
# Cursor: Ctrl+Shift+B

param([switch]$SkipPanelOpen)

$ErrorActionPreference = "Continue"
$Port = 8888
$HostName = "127.0.0.1"
$Flutter = Join-Path $env:LOCALAPPDATA "cursor-flutter\flutter\bin\flutter.bat"
$AppDir = Split-Path $PSScriptRoot -Parent
$OpenPanel = Join-Path $PSScriptRoot "open_preview_panel.ps1"
$PreviewUrl = "http://${HostName}:${Port}/"

function Stop-PortProcess {
  param([int]$TargetPort)
  Get-NetTCPConnection -LocalPort $TargetPort -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique |
    ForEach-Object {
      if ($_ -gt 4) { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
    }
}

if (-not (Test-Path $Flutter)) {
  Write-Host "[ERROR] Flutter not found: $Flutter" -ForegroundColor Red
  exit 1
}

Stop-PortProcess -TargetPort $Port
Start-Sleep -Milliseconds 800
Set-Location $AppDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " ROUNDER Keep-Alive Preview Server" -ForegroundColor Cyan
Write-Host " URL: $PreviewUrl" -ForegroundColor Green
Write-Host " No Chrome needed - open URL in browser" -ForegroundColor Green
Write-Host " Auto-restart in 3s if server stops" -ForegroundColor Yellow
Write-Host " Stop: Ctrl+C in this terminal" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

& $Flutter pub get 2>&1 | Out-Null

if (-not $SkipPanelOpen) {
  Start-Job -ArgumentList $OpenPanel, $Port -ScriptBlock {
    param($Script, $ListenPort)
    Start-Sleep -Seconds 4
    & powershell -ExecutionPolicy Bypass -File $Script -Port $ListenPort
  } | Out-Null
}

$attempt = 0
while ($true) {
  $attempt++
  $started = Get-Date -Format "HH:mm:ss"
  Write-Host ""
  Write-Host "[$started] Starting web-server (attempt $attempt)..." -ForegroundColor Cyan

  # cmd /c 로 flutter.bat이 끝날 때까지 대기 (PowerShell에서 bat 즉시 반환 방지)
  cmd /c "`"$Flutter`" run -d web-server --web-port=$Port --web-hostname=$HostName"
  $code = $LASTEXITCODE

  Write-Host ""
  Write-Host "[WARN] Server stopped (exit $code). Restarting in 3 seconds..." -ForegroundColor Yellow
  Write-Host "       Press Ctrl+C in this window to stop permanently." -ForegroundColor DarkGray
  Start-Sleep -Seconds 3
}
