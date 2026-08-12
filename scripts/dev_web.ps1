# [DEPRECATED] flutter run 방식 — Cursor 환경에서 불안定
# 대신 hot_preview.ps1 (가장 빠름) 또는 preview.ps1 을 사용하세요:
#   powershell -ExecutionPolicy Bypass -File scripts/hot_preview.ps1

Write-Host "dev_web.ps1 is deprecated." -ForegroundColor Yellow
Write-Host "Use: scripts/hot_preview.ps1" -ForegroundColor Green
& (Join-Path $PSScriptRoot "hot_preview.ps1")
