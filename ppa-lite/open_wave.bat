@echo off
rem ------------------------------------------------------------------
rem  Double-click this file to open a waveform that already has signals
rem  in it.  Just opening vsim.exe gives you an empty Wave window: the
rem  simulator has no data source and no signals added, so there is
rem  nothing to draw.
rem
rem  Usage (from Explorer): double-click          -> burst waveform
rem  Usage (from cmd)     : open_wave.bat basic   -> basic waveform
rem                         open_wave.bat fifo    -> fifo_full waveform
rem ------------------------------------------------------------------

setlocal
set "T=%~1"
if "%T%"==""            set "T=mcdt_burst_test"
if /i "%T%"=="basic"    set "T=mcdt_basic_test"
if /i "%T%"=="burst"    set "T=mcdt_burst_test"
if /i "%T%"=="fifo"     set "T=mcdt_fifo_full_test"

cd /d "%~dp0lab1"

if not exist "wave\%T%.wlf" goto nowave
if not exist "wave.do"      goto nodo

echo Opening wave\%T%.wlf with wave.do ...
vsim -view "wave\%T%.wlf" -do wave.do
goto end

:nowave
echo [ERROR] wave\%T%.wlf not found.
echo         Run "make wave" in the lab1 folder first.
pause
goto end

:nodo
echo [ERROR] wave.do not found in lab1.
pause
goto end

:end
endlocal
