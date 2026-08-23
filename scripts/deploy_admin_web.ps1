# ROUNDER — Staging 어드민 Web 빌드 + Hosting 배포 (Firestore 실데이터)
# 사용법: powershell -ExecutionPolicy Bypass -File scripts/deploy_admin_web.ps1
#
# Mock 없이 USE_FIREBASE_WEB=true 로 빌드 → website/admin → firebase hosting

$ErrorActionPreference = "Stop"
$AppDir = Split-Path $PSScriptRoot -Parent
Set-Location $AppDir

$Flutter = "C:\flutter\bin\flutter.bat"
if (-not (Test-Path $Flutter)) {
  $Flutter = Join-Path $env:LOCALAPPDATA "cursor-flutter\flutter\bin\flutter.bat"
}
if (-not (Test-Path $Flutter)) {
  Write-Host "flutter.bat 없음" -ForegroundColor Red
  exit 1
}

$Dest = Join-Path $AppDir "website\admin"
$Src = Join-Path $AppDir "build\web"

Write-Host "Building admin web (Firebase / no mock) ..." -ForegroundColor Cyan
& $Flutter build web --release `
  --base-href=/admin/ `
  --pwa-strategy=none `
  --dart-define=USE_FIREBASE_WEB=true `
  --dart-define=FORCE_OFFLINE_MOCK=false
if ($LASTEXITCODE -ne 0) {
  Write-Host "Build FAILED" -ForegroundColor Red
  exit 1
}

if (-not (Test-Path $Src)) {
  Write-Host "build/web 없음" -ForegroundColor Red
  exit 1
}

Write-Host "Copying to website/admin ..." -ForegroundColor Cyan
if (Test-Path $Dest) {
  Remove-Item -Recurse -Force $Dest
}
New-Item -ItemType Directory -Path $Dest | Out-Null
Copy-Item -Path (Join-Path $Src "*") -Destination $Dest -Recurse -Force

# 빌드가 Mock으로 떨어지지 않았는지 확인
$mainJs = Join-Path $Dest "main.dart.js"
$probe = Select-String -Path $mainJs -Pattern "OFFLINE MOCK" -SimpleMatch -Quiet
if ($probe) {
  Write-Host "WARNING: main.dart.js still contains OFFLINE MOCK path" -ForegroundColor Yellow
} else {
  Write-Host "OK: no OFFLINE MOCK startup string required at boot (Firebase path)" -ForegroundColor Green
}

Write-Host "Deploying Firebase Hosting (staging) ..." -ForegroundColor Cyan
firebase deploy --only hosting --project rounder-staging
if ($LASTEXITCODE -ne 0) {
  Write-Host "Deploy FAILED" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "Done. Admin: https://rounder-staging.web.app/admin/" -ForegroundColor Green
Write-Host "Hard refresh (Ctrl+Shift+R) if old Mock UI is cached." -ForegroundColor Yellow
