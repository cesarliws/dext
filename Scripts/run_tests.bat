@echo off
setlocal enabledelayedexpansion

echo ==========================================
echo Running Dext Tests
echo ==========================================
echo.

set FAILED_TESTS=
set SUCCESS_COUNT=0
set FAIL_COUNT=0
set SKIPPED_COUNT=0

REM Find all test/demo executables
for /r "%~dp0..\Examples" %%f in (*.dproj) do (
    set "PROJECT_NAME=%%~nf"
    set "PROJECT_DIR=%%~dpf"
    
    REM Check if it's a test/demo project (contains "Test" or "Demo" in name)
    echo !PROJECT_NAME! | findstr /i "test demo" >nul
    if !ERRORLEVEL! EQU 0 (
        echo.
        echo ==========================================
        echo Testing: !PROJECT_NAME!
        echo ==========================================
        
        REM Try to find the executable in common output locations
        set "EXE_FOUND="
        for %%d in ("!PROJECT_DIR!..\Output" "!PROJECT_DIR!Win32\Release" "!PROJECT_DIR!Win32\Debug" "!PROJECT_DIR!Release" "!PROJECT_DIR!Debug") do (
            if exist "%%~d\!PROJECT_NAME!.exe" (
                set "EXE_PATH=%%~d\!PROJECT_NAME!.exe"
                set "EXE_FOUND=1"
                goto :run_test
            )
        )
        
        :run_test
        if defined EXE_FOUND (
            echo Running: !EXE_PATH!
            "!EXE_PATH!" --no-wait
            
            if !ERRORLEVEL! EQU 0 (
                echo [PASSED] !PROJECT_NAME!
                set /a SUCCESS_COUNT+=1
            ) else (
                echo [FAILED] !PROJECT_NAME! (Exit code: !ERRORLEVEL!)
                set FAILED_TESTS=!FAILED_TESTS! !PROJECT_NAME!
                set /a FAIL_COUNT+=1
            )
        ) else (
            echo [SKIPPED] !PROJECT_NAME! - Executable not found
            set /a SKIPPED_COUNT+=1
        )
    )
)

echo.
echo ==========================================
echo Test Summary
echo ==========================================
echo Passed:  %SUCCESS_COUNT%
echo Failed:  %FAIL_COUNT%
echo Skipped: %SKIPPED_COUNT%

if not "%FAILED_TESTS%"=="" (
    echo.
    echo Failed Tests:
    for %%p in (%FAILED_TESTS%) do echo   - %%p
    echo.
    echo ==========================================
    echo TESTS COMPLETED WITH FAILURES
    echo ==========================================
    exit /b 1
) else (
    echo.
    echo ==========================================
    if %SUCCESS_COUNT% GTR 0 (
        echo ALL TESTS PASSED!
    ) else (
        echo NO TESTS FOUND TO RUN
    )
    echo ==========================================
    exit /b 0
)

Pause
