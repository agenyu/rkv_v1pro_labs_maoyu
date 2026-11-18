#############################
# User variables
#############################
TB      ?= tb1
SIMDIR  ?= .
LIBDIR  ?= .

DFILES  = $(SIMDIR)/../mcdt/arbiter.v \
          $(SIMDIR)/../mcdt/slave_fifo.v \
          $(SIMDIR)/../mcdt/mcdt.v
VFILES  = $(SIMDIR)/$(TB).v


#############################
# Environment variables
#############################
VCOMP   = vlog -work $(LIBDIR)/work -sv -timescale=1ns/1ps -l comp.log +incdir+$(SIMDIR)/../mcdt
RUN     = vsim -voptargs=+acc -work $(LIBDIR)/work $(TB) -l run.log 

comp:
	$(VCOMP) $(DFILES) $(VFILES)

run:
	$(RUN) -c

rung:
	$(RUN) -i

clean:
	rm -rf *.log* work *.wlf
