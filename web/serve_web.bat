@echo off
setlocal EnableDelayedExpansion

rem ============================================================================
rem  serve_web.bat
rem  --------------------------------------------------------------------------
rem  Purpose:
rem    Convenience launcher for the Python HTTP server used to host the
rem    Spacescape web build with the correct headers for SharedArrayBuffer.
rem
rem  Requirements:
rem    - Python 3 installed and available on PATH as "python".
rem    - This script should live in the same folder as serve_web.py (web/).
rem
rem  Usage:
rem    1. Double-click this file, OR run from a terminal:
rem
rem         serve_web.bat
rem
rem    2. Open the following URL in your browser:
rem
rem         http://localhost:8000/
rem
rem    3. To stop the server, focus the terminal window and press Ctrl+C.
rem
rem  Notes:
rem    - The server sets Cross-Origin-Opener-Policy and
rem      Cross-Origin-Embedder-Policy headers so that love.js can use
rem      SharedArrayBuffer safely.
rem    - This keeps the web tooling separate from the main game code, keeping
rem      the project modular and organized.
rem ============================================================================

rem Ensure we are in the directory of this script (the web/ folder).
cd /d "%~dp0"

rem Launch the Python server on port 8000.
echo.
echo [serve_web] Starting local server on http://localhost:8000/ ...
echo [serve_web] Close this window or press Ctrl+C in the terminal to stop.
echo.

python serve_web.py --port 8000

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [serve_web] ERROR: Failed to start Python server.
    echo [serve_web]        Make sure Python 3 is installed and available as "python".
    echo.
    pause
)
