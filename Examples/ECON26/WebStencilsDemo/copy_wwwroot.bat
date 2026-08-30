@echo off
:: Mirror wwwroot into Examples/Output. xcopy leaves files from the last
:: example that shared this folder (DextGemini index.html was one of them).

set PROJECT_DIR=%~dp0
set TARGET_DIR=%~1

if "%TARGET_DIR%"=="" (
    set TARGET_DIR=%PROJECT_DIR%..\..\Output\
)

echo Mirroring wwwroot from %PROJECT_DIR% to %TARGET_DIR%...

robocopy "%PROJECT_DIR%wwwroot" "%TARGET_DIR%wwwroot" /MIR /NFL /NDL /NJH /NJS /NP
if %ERRORLEVEL% GEQ 8 exit /b 1
exit /b 0
