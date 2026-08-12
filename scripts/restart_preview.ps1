# ROUNDER — 미리보기 서버 재시작 + Cursor 패널 열기
# 작업 후 자동 실행용

$ErrorActionPreference = "Continue"
$Port = 8888
$HostName = "127.0.0.1"
$PreviewUrl = "http://${HostName}:${Port}/"
$AppDir = Split-Path $PSScriptRoot -Parent
$HotPreview = Join-Path $PSScriptRoot "hot_preview.ps1"
$OpenPanel = Join-Path $PSScriptRoot "open_preview_panel.ps1"

Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty OwningProcess -Unique |
  ForEach-Object {
    if ($_ -gt 4) { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
  }

Start-Sleep -Milliseconds 800
Write-Host "Restarting preview server..." -ForegroundColor Cyan

Start-Process powershell -ArgumentList @(
  '-NoExit',
  '-ExecutionPolicy', 'Bypass',
  '-File', $HotPreview,
  '-SkipPanelOpen'
) -WorkingDirectory $AppDir | Out-Null

Start-Sleep -Seconds 3
& powershell -ExecutionPolicy Bypass -File $OpenPanel -Port $Port

Write-Host "Preview: $PreviewUrl" -ForegroundColor Green
