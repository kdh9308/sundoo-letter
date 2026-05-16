@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion
title Sundoo Letter - GitHub Upload
cd /d "%~dp0"

where git >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
  echo.
  echo [ERROR] Git is not installed.
  echo Download Git for Windows: https://git-scm.com/download/win
  pause
  exit /b 1
)

echo.
echo ============================================
echo   Sundoo Letter - GitHub Pages Upload
echo ============================================
echo.
echo BEFORE running this you should already have:
echo   - A GitHub account
echo   - A repository created at https://github.com/new
echo     Public, any name. README is OK - this bat handles it.
echo.
pause

echo.
set GH_USER=
set /p GH_USER="Enter your GitHub username: "
if "!GH_USER!"=="" (
  echo Username is required.
  pause
  exit /b 1
)

set GH_REPO=sundoo-letter
set /p GH_REPO="Repository name [sundoo-letter]: "
if "!GH_REPO!"=="" set GH_REPO=sundoo-letter

echo.
echo Target: https://github.com/!GH_USER!/!GH_REPO!.git
echo.

set GIT_NAME=
for /f "delims=" %%a in ('git config --global user.name 2^>nul') do set GIT_NAME=%%a
if "!GIT_NAME!"=="" (
  set TMP_NAME=
  set /p TMP_NAME="Your name for commits: "
  git config --global user.name "!TMP_NAME!"
)

set GIT_EMAIL=
for /f "delims=" %%a in ('git config --global user.email 2^>nul') do set GIT_EMAIL=%%a
if "!GIT_EMAIL!"=="" (
  set TMP_EMAIL=
  set /p TMP_EMAIL="Your GitHub email: "
  git config --global user.email "!TMP_EMAIL!"
)

if not exist ".git" (
  git init
  git branch -M main
)

git add .
git commit -m "Upload Sundoo letter site"

git remote remove origin >nul 2>nul
git remote add origin https://github.com/!GH_USER!/!GH_REPO!.git

echo.
echo Pushing to GitHub. Video is 72MB so this may take 1-3 minutes.
echo A browser may pop up for GitHub auth - click Authorize.
echo.
git push -u origin main
set PUSH_RESULT=!ERRORLEVEL!

if !PUSH_RESULT! NEQ 0 (
  echo.
  echo First push rejected. Retrying with force to overwrite remote README.
  echo.
  git push -u origin main --force
  set PUSH_RESULT=!ERRORLEVEL!
)

if !PUSH_RESULT! NEQ 0 goto :failed

echo.
echo ============================================
echo   SUCCESS - Files uploaded.
echo ============================================
echo.
echo NEXT - Enable GitHub Pages:
echo.
echo   Open this URL in browser:
echo   https://github.com/!GH_USER!/!GH_REPO!/settings/pages
echo.
echo   Then:
echo     Source = Deploy from a branch
echo     Branch = main      Folder = root
echo     Click Save
echo     Wait 30 to 60 seconds and refresh
echo.
echo Your site:
echo   https://!GH_USER!.github.io/!GH_REPO!/
echo.
echo QR page:
echo   https://!GH_USER!.github.io/!GH_REPO!/qr.html
echo.
echo To update later, just re-run this bat.
echo.
goto :end

:failed
echo.
echo ============================================
echo   [ERROR] Push failed.
echo ============================================
echo.
echo Check:
echo   - Repo exists on GitHub. Create at https://github.com/new
echo   - Authentication. Browser should pop up for GitHub login.
echo   - File size. Any single file must be under 100MB.
echo.

:end
pause
