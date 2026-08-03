@echo off
rem *        Delphi 12 Debug Build (23.0)         *
rem *        Orm.UniDACDemo — errors/warnings to file   *

rem Set environment variables
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"

rem Change to project directory
cd /d "%~dp0"

rem Build project with Debug configuration and filter output
echo Building Orm.UniDACDemo in Debug mode...
msbuild Orm.UniDACDemo.dproj /p:Config=Debug /p:Platform=Win32 /v:minimal > build_full.txt 2>&1
set BUILD_EXIT_CODE=%ERRORLEVEL%

rem Extract only relevant lines for AI analysis
(
    echo ========================================
    echo Build Output - Errors and Warnings Only
    echo ========================================
    echo.
    findstr /i /c:"error" /c:"warning" /c:"failed" /c:"F2039" /c:"F2613" /c:"E2003" /c:"E2034" /c:"E2015" /c:"E2035" /c:"E2129" /c:"F2063" /c:"F1026" /c:"dcc32" /c:"Delphi compiler" /c:".pas(" /c:".dpr(" build_full.txt 2>nul
    echo.
    echo ========================================
    echo Build Summary
    echo ========================================
    findstr /i /c:"Error(s)" /c:"Warning(s)" /c:"Time Elapsed" /c:"Build FAILED" /c:"Build succeeded" build_full.txt 2>nul
) > build_output.txt

rem Check build result
if %BUILD_EXIT_CODE% EQU 0 (
    echo.
    echo ========================================
    echo Build Successful!
    echo ========================================
    echo.
    type build_output.txt
    exit /b 0
) else (
    echo.
    echo ========================================
    echo Build Failed with exit code %BUILD_EXIT_CODE%
    echo ========================================
    echo.
    type build_output.txt
    exit /b %BUILD_EXIT_CODE%
)
