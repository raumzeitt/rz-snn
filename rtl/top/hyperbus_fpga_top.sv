module hyperbus_fpga_top (
    input wire          clk,
    input wire          rst_n,

    // physical UART pins
    input wire          uart_rx,
    output wire         uart_tx,

    // HyperBus Pads
    output logic [NumChips-1:0] pad_hyper_csn,
    output logic        pad_hyper_ck,
    output logic        pad_hyper_ckn,
    output logic        pad_hyper_reset,

    inout wire          pad_hyper_rwds,
    inout wire  [7:0]   pad_hyper_dq
);
import my_bus_pkg::*;

// uart signals
logic[7:0]      PADDR;
logic           PSEL;
logic           PENABLE;
logic           PWRITE;
logic[7:0]      PWDATA;
logic[7:0]      PRDATA;
logic           PREADY;

// hyperbus/axi
axi_req_t       axi_req;
axi_resp_t      axi_rsp;

reg_req_t       reg_req;
reg_rsp_t       reg_rsp;


logic [NumChips-1:0] hyper_csn_o;
logic       hyper_ck_o;
logic       hyper_ckn_o;
logic       hyper_rwds_o;
logic       hyper_rwds_i;
logic       hyper_rwds_oe_o;
logic [7:0] hyper_dq_i;
logic [7:0] hyper_dq_o;
logic       hyper_dq_oe_o;
logic       hyper_reset_n_o;



uart_apb_top uart_apb_top (.*);
always_comb PREADY = 1;
always_comb PRDATA = '0;



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

/*    for (genvar j = 0; j<NumChips; j++) begin
       pad_functional_pd padinst_hyper_csno   (.OEN( 1'b0            ), .I( hyper_csn_o[j] ), .O(                  ), .PAD( pad_hyper_csn[j] ), .PEN( 1'b0 ));
    end
    pad_functional_pd padinst_hyper_ck     (.OEN( 1'b0            ), .I( hyper_ck_o      ), .O(                  ), .PAD( pad_hyper_ck     ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_ckn    (.OEN( 1'b0            ), .I( hyper_ckn_o    ), .O(                  ), .PAD( pad_hyper_ckn    ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_rwds   (.OEN(~hyper_rwds_oe_o), .I( hyper_rwds_o       ), .O( hyper_rwds_i  ), .PAD( pad_hyper_rwds   ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_resetn (.OEN( 1'b0            ), .I( hyper_reset_n_o ), .O(                  ), .PAD( pad_hyper_reset  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dq0  (.OEN(~hyper_dq_oe_o  ), .I( hyper_dq_o[0]      ), .O( hyper_dq_i[0] ), .PAD( pad_hyper_dq[0]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dq1  (.OEN(~hyper_dq_oe_o  ), .I( hyper_dq_o[1]      ), .O( hyper_dq_i[1] ), .PAD( pad_hyper_dq[1]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dq2  (.OEN(~hyper_dq_oe_o  ), .I( hyper_dq_o[2]      ), .O( hyper_dq_i[2] ), .PAD( pad_hyper_dq[2]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dq3  (.OEN(~hyper_dq_oe_o  ), .I( hyper_dq_o[3]      ), .O( hyper_dq_i[3] ), .PAD( pad_hyper_dq[3]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dq4  (.OEN(~hyper_dq_oe_o  ), .I( hyper_dq_o[4]      ), .O( hyper_dq_i[4] ), .PAD( pad_hyper_dq[4]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dq5  (.OEN(~hyper_dq_oe_o  ), .I( hyper_dq_o[5]      ), .O( hyper_dq_i[5] ), .PAD( pad_hyper_dq[5]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dq6  (.OEN(~hyper_dq_oe_o  ), .I( hyper_dq_o[6]      ), .O( hyper_dq_i[6] ), .PAD( pad_hyper_dq[6]  ), .PEN( 1'b0 ) );
    pad_functional_pd padinst_hyper_dq7  (.OEN(~hyper_dq_oe_o  ), .I( hyper_dq_o[7]      ), .O( hyper_dq_i[7] ), .PAD( pad_hyper_dq[7]  ), .PEN( 1'b0 ) );


IOBUF #(
    .DRIVE        (12), 
    .IBUF_LOW_PWR ("TRUE"), // Low Power:"TRUE", High Performance:"FALSE"
    .IOSTANDARD   ("DEFAULT"),
    .SLEW         ("SLOW") 
) u_i2c_iobuf[1:0] (
    .IO ({ i2c_sda,               i2c_scl               }), //io pad
    .O  ({ mccoy_sigchip_sda_in,  mccoy_sigchip_scl_in  }), //o
    .I  ({ 1'b0,                  1'b0                  }), //i
    .T  ({ mccoy_sigchip_sda_out, mccoy_sigchip_scl_out })  //i: 3-state enable: 1=input, 0=output
);

IBUF u_ibuf_I2c_int(.I(sigchip_mccoy_int), .O(sigchip_mccoy_int_ibuf));

*/
endmodule
