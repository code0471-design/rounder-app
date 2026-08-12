# ROUNDER 심사용 홈페이지 배포 (Firebase Hosting)
# 사용법: powershell -ExecutionPolicy Bypass -File scripts/deploy_website.ps1
#
# 사전 준비:
# 1) npm i -g firebase-tools
# 2) firebase login
# 3) .firebaserc 의 프로젝트(예: rounder-staging) 확인
# 4) website/index.html 의 사업자 정보 플레이스홀더 교체

$ErrorActionPreference = "Stop"
$AppDir = Split-Path $PSScriptRoot -Parent
Set-Location $AppDir

if (-not (Test-Path "website\index.html")) {
  Write-Host "website/index.html 없음" -ForegroundColor Red
  exit 1
}

Write-Host "Deploying website/ to Firebase Hosting ..." -ForegroundColor Cyan
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) {
  Write-Host "Deploy FAILED" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "Done. Hosting URL is shown above." -ForegroundColor Green
Write-Host "카카오 제출용 예시:" -ForegroundColor Yellow
Write-Host "  홈페이지: https://<project>.web.app/"
Write-Host "  개인정보: https://<project>.web.app/privacy.html"
Write-Host "  이용약관: https://<project>.web.app/terms.html"
