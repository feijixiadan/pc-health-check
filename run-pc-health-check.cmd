@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo PC Health Check
echo This tool only collects diagnostic information and does not change files or settings.
echo Review generated reports before sharing them publicly.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\pc-health-check.ps1" -OpenReport
echo.
pause
