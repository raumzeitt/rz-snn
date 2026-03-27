# defaults
SIM ?= verilator
#SIM ?= icarus
#SIM ?= modelsim
export SIM := $(SIM)
TOPLEVEL_LANG ?= verilog

export COCOTB_RESOLVE_X := ZEROS

VERILOG_SOURCES += \
        $(realpath ../../rtl/modules/uart_apb_top.sv) \
        $(realpath ../../lib/rz-lib/rtl/sync/sync2edge.sv) \
        $(realpath ../../lib/wbuart32/rtl/rxuart.v) \
        $(realpath ../../lib/wbuart32/rtl/txuart.v) \

#VERILOG_INCLUDE_DIRS += ../../rtl/spi

ifeq ($(SIM),icarus)
        COMPILE_ARGS += -Wall
        COMPILE_ARGS += -v
        #COMPILE_ARGS += -g2005-sv
endif
ifeq ($(SIM),verilator)
        EXTRA_ARGS += --timing
        ifneq ($(WAVES),0)
                EXTRA_ARGS += --trace --trace-structs --trace-fst
        endif
        WNO = WIDTHTRUNC WIDTHEXPAND ASCRANGE EOFNEWLINE PINCONNECTEMPTY DECLFILENAME GENUNNAMED VARHIDDEN UNUSEDPARAM
        EXTRA_ARGS += -Wall $(WNO:%=-Wno-%)
endif

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = uart_apb_top

# MODULE is the basename of the Python test file
MODULE = uart

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf __pycache__ results.xml obj_dir
	rm -rf dump.vcd dump.vcd.fst dump.vcd.fst.hier 
	rm -rf dump.fst dump.fst.hier 
	rm -rf transcript modelsim.ini vsim.wlf vsim_stacktrace.vstf vish_stacktrace.vstf
