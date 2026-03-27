# defaults
SIM ?= verilator
#SIM ?= icarus
#SIM ?= modelsim
export SIM := $(SIM)
TOPLEVEL_LANG ?= verilog

export COCOTB_RESOLVE_X := ZEROS

VERILOG_SOURCES += \
        $(realpath ../../lib/pulp-common_cells/src/cf_math_pkg.sv) \
        $(realpath ../../lib/hyperbus/src/hyperbus_pkg.sv) \
        $(realpath ../../lib/pulp_axi/src/axi_pkg.sv) \
        $(realpath ../../rtl/top/my_bus_pkg.sv) \

VERILOG_SOURCES += \
        $(realpath ../../rtl/top/hyperbus_fpga_top.sv) \
        $(realpath ../../rtl/modules/uart_apb_top.sv) \

VERILOG_SOURCES += \
        ../../lib/hyperbus/src/hyperbus_axi.sv \
        ../../lib/hyperbus/src/hyperbus_cfg_regs.sv \
        ../../lib/hyperbus/src/hyperbus_clk_gen.sv \
        ../../lib/hyperbus/src/hyperbus_clock_diff_out.sv \
        ../../lib/hyperbus/src/hyperbus_ddr_out.sv \
        ../../lib/hyperbus/src/hyperbus_delay.sv \
        ../../lib/hyperbus/src/hyperbus_phy2r.sv \
        ../../lib/hyperbus/src/hyperbus_phy_if.sv \
        ../../lib/hyperbus/src/hyperbus_phy.sv \
        ../../lib/hyperbus/src/hyperbus.sv \
        ../../lib/hyperbus/src/hyperbus_synth_wrap.sv \
        ../../lib/hyperbus/src/hyperbus_trx.sv \
        ../../lib/hyperbus/src/hyperbus_w2phy.sv \
        ../../lib/hyperbus/models/configurable_delay.behav.sv \

VERILOG_SOURCES += \
        ../../lib/pulp-tech_cells_generic/src/rtl/tc_clk.sv \
        ../../lib/pulp-common_cells/src/cdc_fifo_gray.sv \
        ../../lib/pulp-common_cells/src/cdc_2phase.sv \
        ../../lib/pulp-common_cells/src/binary_to_gray.sv \
        ../../lib/pulp-common_cells/src/gray_to_binary.sv \
        ../../lib/pulp-common_cells/src/sync.sv \
        ../../lib/pulp-common_cells/src/spill_register.sv \
        ../../lib/pulp-common_cells/src/spill_register_flushable.sv \
        ../../lib/pulp-common_cells/src/fifo_v3.sv \
        ../../lib/pulp-common_cells/src/stream_register.sv \
        ../../lib/pulp-common_cells/src/stream_fifo.sv \
        ../../lib/pulp-common_cells/src/rr_arb_tree.sv \
        ../../lib/pulp-common_cells/src/addr_decode.sv \
        ../../lib/pulp-common_cells/src/addr_decode_dync.sv \
        ../../lib/pulp_axi/src/axi_atop_filter.sv \
        ../../lib/pulp_axi/src/axi_fifo.sv \
        ../../lib/pulp_axi/src/axi_serializer.sv \

VERILOG_SOURCES += \
        $(realpath ../../lib/rz-lib/rtl/sync/sync2edge.sv) \
        $(realpath ../../lib/wbuart32/rtl/rxuart.v) \
        $(realpath ../../lib/wbuart32/rtl/txuart.v) \

VERILOG_SOURCES += \
        $(realpath ./hyperbus_tb.sv)

#includes!
VERILOG_INCLUDE_DIRS += \
        ../../lib/pulp_axi/include/ \
        ../../lib/pulp-register_interface/include/ \
        ../../lib/pulp-common_cells/include/

ifeq ($(SIM),icarus)
        COMPILE_ARGS += -Wall
        COMPILE_ARGS += -v
        #COMPILE_ARGS += -g2005-sv
        COMPILE_ARGS += -DCOMMON_CELLS_ASSERTS_OFF
endif
ifeq ($(SIM),verilator)
        EXTRA_ARGS += --timing
        ifneq ($(WAVES),0)
                EXTRA_ARGS += --trace --trace-structs --trace-fst
        endif
        WNO = WIDTHTRUNC WIDTHEXPAND ASCRANGE EOFNEWLINE PINCONNECTEMPTY DECLFILENAME GENUNNAMED VARHIDDEN UNUSEDPARAM
        EXTRA_ARGS += -Wall $(WNO:%=-Wno-%)
        #EXTRA_ARGS += --bbox-unsup
        EXTRA_ARGS += +define+COMMON_CELLS_ASSERTS_OFF

        EXTRA_ARGS += -Wno-fatal

endif

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = hyperbus_tb

# MODULE is the basename of the Python test file
MODULE = hyperbus

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf __pycache__ results.xml obj_dir
	rm -rf dump.vcd dump.vcd.fst dump.vcd.fst.hier 
	rm -rf dump.fst dump.fst.hier 
	rm -rf transcript modelsim.ini vsim.wlf vsim_stacktrace.vstf vish_stacktrace.vstf
