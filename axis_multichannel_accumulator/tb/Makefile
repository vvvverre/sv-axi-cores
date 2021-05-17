# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/../../axis_skid_buffer/rtl/axis_skid_buffer.sv $(PWD)/../rtl/axis_multichannel_accumulator.sv 
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = axis_multichannel_accumulator

# MODULE is the basename of the Python test file
MODULE = axis_multichannel_accumulator

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
