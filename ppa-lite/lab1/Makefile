#############################
# User variables
#############################
TB       ?= tb
SEED     ?= 1
SIMDIR   ?= .
LIBDIR   ?= .
PKG      ?= mcdt_pkg.sv
TESTNAME ?= mcdt_basic_test

DFILES   = $(SIMDIR)/../mcdt/arbiter.v \
           $(SIMDIR)/../mcdt/slave_fifo.v \
           $(SIMDIR)/../mcdt/mcdt.v

VFILES   = $(SIMDIR)/$(PKG) \
           $(SIMDIR)/$(TB).sv


#############################
# Environment variables
#############################
VCOMP    = vlog -work $(LIBDIR)/work -sv -timescale=1ns/1ps -l comp.log +incdir+$(SIMDIR)/../mcdt
# -classdebug/-solvefaildebug : 输出更多类对象与随机化失败的调试信息(实验1要求);
# -wlf                        : 保存波形，方便"在波形中检查BURST发送要求"
RUN_BASE = vsim -voptargs=+acc -work $(LIBDIR)/work $(TB) -l run.log -classdebug -solvefaildebug
RUN      = $(RUN_BASE) -wlf $(TESTNAME).wlf -sv_seed $(SEED) +TESTNAME=$(TESTNAME)

comp:
	$(VCOMP) $(DFILES) $(VFILES)

run:
	$(RUN) -c -do "run -all; quit -f"

rung:
	$(RUN) -i

# 依次跑三个测试用例（实验1验收用）
reg:
	@for t in mcdt_basic_test mcdt_burst_test mcdt_fifo_full_test; do \
	  echo "========== running $$t =========="; \
	  $(RUN_BASE) -wlf $$t.wlf -l run_$$t.log -sv_seed $(SEED) +TESTNAME=$$t -c -do "run -all; quit -f" || exit 1; \
	  grep -q "Errors: 0" run_$$t.log || { echo "*** $$t FAILED"; exit 1; }; \
	done

# 生成带信号数据的波形文件（lab1/wave/*.wlf）
# 注意：-c 命令行模式下光加 -wlf 是不够的，不 log 任何对象的话 wlf 里没有波形数据，
#       必须先 log -r 把层次里的信号登记成要记录的对象。
wave:
	@mkdir -p wave
	@for t in mcdt_basic_test mcdt_burst_test mcdt_fifo_full_test; do \
	  echo "========== dumping waveform for $$t =========="; \
	  $(RUN_BASE) -wlf wave/$$t.wlf -sv_seed $(SEED) +TESTNAME=$$t \
	              -c -do "log -r sim:/tb/*; run -all; quit -f" || exit 1; \
	done

clean:
	rm -rf VRMDATA vrmhtmlreport
	rm -rf *.log* work *.wlf *.ucdb
