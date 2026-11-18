#############################
# User variables
#############################
TB        ?= tb
SEED      ?= 1
SIMDIR    ?= .
LIBDIR    ?= .
TESTNAME  ?= mcdt_basic_test
CHID      ?= 0
COVDIR    ?= cov

# 回归用的测试用例列表和随机种子
T_LIST   ?= mcdt_basic_test mcdt_burst_test mcdt_fifo_full_test mcdt_single_test mcdt_random_test
SEEDS    ?= 1 2 3

DFILES    = $(SIMDIR)/../mcdt/arbiter.v \
            $(SIMDIR)/../mcdt/slave_fifo.v \
            $(SIMDIR)/../mcdt/mcdt.v

VFILES    = $(SIMDIR)/mcdt_pkg.sv \
            $(SIMDIR)/$(TB).sv


#############################
# Environment variables
#############################
# NOTE: 覆盖率编译选项只加在设计文件上，TB和package不加
VCOMP_D   = vlog -work $(LIBDIR)/work -cover bst -sv -timescale=1ns/1ps -l comp_dut.log +incdir+$(SIMDIR)/../mcdt
VCOMP_V   = vlog -work $(LIBDIR)/work -sv -timescale=1ns/1ps -l comp_tb.log +incdir+$(SIMDIR)/../mcdt

RUN_BASE  = vsim -c -voptargs=+acc -work $(LIBDIR)/work $(TB) \
            -coverage -assertdebug -assertcounts -classdebug -solvefaildebug

comp:
	mkdir -p $(COVDIR)/runs
	$(VCOMP_D) $(DFILES)
	$(VCOMP_V) $(VFILES)

# 单次仿真：make run TESTNAME=xxx SEED=n CHID=n
run:
	mkdir -p $(COVDIR)/runs
	$(RUN_BASE) -l run_$(TESTNAME)_$(SEED).log -sv_seed $(SEED) \
	            +TESTNAME=$(TESTNAME) +CHID=$(CHID) \
	            -do "coverage save -onexit $(COVDIR)/runs/$(TESTNAME)_$(SEED).ucdb; run -all; quit -f"

rung:
	vsim -voptargs=+acc -work $(LIBDIR)/work $(TB) \
	     -sv_seed $(SEED) +TESTNAME=$(TESTNAME) +CHID=$(CHID) -coverage -assertdebug

# 一键回归：基础用例×多个种子 + alone用例遍历3个独占通道 + pair用例遍历3组配对
reg:
	@mkdir -p $(COVDIR)/runs
	@for t in $(T_LIST); do \
	  for s in $(SEEDS); do \
	    echo "==================== $$t seed=$$s ===================="; \
	    $(RUN_BASE) -l run_$${t}_$${s}.log -sv_seed $$s +TESTNAME=$$t \
	                -do "coverage save -onexit $(COVDIR)/runs/$${t}_$${s}.ucdb; run -all; quit -f" || exit 1; \
	    grep -q "Errors: 0" run_$${t}_$${s}.log || { echo "*** $$t seed $$s FAILED"; exit 1; }; \
	  done; \
	done
	@for c in 0 1 2; do \
	  echo "==================== mcdt_alone_test CHID=$$c ===================="; \
	  $(RUN_BASE) -l run_alone_$$c.log -sv_seed 1 +TESTNAME=mcdt_alone_test +CHID=$$c \
	              -do "coverage save -onexit $(COVDIR)/runs/mcdt_alone_test_$${c}.ucdb; run -all; quit -f" || exit 1; \
	  grep -q "Errors: 0" run_alone_$$c.log || { echo "*** alone CHID=$$c FAILED"; exit 1; }; \
	done
	@for p in 0 1 2; do \
	  echo "==================== mcdt_pair_test CHPAIR=$$p ===================="; \
	  $(RUN_BASE) -l run_pair_$$p.log -sv_seed 1 +TESTNAME=mcdt_pair_test +CHPAIR=$$p \
	              -do "coverage save -onexit $(COVDIR)/runs/mcdt_pair_test_$${p}.ucdb; run -all; quit -f" || exit 1; \
	  grep -q "Errors: 0" run_pair_$$p.log || { echo "*** pair CHPAIR=$$p FAILED"; exit 1; }; \
	done

# 合并所有覆盖率数据
merge:
	vcover merge -out $(COVDIR)/merged.ucdb $(COVDIR)/runs/*.ucdb

# 生成HTML覆盖率报告 + 文本汇总
report: merge
	vcover report -html -output $(COVDIR)/html -details $(COVDIR)/merged.ucdb
	vcover report -details $(COVDIR)/merged.ucdb > $(COVDIR)/merged.txt
	@vcover report -details $(COVDIR)/merged.ucdb | head -60

clean:
	rm -rf VRMDATA vrmhtmlreport
	rm -rf *.log* work *.wlf *.ucdb $(COVDIR)
