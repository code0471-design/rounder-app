# ROUNDER — Flutter Web 서버 1회 실행
# 사용법: powershell -ExecutionPolicy Bypass -File scripts/start_web.ps1

$Port = 8080
$HostName = "127.0.0.1"
$Flutter = Join-Path $env:LOCALAPPDATA "cursor-flutter\flutter\bin\flutter.bat"
$AppDir = Split-Path $PSScriptRoot -Parent

Set-Location $AppDir

Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty OwningProcess -Unique |
  ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }

Start-Sleep -Seconds 1
Write-Host "Starting: http://${HostName}:${Port}/main" -ForegroundColor Green

& $Flutter pub get
& $Flutter run -d web-server --web-port=$Port --web-hostname=$HostName
