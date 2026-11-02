#############################
# User variables
#############################
TB        ?= tb
TESTNAME  ?= lab1_defaults_test
SEED      ?= 1
SEEDS     ?= 1 2 3
COVDIR    ?= cov

SMOKE_TESTS = lab1_defaults_test lab3_e2e_test
LAB1_TESTS  = lab1_defaults_test lab1_pkt_mem_test lab1_pslverr_test
LAB2_TESTS  = lab2_valid_test lab2_errors_test
LAB3_TESTS  = lab3_e2e_test lab3_two_frames_test lab3_busy_protect_test lab3_irq_test lab3_reset_recovery_test
LAB4_TESTS  = lab4_random_test lab4_error_mix_test lab4_closure_test
REGRESS_TESTS = $(LAB1_TESTS) $(LAB2_TESTS) $(LAB3_TESTS) $(LAB4_TESTS)

RTL_FILES = ./rtl/apb_slave_if.sv \
            ./rtl/packet_sram.sv \
            ./rtl/packet_proc_core.sv \
            ./rtl/ppa_top.sv

TB_FILES  = ./tb/ppa_if.sv \
            ./tb/ppa_pkg.sv \
            ./tb/tb.sv

#############################
# Environment variables
#############################
VCOMP_D = vlog -work ./work -sv -timescale=1ns/1ps -cover sbceft \
                 -coverfec -fsmverbose=b -l comp_dut.log
VCOMP_V = vlog -work ./work -sv -timescale=1ns/1ps -l comp_tb.log

RUN_BASE = vsim -c -voptargs=+acc -work ./work $(TB) \
           -coverage -assertdebug -assertcounts -assertdebug \
           -cvgperinstance -cvgmergeinstances -classdebug -solvefaildebug

#############################
# Build and execution
#############################
comp:
	@if [ ! -d ./work ]; then vlib ./work; fi
	$(VCOMP_D) $(RTL_FILES)
	$(VCOMP_V) $(TB_FILES)

run: comp
	@mkdir -p $(COVDIR)/runs
	$(RUN_BASE) -l run_$(TESTNAME)_$(SEED).log -sv_seed $(SEED) \
	            +TESTNAME=$(TESTNAME) +TEST_SEED=$(SEED) \
	            -do "coverage save -onexit $(COVDIR)/runs/$(TESTNAME)_$(SEED).ucdb; run -all; quit -f"
	@grep -q "\[TEST PASS\]" run_$(TESTNAME)_$(SEED).log || { echo "*** $(TESTNAME) FAILED"; exit 1; }
	@grep -q "Errors: 0, Warnings: 0" run_$(TESTNAME)_$(SEED).log || { echo "*** $(TESTNAME) TOOL ERRORS"; exit 1; }

smoke: comp
	@for t in $(SMOKE_TESTS); do \
	  echo "==================== $$t ===================="; \
	  $(RUN_BASE) -l run_$${t}.log -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" run_$${t}.log || { echo "*** $$t FAILED"; exit 1; }; \
	  grep -q "Errors: 0, Warnings: 0" run_$${t}.log || { echo "*** $$t TOOL ERRORS"; exit 1; }; \
	done

regress: comp
	@mkdir -p $(COVDIR)/runs
	@for t in $(REGRESS_TESTS); do \
	  for s in $(SEEDS); do \
	    echo "==================== $$t seed=$$s ===================="; \
	    $(RUN_BASE) -l run_$${t}_$${s}.log -sv_seed $$s +TESTNAME=$$t +TEST_SEED=$$s \
	                -do "coverage save -onexit $(COVDIR)/runs/$${t}_$${s}.ucdb; run -all; quit -f" || exit 1; \
	    grep -q "\[TEST PASS\]" run_$${t}_$${s}.log || { echo "*** $$t seed $$s FAILED"; exit 1; }; \
	    grep -q "Errors: 0, Warnings: 0" run_$${t}_$${s}.log || { echo "*** $$t seed $$s TOOL ERRORS"; exit 1; }; \
	  done; \
	done

lab1: comp
	@for t in $(LAB1_TESTS); do \
	  $(RUN_BASE) -l run_$${t}.log -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" run_$${t}.log || { echo "*** $$t FAILED"; exit 1; }; \
	  grep -q "Errors: 0, Warnings: 0" run_$${t}.log || { echo "*** $$t TOOL ERRORS"; exit 1; }; \
	done

lab2: comp
	@for t in $(LAB2_TESTS); do \
	  $(RUN_BASE) -l run_$${t}.log -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" run_$${t}.log || { echo "*** $$t FAILED"; exit 1; }; \
	  grep -q "Errors: 0, Warnings: 0" run_$${t}.log || { echo "*** $$t TOOL ERRORS"; exit 1; }; \
	done

lab3: comp
	@for t in $(LAB3_TESTS); do \
	  $(RUN_BASE) -l run_$${t}.log -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" run_$${t}.log || { echo "*** $$t FAILED"; exit 1; }; \
	  grep -q "Errors: 0, Warnings: 0" run_$${t}.log || { echo "*** $$t TOOL ERRORS"; exit 1; }; \
	done

lab4: comp
	@for t in $(LAB4_TESTS); do \
	  $(RUN_BASE) -l run_$${t}.log -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" run_$${t}.log || { echo "*** $$t FAILED"; exit 1; }; \
	  grep -q "Errors: 0, Warnings: 0" run_$${t}.log || { echo "*** $$t TOOL ERRORS"; exit 1; }; \
	done

cov: regress

mergecov:
	vcover merge -out $(COVDIR)/merged.ucdb $(COVDIR)/runs/*.ucdb
	vcover merge -out $(COVDIR)/dut_merged.ucdb -instance /tb/dut -recursive $(COVDIR)/merged.ucdb

report: mergecov
	vcover report -html -output $(COVDIR)/html_dut -details $(COVDIR)/dut_merged.ucdb
	vcover report -html -output $(COVDIR)/html_functional -details $(COVDIR)/merged.ucdb
	vcover report -details $(COVDIR)/dut_merged.ucdb > $(COVDIR)/dut_merged.txt
	vcover report -cvg -details $(COVDIR)/merged.ucdb > $(COVDIR)/functional.txt
	vcover report -summary $(COVDIR)/dut_merged.ucdb > $(COVDIR)/dut_summary.txt
	vcover report -summary $(COVDIR)/merged.ucdb > $(COVDIR)/full_summary.txt
	@cat $(COVDIR)/dut_summary.txt
	@vcover report -details $(COVDIR)/merged.ucdb | grep -E "TOTAL COVERGROUP COVERAGE|TOTAL DIRECTIVE COVERAGE|TOTAL ASSERTION COVERAGE"

clean:
	rm -rf ./work ./cov
	rm -f *.log *.wlf *.ucdb

.PHONY: comp run smoke regress lab1 lab2 lab3 lab4 cov mergecov report clean
