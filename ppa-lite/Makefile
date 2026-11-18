#############################
# User variables
#############################
TB        ?= tb
TESTNAME  ?= lab1_defaults_test
SEED      ?= 1
SEEDS     ?= 1 2 3
COVDIR    ?= cov

# ---------------------------------------------------------------
# 每个实验的产物目录（验收时一个目录就是这个实验的全部材料）
#   lab<N>/实验<N>_验收对照.md   评分项与代码/波形的对应表
#   lab<N>/wave_ppa/*.wlf        make wave<N> 生成的波形
#   lab<N>/logs/*.log            该实验的 run / run_wave 日志
# 用例名统一以 lab<N>_ 开头，脚本里用 d=${t%%_*} 就能取到目录名。
# ---------------------------------------------------------------
PPA_LABS  = lab1 lab2 lab3 lab4
WAVESUB  ?= wave_ppa

# [评分 4-必做1.2 | 5分] Lab1-3 必做场景各自至少 1 条 testcase
#   LAB1_TESTS -> 实验1 必做1/2/3 + 选做4
#   LAB2_TESTS -> 实验2 必做1/2 + 选做4/5
#   LAB3_TESTS -> 实验3 必做1/2/3 + 选做4/5
#   LAB4_TESTS -> 实验4 随机 / 错误混合 / 闭合 / 代码覆盖补充
SMOKE_TESTS = lab1_defaults_test lab3_e2e_test
LAB1_TESTS  = lab1_defaults_test lab1_pkt_mem_test lab1_pslverr_test
LAB2_TESTS  = lab2_valid_test lab2_errors_test
LAB3_TESTS  = lab3_e2e_test lab3_two_frames_test lab3_busy_protect_test lab3_irq_test lab3_reset_recovery_test
LAB4_TESTS  = lab4_random_test lab4_error_mix_test lab4_closure_test lab4_code_cov_test

# [评分 4-选做5.1 | 10分] Lab1-3 的选做项全部进 REGRESS_TESTS，每次 make regress 都跑到
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

# 由用例名推出实验目录（lab1_xxx -> lab1）；找不到目录就退回工程根
TESTLAB = $(shell echo $(TESTNAME) | cut -d_ -f1)

#############################
# Build and execution
#############################
comp:
	@if [ ! -d ./work ]; then vlib ./work; fi
	$(VCOMP_D) $(RTL_FILES)
	$(VCOMP_V) $(TB_FILES)

run: comp
	@mkdir -p $(COVDIR)/runs
	@d=$(TESTLAB); [ -d $$d ] || d=.; mkdir -p $$d/logs; \
	$(RUN_BASE) -l $$d/logs/run_$(TESTNAME)_$(SEED).log -sv_seed $(SEED) \
	            +TESTNAME=$(TESTNAME) +TEST_SEED=$(SEED) \
	            -do "coverage save -onexit $(COVDIR)/runs/$(TESTNAME)_$(SEED).ucdb; run -all; quit -f"
	@d=$(TESTLAB); [ -d $$d ] || d=.; \
	grep -q "\[TEST PASS\]" $$d/logs/run_$(TESTNAME)_$(SEED).log || { echo "*** $(TESTNAME) FAILED"; exit 1; }
	@d=$(TESTLAB); [ -d $$d ] || d=.; \
	grep -q "Errors: 0, Warnings: 0" $$d/logs/run_$(TESTNAME)_$(SEED).log || { echo "*** $(TESTNAME) TOOL ERRORS"; exit 1; }

smoke: comp
	@for t in $(SMOKE_TESTS); do \
	  d=$${t%%_*}; [ -d $$d ] || d=.; mkdir -p $$d/logs; \
	  echo "==================== $$t ===================="; \
	  $(RUN_BASE) -l $$d/logs/run_$${t}.log -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" $$d/logs/run_$${t}.log || { echo "*** $$t FAILED"; exit 1; }; \
	  grep -q "Errors: 0, Warnings: 0" $$d/logs/run_$${t}.log || { echo "*** $$t TOOL ERRORS"; exit 1; }; \
	done

# [评分 4-必做1.1 | 10分] 一键回归全部 PASS：14 用例 × 3 seed = 42 次
#   每次仿真后两道 grep 是必须的——vsim 用 quit -f 退出，进程退出码恒为 0，
#   不 grep 的话用例挂了也会显示"回归通过"。
# [评分 4-必做1.3 | 5分] 执行流程：comp(DUT 用 -cover sbceft 编) -> 双层循环 -> 每次落 ucdb
#                   -> 两道 grep -> mergecov -> filtercov -> report
regress: comp
	@mkdir -p $(COVDIR)/runs
	@for t in $(REGRESS_TESTS); do \
	  d=$${t%%_*}; [ -d $$d ] || d=.; mkdir -p $$d/logs; \
	  for s in $(SEEDS); do \
	    echo "==================== $$t seed=$$s ===================="; \
	    $(RUN_BASE) -l $$d/logs/run_$${t}_$${s}.log -sv_seed $$s +TESTNAME=$$t +TEST_SEED=$$s \
	                -do "coverage save -onexit $(COVDIR)/runs/$${t}_$${s}.ucdb; run -all; quit -f" || exit 1; \
	    grep -q "\[TEST PASS\]" $$d/logs/run_$${t}_$${s}.log || { echo "*** $$t seed $$s FAILED"; exit 1; }; \
	    grep -q "Errors: 0, Warnings: 0" $$d/logs/run_$${t}_$${s}.log || { echo "*** $$t seed $$s TOOL ERRORS"; exit 1; }; \
	  done; \
	done

lab1: comp
	@for t in $(LAB1_TESTS); do \
	  d=$${t%%_*}; [ -d $$d ] || d=.; mkdir -p $$d/logs; \
	  $(RUN_BASE) -l $$d/logs/run_$${t}.log -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" $$d/logs/run_$${t}.log || { echo "*** $$t FAILED"; exit 1; }; \
	  grep -q "Errors: 0, Warnings: 0" $$d/logs/run_$${t}.log || { echo "*** $$t TOOL ERRORS"; exit 1; }; \
	done

lab2: comp
	@for t in $(LAB2_TESTS); do \
	  d=$${t%%_*}; [ -d $$d ] || d=.; mkdir -p $$d/logs; \
	  $(RUN_BASE) -l $$d/logs/run_$${t}.log -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" $$d/logs/run_$${t}.log || { echo "*** $$t FAILED"; exit 1; }; \
	  grep -q "Errors: 0, Warnings: 0" $$d/logs/run_$${t}.log || { echo "*** $$t TOOL ERRORS"; exit 1; }; \
	done

# ---------------------------------------------------------------
# 波形（验收抽查用）
#   make wave  TESTNAME=lab1_pkt_mem_test   -> lab1/wave_ppa/lab1_pkt_mem_test.wlf
#   make wave1                              -> 实验1 验收要看的 4 个波形
# 注意 -c 模式下光加 -wlf 不会记数据，必须先 log -r 把层次登记下来。
# ---------------------------------------------------------------
WAVEDIR    ?= wave
WAVE1_TESTS = lab1_defaults_test lab1_pkt_mem_test lab1_pslverr_test lab3_irq_test
WAVE2_TESTS = lab2_valid_test lab2_errors_test
WAVE3_TESTS = lab3_e2e_test lab3_two_frames_test lab3_busy_protect_test lab3_irq_test lab3_reset_recovery_test
WAVE4_TESTS = lab4_random_test lab4_error_mix_test lab4_closure_test lab4_code_cov_test

wave: comp
	@d=$(TESTLAB); [ -d $$d ] || d=.; mkdir -p $$d/$(WAVESUB) $$d/logs; \
	$(RUN_BASE) -wlf $$d/$(WAVESUB)/$(TESTNAME).wlf -l $$d/logs/run_wave_$(TESTNAME).log \
	            -sv_seed $(SEED) +TESTNAME=$(TESTNAME) +TEST_SEED=$(SEED) \
	            -do "log -r sim:/tb/*; log /tb/dut/u_m2/mem; log /tb/m3/mem_words; run -all; quit -f"

wave1: comp
	@for t in $(WAVE1_TESTS); do \
	  d=$${t%%_*}; [ -d $$d ] || d=.; mkdir -p $$d/$(WAVESUB) $$d/logs; \
	  echo "==================== dumping wave $$t ===================="; \
	  $(RUN_BASE) -wlf $$d/$(WAVESUB)/$$t.wlf -l $$d/logs/run_wave_$$t.log \
	              -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "log -r sim:/tb/*; log /tb/dut/u_m2/mem; log /tb/m3/mem_words; run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" $$d/logs/run_wave_$$t.log || { echo "*** $$t FAILED"; exit 1; }; \
	done

wave2: comp
	@for t in $(WAVE2_TESTS); do \
	  d=$${t%%_*}; [ -d $$d ] || d=.; mkdir -p $$d/$(WAVESUB) $$d/logs; \
	  echo "==================== dumping wave $$t ===================="; \
	  $(RUN_BASE) -wlf $$d/$(WAVESUB)/$$t.wlf -l $$d/logs/run_wave_$$t.log \
	              -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "log -r sim:/tb/*; log /tb/dut/u_m2/mem; log /tb/m3/mem_words; run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" $$d/logs/run_wave_$$t.log || { echo "*** $$t FAILED"; exit 1; }; \
	done

wave3: comp
	@for t in $(WAVE3_TESTS); do \
	  d=$${t%%_*}; [ -d $$d ] || d=.; mkdir -p $$d/$(WAVESUB) $$d/logs; \
	  echo "==================== dumping wave $$t ===================="; \
	  $(RUN_BASE) -wlf $$d/$(WAVESUB)/$$t.wlf -l $$d/logs/run_wave_$$t.log \
	              -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "log -r sim:/tb/*; log /tb/dut/u_m2/mem; log /tb/m3/mem_words; run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" $$d/logs/run_wave_$$t.log || { echo "*** $$t FAILED"; exit 1; }; \
	done

wave4: comp
	@for t in $(WAVE4_TESTS); do \
	  d=$${t%%_*}; [ -d $$d ] || d=.; mkdir -p $$d/$(WAVESUB) $$d/logs; \
	  echo "==================== dumping wave $$t ===================="; \
	  $(RUN_BASE) -wlf $$d/$(WAVESUB)/$$t.wlf -l $$d/logs/run_wave_$$t.log \
	              -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "log -r sim:/tb/*; log /tb/dut/u_m2/mem; log /tb/m3/mem_words; run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" $$d/logs/run_wave_$$t.log || { echo "*** $$t FAILED"; exit 1; }; \
	done

lab3: comp
	@for t in $(LAB3_TESTS); do \
	  d=$${t%%_*}; [ -d $$d ] || d=.; mkdir -p $$d/logs; \
	  $(RUN_BASE) -l $$d/logs/run_$${t}.log -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" $$d/logs/run_$${t}.log || { echo "*** $$t FAILED"; exit 1; }; \
	  grep -q "Errors: 0, Warnings: 0" $$d/logs/run_$${t}.log || { echo "*** $$t TOOL ERRORS"; exit 1; }; \
	done

lab4: comp
	@for t in $(LAB4_TESTS); do \
	  d=$${t%%_*}; [ -d $$d ] || d=.; mkdir -p $$d/logs; \
	  $(RUN_BASE) -l $$d/logs/run_$${t}.log -sv_seed $(SEED) +TESTNAME=$$t +TEST_SEED=$(SEED) \
	              -do "run -all; quit -f" || exit 1; \
	  grep -q "\[TEST PASS\]" $$d/logs/run_$${t}.log || { echo "*** $$t FAILED"; exit 1; }; \
	  grep -q "Errors: 0, Warnings: 0" $$d/logs/run_$${t}.log || { echo "*** $$t TOOL ERRORS"; exit 1; }; \
	done

cov: regress

mergecov:
	vcover merge -out $(COVDIR)/merged.ucdb $(COVDIR)/runs/*.ucdb
	vcover merge -out $(COVDIR)/dut_merged.ucdb -instance /tb/dut -recursive $(COVDIR)/merged.ucdb

# [评分 4-选做4.2 | 5分] 登记表与过滤配置一一对应：cov_exclude.do 每条注释以 CSV row N 开头，
#   登记表的 exclude_ref 反过来指回 do 文件行号，两边可以互相对上。
filtercov: mergecov
	vsim -c -viewcov $(COVDIR)/dut_merged.ucdb -do "do cov_exclude.do; quit -f"

# [评分 4-必做2.1 | 15分] 五类覆盖率：mergecov 出原始库(98.73%)，filtercov 排除登记项后 100%
# [评分 4-必做2.2 | 5分] 覆盖率报告 GUI 现场展示：cov/html_dut/index.html / cov/html_functional
report: filtercov
	vcover report -html -output $(COVDIR)/html_dut -details $(COVDIR)/dut_filtered.ucdb
	vcover report -html -output $(COVDIR)/html_functional -details $(COVDIR)/merged.ucdb
	vcover report -details $(COVDIR)/dut_merged.ucdb > $(COVDIR)/dut_merged.txt
	vcover report -details $(COVDIR)/dut_filtered.ucdb > $(COVDIR)/dut_filtered.txt
	vcover report -cvg -details $(COVDIR)/merged.ucdb > $(COVDIR)/functional.txt
	vcover report -summary $(COVDIR)/dut_filtered.ucdb > $(COVDIR)/dut_summary.txt
	vcover report -summary $(COVDIR)/merged.ucdb > $(COVDIR)/full_summary.txt
	@cat $(COVDIR)/dut_summary.txt
	@vcover report -details $(COVDIR)/merged.ucdb | grep -E "TOTAL COVERGROUP COVERAGE|TOTAL DIRECTIVE COVERAGE|TOTAL ASSERTION COVERAGE"

# 只清 PPA 产物，不碰各 lab 目录里 MCDT 实验的 work/ 与 wave/
clean:
	rm -rf ./work ./cov
	rm -f *.log *.wlf *.ucdb
	@for d in $(PPA_LABS); do rm -f $$d/logs/*.log $$d/$(WAVESUB)/*.wlf; done

.PHONY: comp run smoke regress lab1 lab2 lab3 lab4 wave wave1 wave2 wave3 wave4 cov mergecov filtercov report clean
