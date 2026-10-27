// Byte-addressed APB control for single-word 32-bit AXI reads and writes.
//
// Offset    Register   Description
// 0x0..0x3  ADDRESS    32-bit AXI byte address, little-endian
// 0x4..0x7  DATA       32-bit write data / read result, little-endian
// 0x8       COMMAND    Bits 1:0: 1=read, 2=write
//                      bits 7:4: active-low byte enables
// 0x9       STATUS     Bit 0: busy, bit 1: error; other bits read zero
//
// Set ADDRESS and write DATA as needed, then issue COMMAND.
// Poll busy until zero before reading error or the read result.
// Addresses must be 4-byte aligned. 
// Each COMMAND[7:4] bit disables its byte lane.
// COMMAND=0x02 writes all four bytes; COMMAND=0x01 reads a full word.
// 
// Writes while busy and unsupported commands are ignored.
// Unused offsets read zero and ignore writes. No APB slave-error output.
// AXI requests remain active until a response; there is no timeout.
module apb_axi_access #(
    parameter type axi_req_t = logic,
    parameter type axi_rsp_t = logic,
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [3:0]  PADDR,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [7:0]  PWDATA,
    output logic [7:0]  PRDATA,
    output logic        PREADY,
    output axi_req_t  axi_req_o, // AXI master request
    input  axi_rsp_t axi_rsp_i // AXI slave response
);

logic [31:0] address_q, data_q; // AXI byte address and shared write/read data
logic write_q, valid_q, error_q; // Operation, busy, last AXI error
logic [3:0] wstrb_q; // Byte enables held until AXI responds

reg_req_t request; // Regbus request to AXI bridge
reg_rsp_t response; // Regbus response from AXI bridge

assign PREADY = 1; // APB register accesses never wait for AXI
assign request = '{addr: address_q, write: write_q, wdata: data_q, wstrb: wstrb_q, valid: valid_q}; // Regbus valid corresponds to APB PSEL && PENABLE; held until response.ready
    
always_comb 
    casez (PADDR)
        4'b00??: PRDATA = address_q[8*PADDR[1:0] +: 8]; // Address bytes, least significant first
        4'b01??: PRDATA = data_q[8*PADDR[1:0] +: 8];// Data bytes, least significant first
        4'h9: PRDATA = {error_q, valid_q}; // Error/busy
        default: PRDATA = 0;
    endcase

always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)
        valid_q <= 0; // Only the request-active flag requires reset
    else if (valid_q && response.ready)
        valid_q <= 0; // Transaction completed
    else if (!valid_q && PSEL && PENABLE && PWRITE && PADDR == 8 && (PWDATA[1:0] == 1 || PWDATA[1:0] == 2))
        valid_q <= 1; // Hold request active until AXI responds

always_ff @(posedge clk) begin
    // Freeze address/data until the outstanding AXI access completes.
    if (PSEL && PENABLE && PWRITE && !valid_q) begin // Accept writes only when idle
        casez (PADDR)
            4'b00??: // Address bytes, least significant first
                address_q[8*PADDR[1:0] +: 8] <= PWDATA;
            4'b01??: // Data bytes, least significant first
                data_q[8*PADDR[1:0] +: 8] <= PWDATA;
            4'h8: if (PWDATA[1:0] == 1 || PWDATA[1:0] == 2) begin // Command: 1=read, 2=write
                write_q <= PWDATA[1:0] == 2; // Select write; otherwise read
                wstrb_q <= ~PWDATA[7:4]; // Zero enables a byte lane
            end
        endcase
    end
    if (valid_q && response.ready) begin // AXI read or write response received
        error_q <= response.error; // Non-OKAY AXI response
        if (!write_q) 
            data_q <= response.rdata; // Replace data register on read completion
    end

end

reg_to_axi #( // Handles independent AXI channel handshakes
    .DataWidth (32),
    .reg_req_t (reg_req_t),
    .reg_rsp_t (reg_rsp_t),
    .axi_req_t (axi_req_t),
    .axi_rsp_t (axi_rsp_t)
) i_reg_to_axi (
    .clk_i (clk),
    .rst_ni (rst_n),
    .reg_req_i (request), // from APB registers
    .reg_rsp_o (response), // to APB registers
    .axi_req_o (axi_req_o), // external
    .axi_rsp_i (axi_rsp_i) // external
);
endmodule
