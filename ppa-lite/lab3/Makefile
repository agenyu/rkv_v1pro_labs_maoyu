#############################
# User variables
#############################
TB        ?= tb
SEED      ?= 1
SIMDIR    ?= .
LIBDIR    ?= .
PKG       ?= mcdt_pkg.sv
TESTNAME  ?= mcdt_basic_test

DFILES    = $(SIMDIR)/../mcdt/arbiter.v \
            $(SIMDIR)/../mcdt/slave_fifo.v \
            $(SIMDIR)/../mcdt/mcdt.v

VFILES    = $(SIMDIR)/$(PKG) \
            $(SIMDIR)/$(TB).sv


#############################
# Environment variables
#############################
VCOMP     = vlog -work $(LIBDIR)/work -cover bst -sv -timescale=1ns/1ps -l comp.log +incdir+$(SIMDIR)/../mcdt
RUN       = vsim -work $(LIBDIR)/work -voptargs=+acc -classdebug -solvefaildebug -msgmode both -assertdebug -assertcounts $(TB) -l run.log -cover -cvgperinstance -cvgmergeinstances +sv_seed=$(SEED) +UVM_TESTNAME=$(TESTNAME)

comp:
	$(VCOMP) $(DFILES) $(VFILES)

run:
	$(RUN) -c -do "run -all; quit -f"

rung:
	$(RUN) -i

clean:
	rm -rf VRMDATA vrmhtmlreport
	rm -rf *.log* work *.wlf
