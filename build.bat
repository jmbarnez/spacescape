@echo off
setlocal EnableDelayedExpansion

rem Game name (output .love file)
set "GAME_NAME=Novus"
set "OUTPUT_FILE=%GAME_NAME%.love"
set "TEMP_ZIP=%GAME_NAME%.zip"
set "DIST_DIR=dist"

rem Ensure we are in the directory of this script
cd /d "%~dp0"

echo Building %OUTPUT_FILE% ...

rem Remove existing output if it exists
if exist "%OUTPUT_FILE%" (
    del /f /q "%OUTPUT_FILE%"
)
if exist "%DIST_DIR%\%OUTPUT_FILE%" (
    del /f /q "%DIST_DIR%\%OUTPUT_FILE%"
)
if exist "%TEMP_ZIP%" (
    del /f /q "%TEMP_ZIP%"
)

rem Create a temporary .zip using PowerShell (compress everything in this folder)
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
"Compress-Archive -Path * -DestinationPath '%TEMP_ZIP%' -Force"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Failed to create %OUTPUT_FILE%.
    pause
    exit /b 1
)

rem Rename the temporary .zip to the .love file
if not exist "%DIST_DIR%" (
    mkdir "%DIST_DIR%"
)
if exist "%DIST_DIR%\%OUTPUT_FILE%" (
    del /f /q "%DIST_DIR%\%OUTPUT_FILE%"
)
move /Y "%TEMP_ZIP%" "%DIST_DIR%\%OUTPUT_FILE%"

echo.
echo Done. Created %DIST_DIR%\%OUTPUT_FILE%.
echo You can run it with the L.ovE engine (e.g. drag onto love.exe).
echo.
pause
