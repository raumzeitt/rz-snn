/*
READ:  [(N-1)*16|0x02][ADDR] returns [N data bytes]
WRITE: [(N-1)*16|0x01][ADDR][N data bytes]

APB addresses increment after each transfer and wrap at 256.
No RX FIFO: each write must complete before the next UART byte arrives.

PC          FPGA(UART)     APB
 |               |           |
 |--[0x02]-----> |           |
 |--[ADDR]-----> |           |
 |               |--SETUP--> |
 |               |--ACCESS-> |
 |               |<-PRDATA-- |
 |               |<-READY--- |
 |<--[DATA]------|           |

PC          FPGA(UART)     APB
 |               |           |
 |--[0x01]-----> |           |
 |--[ADDR]-----> |           |
 |--[DATA]-----> |           |
 |               |--SETUP--> |
 |               |--ACCESS-> |
 |               |--PWDATA-> |
 |               |<-READY--- |

*/
`include "uart_config.vh"

module uart_apb_top (
    input  logic        clk,
    input  logic        rst_n,

    // UART pins
    input  logic        uart_rx,
    output logic        uart_tx,

    // APB master
    output logic[7:0]   PADDR,
    output logic        PSEL,
    output logic        PENABLE,
    output logic        PWRITE,
    output logic[7:0]   PWDATA,
    input  logic[7:0]   PRDATA,
    input  logic        PREADY
);

localparam [23:0] DIVISOR = `UART_DIVISOR;

logic [7:0]     rx_data;
logic           rx_valid;
logic [7:0]     tx_data;
logic           tx_valid;
logic           tx_busy;

typedef enum logic[1:0] { U_IDLE, U_ADDR, U_DATA} ustate_t;
typedef enum logic { U_RD=0, U_WR=1} ucmd_t; 

ustate_t        ustate;
ucmd_t          cmd;
logic [7:0]     addr;
logic [4:0]     byte_count; // Remaining bytes; zero means done

typedef enum logic[1:0] {A_IDLE=0, A_SETUP=1, A_ACCESS=3} pstate_t;
pstate_t        pstate;


// UART shifter
rxuart #(
    .INITIAL_SETUP({7'h0, DIVISOR})
) u_rx (
    .i_clk      (clk),
    .i_reset    (~rst_n),
    .i_setup    ({7'h0, DIVISOR}),
    .i_uart_rx  (uart_rx),
    .o_wr       (rx_valid),
    .o_data     (rx_data),
    .o_break    ( ),
    .o_parity_err ( ),
    .o_frame_err ( ),
    .o_ck_uart  ( )
);

txuart #(
    .INITIAL_SETUP({7'h0, DIVISOR})
) u_tx (
    .i_clk      (clk),
    .i_reset    (~rst_n),
    .i_setup    ({7'h0, DIVISOR}),
    .i_break    (1'b0), // no break
    .i_wr       (tx_valid),
    .i_data     (tx_data),
    .i_cts_n    (1'b0), // no flow control
    .o_uart_tx  (uart_tx),
    .o_busy     (tx_busy)
);  


// UART FSM

always @(posedge clk or negedge rst_n)
if (~rst_n)
    ustate      <= U_IDLE;
else if (rx_valid)
    case (ustate)
    U_IDLE: if (rx_data[3:0] == 1 | rx_data[3:0] == 2) ustate <= U_ADDR;
    U_ADDR: ustate <= cmd == U_WR ? U_DATA : U_IDLE; // write/read
    U_DATA: if (byte_count == 0) ustate <= U_IDLE;
    default: ustate <= ustate_t'('x);
    endcase


always @(posedge clk)
if (rx_valid) begin
    if (ustate==U_IDLE & (rx_data[3:0] == 1 | rx_data[3:0] == 2)) cmd <= ucmd_t'(rx_data);
end 

// load count/address and update both on APB completion
always @(posedge clk or negedge rst_n)
if (~rst_n)
    byte_count <= 5'b1xxxx;
else if (rx_valid) begin
    if (ustate==U_IDLE & (rx_data[3:0] == 1 | rx_data[3:0] == 2))
        byte_count <= rx_data[7:4]; // Upper nibble encodes N-1
    if (ustate==U_ADDR)
        addr <= rx_data;
end else if (PENABLE && PREADY) begin
    byte_count <= byte_count - 1;
    addr <= addr + 1;
end

// APB Master FSM

always @(posedge clk or negedge rst_n)
if (~rst_n)
    pstate  <= A_IDLE;
else
    case (pstate)
    A_IDLE: if (cmd==U_WR ? (ustate==U_DATA & rx_valid) : (ustate==U_IDLE & !tx_busy & ~byte_count[4])) pstate <= A_SETUP;
    A_SETUP:  pstate <= A_ACCESS;
    A_ACCESS: if(PREADY)  pstate <= A_IDLE;
    default: pstate <= pstate_t'('x);
    endcase

always_comb PADDR = addr;
always_comb {PENABLE, PSEL} = pstate;
always_comb PWRITE = cmd;
always_comb PWDATA = rx_data;

always_comb tx_valid = ~PWRITE & PENABLE & PREADY; //&PSEL
always_comb tx_data = PRDATA;
//always_comb tx_data = PRDATA;
endmodule
