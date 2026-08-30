@echo off
:: This script copies the wwwroot folder to the output directory
:: It is intended to be called as a Post-Build event in the Delphi project

set PROJECT_DIR=%~dp0
set TARGET_DIR=%~1

if "%TARGET_DIR%"=="" (
    set TARGET_DIR=%PROJECT_DIR%..\..\Output\
)

echo Copying wwwroot from %PROJECT_DIR% to %TARGET_DIR%...

if not exist "%TARGET_DIR%wwwroot" mkdir "%TARGET_DIR%wwwroot"
xcopy "%PROJECT_DIR%wwwroot\*" "%TARGET_DIR%wwwroot\" /S /E /Y /D

echo Done.
