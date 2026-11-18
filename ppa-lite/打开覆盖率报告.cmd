@echo off
setlocal
set "ROOT=%~dp0"

if not exist "%ROOT%cov\html_dut\index.html" goto missing
if not exist "%ROOT%cov\html_functional\index.html" goto missing

start "" "%ROOT%cov\html_dut\index.html"
start "" "%ROOT%cov\html_functional\index.html"
exit /b 0

:missing
echo Coverage HTML report was not found.
echo Run the following command from this project directory first:
echo.
echo     make report
echo.
pause
exit /b 1
