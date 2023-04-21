# Makefile

# defaults
SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl
EXTRA_ARGS += --std=08
SIM_ARGS += --wave=wave.ghw

VHDL_SOURCES += $(PWD)/../rtl/wb_regs.vhd
VHDL_SOURCES += $(PWD)/../rtl/axil_regs.vhd
VHDL_SOURCES += $(PWD)/../rtl/sdram_controller_pkg.vhd
VHDL_SOURCES += $(PWD)/../rtl/delay_counter.vhd
VHDL_SOURCES += $(PWD)/../rtl/sdram_control_bus.vhd
VHDL_SOURCES += $(PWD)/../rtl/sdram_data_bus.vhd
VHDL_SOURCES += $(PWD)/../rtl/sdram_FSM.vhd
VHDL_SOURCES += $(PWD)/../rtl/sdram_top.vhd
VHDL_SOURCES += $(PWD)/../rtl/mt48lc64m4a2.vhd
VHDL_SOURCES += $(PWD)/../rtl/top.vhd
VHDL_SOURCES += $(PWD)/../rtl/top_axi.vhd
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
# MODULE is the basename of the Python test file

test:
		rm -rf sim_build
		$(MAKE) sim MODULE=testbench TOPLEVEL=top
		
test_axi:
		rm -rf sim_build
		$(MAKE) sim MODULE=testbench_axi TOPLEVEL=top_axi

formal_fsm :
		sby --yosys "yosys -m ghdl" -f sdram_FSM.sby
# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim