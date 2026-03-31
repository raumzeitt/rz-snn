# defaults
SIM ?= verilator
#SIM ?= icarus
#SIM ?= modelsim
export SIM := $(SIM)
TOPLEVEL_LANG ?= verilog

# Xilinx tools
# Env variable: XILINX_VIVADO=/tools/Xilinx/Vivado/2023.2
# make sure XILINX_VIVADO is set
XILINX_UNISIMS = $(XILINX_VIVADO)/data/verilog/src/unisims

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

# Download sim model from:
# "https://www.infineon.com/assets/row/public/documents/10/50/infineon-s27kl0641-s27ks0641-verilog-simulationmodels-en.zip"
# or
# https://www.infineon.com/gated/infineon-s27kl0641-s27ks0641-verilog-simulationmodels-en_2a2bc13c-621c-436e-ab1b-e58c9bdb449c
# old link from PULP HyperBus Makefile no longer works

VERILOG_SOURCES += s80ks5122.verilator.v

        #002-32555/hbus/s80ks5122.v \
        #S27KL0641_S27KS0641/S27kl0641/model/s27kl0641.v \

# Xilinx primitives      
VERILOG_SOURCES += \
        $(XILINX_VIVADO)/data/verilog/src/glbl.v \
        $(XILINX_UNISIMS)/IOBUF.v \
        $(XILINX_UNISIMS)/OBUF.v \
        $(XILINX_UNISIMS)/IBUF.v \


#include directories
VERILOG_INCLUDE_DIRS += \
        ../../lib/pulp_axi/include/ \
        ../../lib/pulp-register_interface/include/ \
        ../../lib/pulp-common_cells/include/


# Defines section
COMMON_DEFINES += \
        GLBL_INSTANCE \

ifeq ($(SIM),icarus)
        COMPILE_ARGS += $(COMMON_DEFINES:%=-D%)
        COMPILE_ARGS += -Wall
        COMPILE_ARGS += -v
        #COMPILE_ARGS += -g2005-sv
        COMPILE_ARGS += -DCOMMON_CELLS_ASSERTS_OFF
endif
ifeq ($(SIM),verilator)
        EXTRA_ARGS += $(COMMON_DEFINES:%=+define+%)
        EXTRA_ARGS += --timing
        ifneq ($(WAVES),0)
                EXTRA_ARGS += --trace --trace-structs --trace-fst
        endif
        WNO = WIDTHTRUNC WIDTHEXPAND ASCRANGE EOFNEWLINE PINCONNECTEMPTY DECLFILENAME GENUNNAMED VARHIDDEN UNUSEDPARAM
        EXTRA_ARGS += -Wall $(WNO:%=-Wno-%)
        #EXTRA_ARGS += --bbox-unsup
        EXTRA_ARGS += +define+COMMON_CELLS_ASSERTS_OFF

        EXTRA_ARGS += -Wno-fatal
        EXTRA_ARGS += -DVM_TIMING=0
        #EXTRA_ARGS += --trace
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
