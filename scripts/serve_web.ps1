# ROUNDER — 1회 빌드 + 정적 서버 (Python 불필요)
# 사용법: powershell -ExecutionPolicy Bypass -File scripts/serve_web.ps1

$ErrorActionPreference = "Stop"
$Port = 8080
$HostName = "127.0.0.1"
$Flutter = Join-Path $env:LOCALAPPDATA "cursor-flutter\flutter\bin\flutter.bat"
$AppDir = Split-Path $PSScriptRoot -Parent
$WebDir = Join-Path $AppDir "build\web"

Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty OwningProcess -Unique |
  ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }

Set-Location $AppDir
Write-Host "Building web..." -ForegroundColor Cyan
& $Flutter build web --release
if ($LASTEXITCODE -ne 0) { throw "flutter build web failed" }

Write-Host "Serving: http://${HostName}:${Port}/" -ForegroundColor Green
Set-Location $WebDir

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://${HostName}:${Port}/")
$listener.Start()

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $rel = $ctx.Request.Url.LocalPath.TrimStart("/") -replace "/", "\"
  if ([string]::IsNullOrWhiteSpace($rel)) { $rel = "index.html" }
  $file = Join-Path $WebDir $rel
  if (-not (Test-Path $file -PathType Leaf)) { $file = Join-Path $WebDir "index.html" }
  $bytes = [IO.File]::ReadAllBytes($file)
  $ctx.Response.Headers.Add("Cache-Control", "no-cache")
  $ctx.Response.ContentLength64 = $bytes.Length
  $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $ctx.Response.Close()
}
