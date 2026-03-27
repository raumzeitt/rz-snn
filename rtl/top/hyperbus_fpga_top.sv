module hyperbus_fpga_top (
    input  wire        clk,
    input  wire        rst_n,

    // physical UART pins
    input  wire        uart_rx,
    output wire        uart_tx
);

logic[7:0]   PADDR;
logic        PSEL;
logic        PENABLE;
logic        PWRITE;
logic[7:0]   PWDATA;
logic[7:0]   PRDATA;
logic        PREADY;

always_comb PREADY = 1;
always_comb PRDATA = '0;
uart_apb_top uart_apb_top (.*);

endmodule
