/*
From TB:
    localparam time SYS_TCK  = 4ns; // = 250MHz
    localparam time PHY_TCK  = 6ns; // = 166MHz
*/

module hyperbus_fpga_top (
    input wire          clk,
    input wire          rst_n,

    // physical UART pins
    input wire          uart_rx,
    output wire         uart_tx,

    // HyperBus Pads
    output wire [my_bus_pkg::NumChips-1:0] pad_hyper_csn,
    output wire         pad_hyper_ck,
    output wire         pad_hyper_ckn,
    output wire         pad_hyper_reset_n,

    inout wire          pad_hyper_rwds,
    inout wire  [7:0]   pad_hyper_dq
);
import my_bus_pkg::*;

// Uart
logic           uart_rx_w;
logic           uart_tx_w;

// APB signals
localparam N_APB = 2;
logic[7:0]      PADDR;
logic           PSEL;
logic           PENABLE;
logic           PWRITE;
logic[7:0]      PWDATA;
logic[7:0]      PRDATA;
logic           PREADY;
logic[N_APB-1:0] local_psel;


// AXI flattened signals for cocotb
// AW 
logic [5:0]     axi_awid;       // = '0;
logic [31:0]    axi_awaddr;
logic [7:0]     axi_awlen;
logic [2:0]     axi_awsize;     // = 3'b010; (*)
logic [1:0]     axi_awburst;    // = 2'b01; (*)
logic           axi_awlock;     // = 1'b0;
logic [3:0]     axi_awcache;    // = 4'b0000;
logic [2:0]     axi_awprot;     // = 3'b000;
logic [3:0]     axi_awqos;      // = 4'b0000;
logic [3:0]     axi_awregion;   // = 4'b0000;
logic [0:0]     axi_awuser;     // = '0;
logic           axi_awvalid;
logic           axi_awready;
// W 
logic [31:0]    axi_wdata;
logic [3:0]     axi_wstrb;      // = 4'b1111; (*)
logic           axi_wlast;
logic [0:0]     axi_wuser;      // ignore
logic           axi_wvalid;
logic           axi_wready;
// B
logic [5:0]     axi_bid;        // ignore
logic [1:0]     axi_bresp;      // optional check
logic [0:0]     axi_buser;      // ignore
logic           axi_bvalid;
logic           axi_bready;
// AR
logic [5:0]     axi_arid;       // = '0;
logic [31:0]    axi_araddr;
logic [7:0]     axi_arlen;
logic [2:0]     axi_arsize;     // = 3'b010; (*)
logic [1:0]     axi_arburst;    // = 2'b01; (*)
logic           axi_arlock;     // = 1'b0;
logic [3:0]     axi_arcache;    // = 4'b0000;
logic [2:0]     axi_arprot;     // = 3'b000;
logic [3:0]     axi_arqos;      // = 4'b0000;
logic [3:0]     axi_arregion;   // = 4'b0000;
logic [0:0]     axi_aruser;     // = '0;
logic           axi_arvalid;
logic           axi_arready;
// R 
logic [5:0]     axi_rid;        // ignore
logic [31:0]    axi_rdata;
logic [1:0]     axi_rresp;      // optional check
logic           axi_rlast;
logic [0:0]     axi_ruser;      // ignore
logic           axi_rvalid;
logic           axi_rready;

// hyperbus/axi
axi_req_t       axi_req;
axi_resp_t      axi_rsp;
// hyperbus/apb
reg_req_t       reg_req;
reg_rsp_t       reg_rsp;

// hyperbus/IO
logic [NumChips-1:0] hyper_csn_o;
logic           hyper_ck_o;
logic           hyper_ckn_o;
logic           hyper_rwds_o;
logic           hyper_rwds_i;
logic           hyper_rwds_oe_o;
logic [7:0]     hyper_dq_i;
logic [7:0]     hyper_dq_o;
logic           hyper_dq_oe_o;
logic           hyper_reset_n_o;


//  UART
IBUF u_ibuf_uart_rx(.I(uart_rx), .O(uart_rx_w));
OBUF u_obuf_uart_rx(.I(uart_tx_w), .O(uart_tx));
uart_apb_top uart_apb_top (.uart_rx(uart_rx_w), .uart_tx(uart_tx_w), .*);

//  APB 
//  0 = hyperbus
//  1 = perf fsm
// Hyperbus:
// Internal Parameters
localparam int unsigned NumBaseRegs     = 11;
localparam int unsigned NumRegs         = 2*NumChips + NumBaseRegs; // = 2*2 + 11 = 15 ($clog2(NumRegs) = 4)

always_comb local_psel[0] = PADDR[7:6]==0 & PADDR[5:2]<NumRegs; 
always_comb local_psel[1] = PADDR[7:6]==1; 

// hook up hyperbus APB

/*-->
ADDR   NAME                     USED BITS      DESCRIPTION
---------------------------------------------------------------------------
0x00   CRANGE0_START            [31:0]         AXI base -> chip 0
0x04   CRANGE0_END              [31:0]         AXI end   -> chip 0
0x08   CRANGE1_START            [31:0]         AXI base -> chip 1
0x0C   CRANGE1_END              [31:0]         AXI end   -> chip 1
0x10   T_CSH_CYCLES             [7:0]          CS high time
0x14   WHICH_PHY                UNUSED         (NumPhys=1 -> always 0)
0x18   PHYS_IN_USE              UNUSED         (NumPhys=1 -> always 1)
0x1C   ADDRESS_SPACE            [0:0]          0=memory, 1=register
0x20   ADDRESS_MASK_MSB         [5:0]          address width limit
0x24   T_TX_CLK_DELAY           [7:0]          TX delay
0x28   T_RX_CLK_DELAY           [7:0]          RX delay
0x2C   T_RW_RECOVERY            [7:0]          readâ->write delay
0x30   T_BURST_MAX              [7:0]          max burst
0x34   EN_LATENCY_ADDITIONAL    [0:0]          extra latency
0x38   T_LATENCY_ACCESS         [4:0]          base latency
*/

always_comb begin
    // not used: reg_rsp.error
    PRDATA = ({8{local_psel[0]}} & (reg_rsp.rdata[31:0] >> (8*PADDR[1:0]))) |
                ({8{local_psel[1]}} & 8'h00);
    PREADY = local_psel==0 ? 1 : |(local_psel & {1'b1, 1'b1, reg_rsp.ready});
end 

always_comb begin
    reg_req.addr = {24'h0, PADDR[7:2], 2'b00}; // 00 = LSB
    reg_req.valid = local_psel[0] & PSEL & PENABLE;
    reg_req.wdata = {4{PWDATA[7:0]}};
    reg_req.write = PWRITE;
    reg_req.wstrb = 1<<PADDR[1:0];
end


// ==========================================================
// AXI MASTER SIGNAL GUIDE (for hyperbus)
// ==========================================================
//
// YOU DRIVE (inputs to hyperbus / AXI slave)
// ------------------------------------------
//
// ---- WRITE ADDRESS CHANNEL (AW) ----
// aw_valid    : assert when issuing write address
// aw.addr     : target address
// aw.len      : number of beats - 1
// aw.size     : transfer size (e.g. 3'b010 for 32-bit)
// aw.burst    : burst type (use 2'b01 = INCR)
//
// aw.id       : tie to 0
// aw.user     : tie to 0
// aw.cache    : tie to 0
// aw.prot     : tie to 0
// aw.qos      : tie to 0
// aw.region   : tie to 0
// aw.lock     : tie to 0
//
// ---- WRITE DATA CHANNEL (W) ----
// w_valid     : assert when data is valid
// w.data      : write data
// w.strb      : byte enable (e.g. 4'b1111 for 32-bit)
// w.last      : 1 on final beat of burst
//
// w.user      : tie to 0
//
// ---- READ ADDRESS CHANNEL (AR) ----
// ar_valid    : assert when issuing read request
// ar.addr     : target address
// ar.len      : number of beats - 1
// ar.size     : transfer size (e.g. 3'b010 for 32-bit)
// ar.burst    : burst type (use 2'b01 = INCR)
//
// ar.id       : tie to 0
// ar.user     : tie to 0
// ar.cache    : tie to 0
// ar.prot     : tie to 0
// ar.qos      : tie to 0
// ar.region   : tie to 0
// ar.lock     : tie to 0
//
// ---- RESPONSE READY (MASTER SIDE) ----
// r_ready     : set to 1 (always accept read data)
// b_ready     : set to 1 (always accept write response)
//
// YOU SAMPLE (outputs from hyperbus / AXI slave)
// ----------------------------------------------
//
// ---- WRITE ADDRESS HANDSHAKE ----
// aw_ready    : address accepted when (aw_valid && aw_ready)
//
// ---- WRITE DATA HANDSHAKE ----
// w_ready     : data accepted when (w_valid && w_ready)
//
// ---- WRITE RESPONSE ----
// b_valid     : write response valid
// b.resp      : response code (optional check)
// b.id        : ignore (always 0 in this core)
// b.user      : ignore
//
// ---- READ ADDRESS HANDSHAKE ----
// ar_ready    : read request accepted when (ar_valid && ar_ready)
//
// ---- READ DATA ----
// r_valid     : read data valid
// r.data      : read data
// r.last      : last beat of burst
// r.resp      : response code (optional check)
// r.id        : ignore (always 0)
// r.user      : ignore
//
// ==========================================================
// RULES (IMPORTANT)
// ==========================================================
//
// Burst:
//    number of beats = len + 1
//    w.last must be asserted on final beat
//
// Alignment:
//    addr must match size (e.g. 4-byte aligned for 32-bit)
//
// Handshake logic 
//      aw_valid && axi_rsp.aw_ready     address accepted
//      w_valid  && axi_rsp.w_ready      data accepted
//      ar_valid && axi_rsp.ar_ready     read accepted
// ==========================================================

// Flat AXI wires <-> axi_req_t / axi_rsp_t bridge
// AW
assign axi_req.aw.id        = axi_awid;
assign axi_req.aw.addr      = axi_awaddr;
assign axi_req.aw.len       = axi_awlen;
assign axi_req.aw.size      = axi_awsize;
assign axi_req.aw.burst     = axi_awburst;
assign axi_req.aw.lock      = axi_awlock;
assign axi_req.aw.cache     = axi_awcache;
assign axi_req.aw.prot      = axi_awprot;
assign axi_req.aw.qos       = axi_awqos;
assign axi_req.aw.region    = axi_awregion;
assign axi_req.aw.user      = axi_awuser;
assign axi_req.aw_valid     = axi_awvalid;
assign axi_awready          = axi_rsp.aw_ready;
// W
assign axi_req.w.data       = axi_wdata;
assign axi_req.w.strb       = axi_wstrb;
assign axi_req.w.last       = axi_wlast;
assign axi_req.w.user       = axi_wuser;
assign axi_req.w_valid      = axi_wvalid;
assign axi_wready           = axi_rsp.w_ready;
// B
assign axi_bid              = axi_rsp.b.id;
assign axi_bresp            = axi_rsp.b.resp;
assign axi_buser            = axi_rsp.b.user;
assign axi_bvalid           = axi_rsp.b_valid;
assign axi_req.b_ready      = axi_bready;
// AR
assign axi_req.ar.id        = axi_arid;
assign axi_req.ar.addr      = axi_araddr;
assign axi_req.ar.len       = axi_arlen;
assign axi_req.ar.size      = axi_arsize;
assign axi_req.ar.burst     = axi_arburst;
assign axi_req.ar.lock      = axi_arlock;
assign axi_req.ar.cache     = axi_arcache;
assign axi_req.ar.prot      = axi_arprot;
assign axi_req.ar.qos       = axi_arqos;
assign axi_req.ar.region    = axi_arregion;
assign axi_req.ar.user      = axi_aruser;
assign axi_req.ar_valid     = axi_arvalid;
assign axi_arready          = axi_rsp.ar_ready;
// R
assign axi_rid              = axi_rsp.r.id;
assign axi_rdata            = axi_rsp.r.data;
assign axi_rresp            = axi_rsp.r.resp;
assign axi_rlast            = axi_rsp.r.last;
assign axi_ruser            = axi_rsp.r.user;
assign axi_rvalid           = axi_rsp.r_valid;
assign axi_req.r_ready      = axi_rready;


//  HYPERBUS
hyperbus #(
    .NumChips(NumChips),
    .NumPhys(NumPhys),

    // AXI widths (from your pkg)
    .AxiAddrWidth(AxiAddrWidth),
    .AxiDataWidth(AxiDataWidth),
    .AxiIdWidth(AxiIdWidth),
    .AxiUserWidth(AxiUserWidth),

    // AXI types (from macros)
    .axi_req_t(axi_req_t),
    .axi_rsp_t(axi_resp_t),
    .axi_aw_chan_t(axi_aw_chan_t),
    .axi_w_chan_t(axi_w_chan_t),
    .axi_b_chan_t(axi_b_chan_t),
    .axi_ar_chan_t(axi_ar_chan_t),
    .axi_r_chan_t(axi_r_chan_t),

    // REG widths + types
    .RegAddrWidth(RegAw),
    .RegDataWidth(RegDw),
    .reg_req_t(reg_req_t),
    .reg_rsp_t(reg_rsp_t)

) i_hyperbus (
    // clocks / reset
    .clk_phy_i(clk),
    .rst_phy_ni(rst_n),
    .clk_sys_i(clk),
    .rst_sys_ni(rst_n),
    .test_mode_i(1'b0),

    // AXI
    .axi_req_i(axi_req),
    .axi_rsp_o(axi_rsp),

    // REG
    .reg_req_i(reg_req),
    .reg_rsp_o(reg_rsp),

    // HyperBus PHY
    .hyper_cs_no(hyper_csn_o),
    .hyper_ck_o(hyper_ck_o),
    .hyper_ck_no(hyper_ckn_o),
    .hyper_rwds_o(hyper_rwds_o),
    .hyper_rwds_i(hyper_rwds_i),
    .hyper_rwds_oe_o(hyper_rwds_oe_o),
    .hyper_dq_i(hyper_dq_i),
    .hyper_dq_o(hyper_dq_o),
    .hyper_dq_oe_o(hyper_dq_oe_o),
    .hyper_reset_no(hyper_reset_n_o)
);

OBUF u_obuf_hyper_csn[NumChips-1:0] (.I(hyper_csn_o), .O(pad_hyper_csn));
OBUF u_obuf_hyper_ck (.I( hyper_ck_o ), .O( pad_hyper_ck ));
OBUF u_obuf_hyper_ckn (.I( hyper_ckn_o ), .O( pad_hyper_ckn ));
OBUF u_obuf_hyper_resetn (.I( hyper_reset_n_o ), .O( pad_hyper_reset_n ));

IOBUF #(
    .DRIVE        (12), 
    .IBUF_LOW_PWR ("TRUE"), // Low Power:"TRUE", High Performance:"FALSE"
    .IOSTANDARD   ("DEFAULT"),
    .SLEW         ("SLOW") 
) u_iobuf_hyper_dq[7:0] (
    .IO (pad_hyper_dq), //io pad
    .O  (hyper_dq_i), //o
    .I  (hyper_dq_o), //i
    .T  ({8{~hyper_dq_oe_o}})  //t: 3-state enable: 1=input, 0=output (T=0 drives I to IO)
);

IOBUF #(
    .DRIVE        (12), 
    .IBUF_LOW_PWR ("TRUE"), // Low Power:"TRUE", High Performance:"FALSE"
    .IOSTANDARD   ("DEFAULT"),
    .SLEW         ("SLOW") 
) u_iobuf_hyper_rwds (
    .IO (pad_hyper_rwds), //io pad
    .O  (hyper_rwds_i), //o
    .I  (hyper_rwds_o), //i
    .T  (~hyper_rwds_oe_o)  //t: 3-state enable: 1=input, 0=output (T=0 drives I to IO)
);

endmodule
