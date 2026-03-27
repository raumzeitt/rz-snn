module hyperbus_tb (
    input wire          clk,
    input wire          rst_n,

    // physical UART pins
    input wire          uart_rx,
    output wire         uart_tx
);
import my_bus_pkg::*;

// HyperBus Pads
wire [NumChips-1:0] pad_hyper_csn;
wire            pad_hyper_ck;
wire            pad_hyper_ckn;
wire            pad_hyper_reset;
tri1            pad_hyper_rwds;
tri1 [7:0]      pad_hyper_dq;

hyperbus_fpga_top hyperbus_fpga_top(.*);

endmodule
