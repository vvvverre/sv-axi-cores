TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = axis_bram_writer
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)

VERILOG_SOURCES += ../../rtl/$(DUT)_trigger.sv


export PARAM_DATA_WIDTH ?= 16
export PARAM_ADDR_WIDTH ?= 12
export PARAM_OPT_TSTRB ?= 0
export PARAM_OPT_TRIGGER ?= 0


ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).DATA_WIDTH=$(PARAM_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).ADDR_WIDTH=$(PARAM_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).OPT_TSTRB=$(PARAM_OPT_TSTRB)
	COMPILE_ARGS += -P $(TOPLEVEL).OPT_TRIGGER=$(PARAM_OPT_TRIGGER)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif

else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GDATA_WIDTH=$(PARAM_DATA_WIDTH)
	COMPILE_ARGS += -GADDR_WIDTH=$(PARAM_ADDR_WIDTH)
	COMPILE_ARGS += -GOPT_TSTRB=$(PARAM_OPT_TSTRB)
	COMPILE_ARGS += -GOPT_TRIGGER=$(PARAM_OPT_TRIGGER)

	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
	endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

iverilog_dump.v:
	echo 'module iverilog_dump();' > $@
	echo 'initial begin' >> $@
	echo '    $$dumpfile("$(TOPLEVEL).fst");' >> $@
	echo '    $$dumpvars(0, $(TOPLEVEL));' >> $@
	echo 'end' >> $@
	echo 'endmodule' >> $@

clean::
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst $(TOPLEVEL).fst
