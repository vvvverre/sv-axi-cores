TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = axi_axis_streamer
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)

VERILOG_SOURCES += ../../rtl/$(DUT).sv
VERILOG_SOURCES += ../../../axi_bram_interface/rtl/axi_bram_interface.sv
VERILOG_SOURCES += ../../../axis_bram_reader/rtl/axis_bram_reader.sv
VERILOG_SOURCES += ../../../bram/rtl/bram.sv


export PARAM_AXI_DATA_WIDTH ?= 32
export PARAM_AXI_ADDR_WIDTH ?= 12
export PARAM_DATA_WIDTH ?= 14

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).AXI_DATA_WIDTH=$(PARAM_AXI_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXI_ADDR_WIDTH=$(PARAM_AXI_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).DATA_WIDTH=$(PARAM_DATA_WIDTH)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif

else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GAXI_AXI_DATA_WIDTH=$(PARAM_AXI_DATA_WIDTH)
	COMPILE_ARGS += -GAXI_AXI_ADDR_WIDTH=$(PARAM_AXI_ADDR_WIDTH)
	COMPILE_ARGS += -GAXI_DATA_WIDTH=$(PARAM_DATA_WIDTH)

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
