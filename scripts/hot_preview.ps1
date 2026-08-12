# ROUNDER — Cursor 오른쪽 패널 미리보기 (핫 리로드)
# 사용법: powershell -ExecutionPolicy Bypass -File scripts/hot_preview.ps1
# Cursor 작업(Ctrl+Shift+B)에서는 -SkipPanelOpen 옵션 사용

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
Write-Host " ROUNDER Preview (Cursor right panel)" -ForegroundColor Cyan
Write-Host " URL: $PreviewUrl" -ForegroundColor Green
Write-Host " Save file -> auto hot reload (1~2 sec)" -ForegroundColor Green
Write-Host " Ctrl+C to stop" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

& $Flutter pub get 2>&1 | Out-Null

if (-not $SkipPanelOpen) {
  Start-Job -ArgumentList $OpenPanel, $Port -ScriptBlock {
    param($Script, $ListenPort)
    & powershell -ExecutionPolicy Bypass -File $Script -Port $ListenPort
  } | Out-Null
}

& $Flutter run -d web-server --web-port=$Port --web-hostname=$HostName
