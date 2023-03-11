# Makefile

# defaults
SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl
EXTRA_ARGS += --std=08
SIM_ARGS += --wave=wave.ghw

VHDL_SOURCES += $(PWD)/sdram_controller_pkg.vhd
VHDL_SOURCES += $(PWD)/delay_counter.vhd
VHDL_SOURCES += $(PWD)/sdram_control_bus.vhd
VHDL_SOURCES += $(PWD)/sdram_data_bus.vhd
VHDL_SOURCES += $(PWD)/sdram_FSM.vhd
VHDL_SOURCES += $(PWD)/sdram_top.vhd
VHDL_SOURCES += $(PWD)/mt48lc64m4a2.vhd
VHDL_SOURCES += $(PWD)/top.vhd
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
# MODULE is the basename of the Python test file

test:
		rm -rf sim_build
		$(MAKE) sim MODULE=testbench TOPLEVEL=top
		
formal_fsm :
		sby --yosys "yosys -m ghdl" -f sdram_FSM.sby
# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim