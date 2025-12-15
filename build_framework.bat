@echo off
setlocal

echo Setting up Delphi environment...
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"

echo.
echo ==========================================
echo Building Dext Framework Packages
echo ==========================================
echo.

set BUILD_CONFIG=Debug
set PLATFORM=Win32
set OUTPUT_PATH=%~dp0\Output

if not exist "%OUTPUT_PATH%" mkdir "%OUTPUT_PATH%"
cd "%~dp0\Sources"

echo Building Dext.Core...
msbuild "Dext.Core.dproj" /t:Build /p:Configuration=%BUILD_CONFIG% /p:Platform=%PLATFORM% /p:DCC_DcuOutput="%OUTPUT_PATH%" /p:DCC_DcpOutput="%OUTPUT_PATH%" /v:minimal
if %ERRORLEVEL% NEQ 0 goto Error

echo.
echo Building Dext.Data...
msbuild "Dext.Data.dproj" /t:Build /p:Configuration=%BUILD_CONFIG% /p:Platform=%PLATFORM% /p:DCC_DcuOutput="%OUTPUT_PATH%" /p:DCC_DcpOutput="%OUTPUT_PATH%" /p:DCC_UnitSearchPath="%OUTPUT_PATH%" /v:minimal
if %ERRORLEVEL% NEQ 0 goto Error

echo.
echo Building Dext.Web...
msbuild "Dext.Web.Core.dproj" /t:Build /p:Configuration=%BUILD_CONFIG% /p:Platform=%PLATFORM% /p:DCC_DcuOutput="%OUTPUT_PATH%" /p:DCC_DcpOutput="%OUTPUT_PATH%" /p:DCC_UnitSearchPath="%OUTPUT_PATH%" /v:minimal
if %ERRORLEVEL% NEQ 0 goto Error

echo.
echo ==========================================
echo Build Completed Successfully!
echo Output: %OUTPUT_PATH%
echo ==========================================
if not "%1"=="--no-wait" pause
cd ..
exit /b 0

:Error
echo.
echo ==========================================
echo BUILD FAILED!
echo ==========================================
if not "%1"=="--no-wait" pause
cd ..
exit /b 1
