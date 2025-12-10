@echo off
setlocal EnableDelayedExpansion

rem ============================================================================
rem  build_web.bat
rem  --------------------------------------------------------------------------
rem  Purpose:
rem    Build a web-ready version of the game using love.js.
rem
rem  What this does:
rem    1. Ensures the standard desktop .love build exists by calling build.bat.
rem    2. Uses love.js (npm package) to create a complete web build.
rem    3. Outputs to the "web" folder with all necessary files.
rem
rem  Requirements:
rem    - Node.js and npm must be installed
rem    - love.js package (will be installed if not present)
rem
rem  Notes:
rem    - Uses -c (compatibility mode) for broader browser support
rem    - The web folder will contain a complete, ready-to-deploy web build
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

rem Target directory for web build
set "WEB_DIR=web"

rem Game title for the web page
set "GAME_TITLE=Spacescape"

rem ---------------------------------------------------------------------------
rem INITIAL SETUP
rem ---------------------------------------------------------------------------

rem Ensure we are running from the directory that contains this script.
cd /d "%~dp0"

rem Echo a small header so it is clear in the console what is happening.
echo.
echo [build_web] Building web version of %LOVE_FILE% ...
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
rem STEP 2: Check for Node.js and npm
rem ---------------------------------------------------------------------------

where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [build_web] ERROR: Node.js is not installed or not in PATH.
    echo [build_web]        Please install Node.js from https://nodejs.org/
    echo.
    pause
    exit /b 1
)

echo [build_web] Node.js found.

rem ---------------------------------------------------------------------------
rem STEP 3: Build the web version using love.js
rem ---------------------------------------------------------------------------

echo [build_web] Running love.js to create web build...
echo [build_web] This may take a moment...
echo.

rem Run love.js using the locally installed module
rem -t sets the title, -c enables compatibility mode, -m sets memory (64MB)
node node_modules/love.js/index.js "%DIST_DIR%\%LOVE_FILE%" "%WEB_DIR%" -t "%GAME_TITLE%" -c -m 67108864

rem Check the result
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [build_web] ERROR: love.js build failed.
    echo [build_web]        Make sure you have internet access for npm packages.
    echo.
    pause
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem FINAL MESSAGE / NEXT STEPS
rem ---------------------------------------------------------------------------

echo.
echo [build_web] Done! Web build is ready in the "%WEB_DIR%" folder.
echo.
echo [build_web] To test locally:
echo    1. cd %WEB_DIR%
echo    2. python -m http.server 8000
echo    3. Open http://localhost:8000 in your browser
echo.
echo [build_web] Or use serve_web.bat for a server with proper headers.
echo.
pause
</CodeContent>
<parameter name="Complexity">4
