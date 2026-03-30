module hyperbus_tb (
    input wire          clk,
    input wire          rst_n,

    // physical UART pins
    input wire          uart_rx,
    output wire         uart_tx
);
import my_bus_pkg::*;

// Needed for simulation w/ xilinx/verilator
`ifdef GLBL_INSTANCE
glbl glbl();
`endif

// HyperBus Pads
wire [NumChips-1:0] pad_hyper_csn;
wire            pad_hyper_ck;
wire            pad_hyper_ckn;
wire            pad_hyper_reset_n;
wire            pad_hyper_rwds;
wire [7:0]      pad_hyper_dq;

hyperbus_fpga_top hyperbus_fpga_top(.*);
//s80ks5122 s80ks5122 ( );
endmodule
