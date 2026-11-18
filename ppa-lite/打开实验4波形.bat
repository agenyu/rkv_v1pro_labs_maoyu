@echo off
rem ============================================================
rem  Lab4 (PPA) waveforms - one window per testcase
rem  Prerequisite: run "make wave4" in this directory first.
rem ============================================================
cd /d "%~dp0"

if not exist "lab4\wave_ppa\lab4_random_test.wlf" (
  echo [ERROR] lab4\wave_ppa\*.wlf not found.
  echo         Run "make wave4" in %CD% first.
  pause
  exit /b 1
)

start "lab4_random_test" vsim -view lab4/wave_ppa/lab4_random_test.wlf -do wave/ppa_wave.do
start "lab4_error_mix_test" vsim -view lab4/wave_ppa/lab4_error_mix_test.wlf -do wave/ppa_wave.do
start "lab4_closure_test" vsim -view lab4/wave_ppa/lab4_closure_test.wlf -do wave/ppa_wave.do
start "lab4_code_cov_test" vsim -view lab4/wave_ppa/lab4_code_cov_test.wlf -do wave/ppa_wave.do

exit /b 0
