@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo  Cursor에서 Ctrl+Shift+B 가 더 편합니다 (오른쪽 패널 자동 열림)
echo.
powershell -ExecutionPolicy Bypass -File "scripts\hot_preview.ps1"
pause
