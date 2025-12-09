@echo off
setlocal EnableDelayedExpansion

rem ============================================================================
rem  build_web.bat
rem  --------------------------------------------------------------------------
rem  Purpose:
rem    Helper script to prepare a web-ready .love package for use with love.js.
rem
rem  What this does:
rem    1. Ensures the standard desktop .love build exists by calling build.bat.
rem    2. Creates a dedicated "web" folder (if it does not already exist).
rem    3. Copies the .love file into the web folder for hosting / embedding.
rem
rem  Notes:
rem    - This script does NOT download or manage love.js / love.wasm.
rem    - You are expected to place love.js, love.wasm and index.html into the
rem      web folder yourself and configure index.html to load this .love file.
rem    - Keeping the web build in its own folder keeps the project modular and
rem      organized so desktop and web builds stay separate.
rem ============================================================================

rem ---------------------------------------------------------------------------
rem CONFIGURATION SECTION
rem ---------------------------------------------------------------------------

rem Name of the game; this should match the .love built by build.bat
set "GAME_NAME=Novus"

rem Name of the .love file produced by the main build script
set "LOVE_FILE=%GAME_NAME%.love"

rem Desktop build output directory (used by build.bat)
set "DIST_DIR=dist"

rem Target directory for web-specific artifacts (for love.js, index.html, etc.)
set "WEB_DIR=web"

rem ---------------------------------------------------------------------------
rem INITIAL SETUP
rem ---------------------------------------------------------------------------

rem Ensure we are running from the directory that contains this script.
cd /d "%~dp0"

rem Echo a small header so it is clear in the console what is happening.
echo.
echo [build_web] Preparing web build for %LOVE_FILE% ...
echo.

rem ---------------------------------------------------------------------------
rem STEP 1: Ensure the desktop .love build exists by delegating to build.bat
rem ---------------------------------------------------------------------------

rem If the .love file does not exist in the dist directory, call the main build.
if not exist "%DIST_DIR%\%LOVE_FILE%" (
    echo [build_web] %DIST_DIR%\%LOVE_FILE% not found. Running build.bat ...
    echo.
    rem Use CALL so control returns to this script after build.bat finishes.
    call build.bat
) else (
    echo [build_web] Found existing %DIST_DIR%\%LOVE_FILE%.
)

rem Double-check that the .love file now exists. If not, abort with an error.
if not exist "%DIST_DIR%\%LOVE_FILE%" (
    echo.
    echo [build_web] ERROR: Failed to locate %DIST_DIR%\%LOVE_FILE% even after running build.bat.
    echo [build_web]        Make sure build.bat completes successfully.
    echo.
    pause
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem STEP 2: Ensure the web output directory exists
rem ---------------------------------------------------------------------------

if not exist "%WEB_DIR%" (
    echo [build_web] Creating web output directory "%WEB_DIR%" ...
    mkdir "%WEB_DIR%"
) else (
    echo [build_web] Web output directory "%WEB_DIR%" already exists.
)

rem ---------------------------------------------------------------------------
rem STEP 3: Copy the .love file into the web directory
rem ---------------------------------------------------------------------------

rem Remove any previous copy of the .love file in the web directory to avoid
rem confusion or stale builds.
if exist "%WEB_DIR%\%LOVE_FILE%" (
    echo [build_web] Removing existing "%WEB_DIR%\%LOVE_FILE%" ...
    del /f /q "%WEB_DIR%\%LOVE_FILE%"
)

rem Copy the freshly built .love file from dist into the web folder.
echo [build_web] Copying "%DIST_DIR%\%LOVE_FILE%" -> "%WEB_DIR%\%LOVE_FILE%" ...
copy /Y "%DIST_DIR%\%LOVE_FILE%" "%WEB_DIR%\%LOVE_FILE%" >nul

rem Check the result of the copy operation and report any error.
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [build_web] ERROR: Failed to copy .love into "%WEB_DIR%".
    echo [build_web]        Verify that %DIST_DIR% and %WEB_DIR% are accessible.
    echo.
    pause
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem FINAL MESSAGE / NEXT STEPS
rem ---------------------------------------------------------------------------

echo.
echo [build_web] Done. Web build is ready at "%WEB_DIR%\%LOVE_FILE%".
echo.
echo [build_web] Next steps (for running in a browser):
echo    1. Place love.js, love.wasm and index.html into the "%WEB_DIR%" folder.
echo    2. Configure index.html to pass "%LOVE_FILE%" as the argument to love.js.
echo    3. Serve the "%WEB_DIR%" folder using a local HTTP server (not file://).
echo.
pause
