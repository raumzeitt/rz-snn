package my_bus_pkg;

    import axi_pkg::*;
    `include "axi/typedef.svh"
    `include "register_interface/typedef.svh"

    // ---- Topo ----
    parameter int unsigned NumChips = 2;
    parameter int unsigned NumPhys = 1;

    // ---- AXI ----
    parameter int AxiAddrWidth = 32; // from PULP tb
    parameter int AxiDataWidth = 64;
    parameter int AxiIdWidth   = 6;
    parameter int AxiUserWidth = 1;

    typedef logic [AxiAddrWidth-1:0] addr_t;
    typedef logic [AxiDataWidth-1:0] data_t;
    typedef logic [AxiDataWidth/8-1:0] strb_t;
    typedef logic [AxiIdWidth-1:0] id_t;
    typedef logic [AxiUserWidth-1:0] user_t;

    `AXI_TYPEDEF_ALL(axi, addr_t, id_t, data_t, strb_t, user_t)

    // ---- REG ----
    parameter int RegAw = 32; // from PULP tb
    parameter int RegDw = 32;

    typedef logic [RegAw-1:0] reg_addr_t;
    typedef logic [RegDw-1:0] reg_data_t;
    typedef logic [RegDw/8-1:0] reg_strb_t;

    `REG_BUS_TYPEDEF_REQ(reg_req_t, reg_addr_t, reg_data_t, reg_strb_t)
    `REG_BUS_TYPEDEF_RSP(reg_rsp_t, reg_data_t)

endpackage
