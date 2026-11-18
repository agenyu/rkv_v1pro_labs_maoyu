@echo off
rem ============================================================
rem  Lab3 (PPA) waveforms - one window per testcase
rem  Prerequisite: run "make wave3" in this directory first.
rem ============================================================
cd /d "%~dp0"

if not exist "lab3\wave_ppa\lab3_e2e_test.wlf" (
  echo [ERROR] lab3\wave_ppa\*.wlf not found.
  echo         Run "make wave3" in %CD% first.
  pause
  exit /b 1
)

start "lab3_e2e_test" vsim -view lab3/wave_ppa/lab3_e2e_test.wlf -do wave/ppa_wave.do
start "lab3_two_frames_test" vsim -view lab3/wave_ppa/lab3_two_frames_test.wlf -do wave/ppa_wave.do
start "lab3_busy_protect_test" vsim -view lab3/wave_ppa/lab3_busy_protect_test.wlf -do wave/ppa_wave.do
start "lab3_irq_test" vsim -view lab3/wave_ppa/lab3_irq_test.wlf -do wave/ppa_wave.do
start "lab3_reset_recovery_test" vsim -view lab3/wave_ppa/lab3_reset_recovery_test.wlf -do wave/ppa_wave.do

exit /b 0
