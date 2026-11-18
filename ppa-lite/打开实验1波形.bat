@echo off
rem ============================================================
rem  Lab1 (PPA) waveforms - one window per testcase
rem  Prerequisite: run "make wave1" in this directory first.
rem ============================================================
cd /d "%~dp0"

if not exist "lab1\wave_ppa\lab1_defaults_test.wlf" (
  echo [ERROR] lab1\wave_ppa\*.wlf not found.
  echo         Run "make wave1" in %CD% first.
  pause
  exit /b 1
)

start "lab1_defaults_test" vsim -view lab1/wave_ppa/lab1_defaults_test.wlf -do wave/ppa_wave_lab1.do
start "lab1_pslverr_test" vsim -view lab1/wave_ppa/lab1_pslverr_test.wlf -do wave/ppa_wave_lab1.do
start "lab1_pkt_mem_test" vsim -view lab1/wave_ppa/lab1_pkt_mem_test.wlf -do wave/ppa_wave.do

exit /b 0
