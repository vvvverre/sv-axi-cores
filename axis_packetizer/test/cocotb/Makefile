TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = axis_packetizer
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)

VERILOG_SOURCES += ../../rtl/$(DUT).sv


export PARAM_DATA_WIDTH ?= 16
export PARAM_COUNTER_WIDTH ?= 16
export PARAM_OPT_REGISTER ?= 0


ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).DATA_WIDTH=$(PARAM_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).COUNTER_WIDTH=$(PARAM_COUNTER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).OPT_REGISTER=$(PARAM_OPT_REGISTER)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif

else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GDATA_WIDTH=$(PARAM_DATA_WIDTH)
	COMPILE_ARGS += -GCOUNTER_WIDTH=$(PARAM_COUNTER_WIDTH)
	COMPILE_ARGS += -OPT_REGISTER=$(PARAM_OPT_REGISTER)

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
