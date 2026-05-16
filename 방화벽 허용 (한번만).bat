@echo off
chcp 65001 >nul 2>&1
title Sundoo Letter - Firewall Setup

REM ── 관리자 권한 자동 요청 ──
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
  echo.
  echo Requesting administrator permission...
  echo Please click "Yes" on the UAC popup.
  echo.
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

REM ── 이제 관리자 권한으로 실행 중 ──
echo.
echo ============================================
echo   Sundoo Letter Site - Firewall Rule Setup
echo ============================================
echo.

REM 기존 동명 규칙 삭제 (재실행 안전)
netsh advfirewall firewall delete rule name="Sundoo Letter Site (TCP In)" >nul 2>&1

REM 신규 인바운드 TCP 허용 규칙 추가 — 모든 프로파일
netsh advfirewall firewall add rule ^
  name="Sundoo Letter Site (TCP In)" ^
  description="Allow inbound TCP for the Sundoo Church letter site" ^
  dir=in ^
  action=allow ^
  protocol=TCP ^
  localport=8000,8080,5500,3000,9000 ^
  profile=any ^
  enable=yes

if %ERRORLEVEL%==0 (
  echo.
  echo [SUCCESS] Firewall rule added.
  echo Ports 8000, 8080, 5500, 3000, 9000 are now allowed inbound on ALL profiles.
  echo.
  echo You can now close this window and run "편지 사이트 열기.bat".
  echo Mobile devices on the same WiFi will be able to connect.
) else (
  echo.
  echo [ERROR] Failed to add the rule. Check error message above.
)

echo.
echo Press any key to exit...
pause >nul
