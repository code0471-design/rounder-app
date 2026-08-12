# ROUNDER — Staging Firebase 미리보기
# 사용법: powershell -ExecutionPolicy Bypass -File scripts/preview_staging.ps1
#
# Mock 끔 + USE_FIREBASE_WEB=true 로 앱/어드민이 같은 Firestore를 봅니다.
# http://127.0.0.1:8888/?app=1   (앱)
# http://127.0.0.1:8888/         (어드민)

$ErrorActionPreference = "Continue"
$Port = 8888
$HostName = "127.0.0.1"
$Flutter = "C:\flutter\bin\flutter.bat"
if (-not (Test-Path $Flutter)) {
  $Flutter = Join-Path $env:LOCALAPPDATA "cursor-flutter\flutter\bin\flutter.bat"
}
$AppDir = Split-Path $PSScriptRoot -Parent
$WebDir = Join-Path $AppDir "build\web"
$PreviewUrl = "http://${HostName}:${Port}/?app=1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " ROUNDER STAGING (Firebase Web)" -ForegroundColor Cyan
Write-Host " URL: $PreviewUrl" -ForegroundColor Green
Write-Host " Admin: http://${HostName}:${Port}/" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Set-Location $AppDir

# free port
Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty OwningProcess -Unique |
  ForEach-Object { if ($_ -gt 4) { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue } }

Write-Host "Building with USE_FIREBASE_WEB=true ..." -ForegroundColor Cyan
& $Flutter build web --debug `
  --dart-define=USE_FIREBASE_WEB=true `
  --dart-define=FORCE_OFFLINE_MOCK=false
if ($LASTEXITCODE -ne 0) {
  Write-Host "Build FAILED" -ForegroundColor Red
  exit 1
}

Write-Host "Serving $WebDir on $Port ..." -ForegroundColor Green
Set-Location $WebDir
# Windows Store python stub often fails (exit 9009) — prefer npx serve
if (Get-Command npx -ErrorAction SilentlyContinue) {
  npx --yes serve -l "tcp://${HostName}:${Port}" .
} else {
  Write-Host "npx not found — falling back to flutter web-server" -ForegroundColor Yellow
  Set-Location $AppDir
  & $Flutter run -d web-server --web-hostname=$HostName --web-port=$Port `
    --dart-define=USE_FIREBASE_WEB=true `
    --dart-define=FORCE_OFFLINE_MOCK=false
}
