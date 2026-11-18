@echo off
rem ============================================================
rem  Lab2 (PPA) waveforms - one window per testcase
rem  Prerequisite: run "make wave2" in this directory first.
rem ============================================================
cd /d "%~dp0"

if not exist "lab2\wave_ppa\lab2_valid_test.wlf" (
  echo [ERROR] lab2\wave_ppa\*.wlf not found.
  echo         Run "make wave2" in %CD% first.
  pause
  exit /b 1
)

start "lab2_valid_test" vsim -view lab2/wave_ppa/lab2_valid_test.wlf -do wave/ppa_wave_m3.do
start "lab2_errors_test" vsim -view lab2/wave_ppa/lab2_errors_test.wlf -do wave/ppa_wave_m3.do

exit /b 0
