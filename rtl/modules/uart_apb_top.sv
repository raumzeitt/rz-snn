/*
READ:  [0x02][ADDR] returns [DATA]
WRITE: [0x01][ADDR][DATA] returns [0x55]

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

(|<--[0x55]------|           |)
 
 */
module uart_apb_top #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD     = 115200
)(
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

localparam [23:0] DIVISOR = 868; //=CLK_FREQ/BAUD;

logic [7:0]     rx_data;
logic           rx_valid;
logic [7:0]     tx_data;
logic           tx_valid;

typedef enum logic[1:0] { U_IDLE, U_ADDR, U_DATA} ustate_t; 
typedef enum logic { U_RD=0, U_WR=1} ucmd_t; 

ustate_t        ustate;
ucmd_t          cmd;
logic [7:0]     addr;
logic           u_exec;

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
    .o_busy     ( )
);  


// UART FSM

always @(posedge clk)
if (~rst_n) 
    ustate      <= U_IDLE;
else if (rx_valid)
    case (ustate)
    U_IDLE: if (rx_data == 1 | rx_data == 2) ustate <= U_ADDR;
    U_ADDR: ustate <= cmd == U_WR ? U_DATA : U_IDLE; // write/read
    U_DATA: ustate <= U_IDLE;
    default: ustate <= ustate_t'('x);
    endcase

always_comb  u_exec = rx_valid & (cmd == U_WR ? ustate==U_DATA : ustate==U_ADDR);

always @(posedge clk)
if (rx_valid) begin
    if (ustate==U_IDLE & (rx_data == 1 | rx_data == 2)) cmd <= ucmd_t'(rx_data);
    if (ustate==U_ADDR)                                 addr <= rx_data;
end

// APB Master FSM

always @(posedge clk)
if (~rst_n)
    pstate  <= A_IDLE;
else
    case (pstate)
    A_IDLE: if (u_exec)  pstate <= A_SETUP;
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
//always_comb tx_data = cmd==U_WR ? 8'h55 : PRDATA;
endmodule
