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

generate
for (genvar i=0; i<2;i=i+1) begin: s80ks5122
s80ks5122 s80ks5122 (
    .DQ7(pad_hyper_dq[7]),
    .DQ6(pad_hyper_dq[6]),
    .DQ5(pad_hyper_dq[5]),
    .DQ4(pad_hyper_dq[4]),
    .DQ3(pad_hyper_dq[3]),
    .DQ2(pad_hyper_dq[2]),
    .DQ1(pad_hyper_dq[1]),
    .DQ0(pad_hyper_dq[0]),
    .RWDS(pad_hyper_rwds),
    .CSNeg(pad_hyper_csn[i]),
    .CK(pad_hyper_ck),
    .CKn(pad_hyper_ckn),
    .RESETNeg(pad_hyper_reset_n)
);
end
endgenerate
endmodule
