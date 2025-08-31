//=============================================================================
// AXI4 Bus Width Converter DUT - PART14
//=============================================================================
// This module combines the bus width converter and RAM module to create
// a complete DUT (Device Under Test) for testing.
// 
// Architecture:
// - 32bit AXI4 source interface
// - Bus width converter (32bit -> 64bit)
// - 64bit AXI4 RAM interface
// - Memory size: axi_common_defs.svh parameters
//=============================================================================

`include "axi_common_defs.svh"

module axi_narrow_to_wide_dut #(
    parameter int unsigned SOURCE_WIDTH = AXI_DATA_WIDTH,    // Source bus width from axi_common_defs.svh
    parameter int unsigned TARGET_WIDTH = AXI_TARGET_WIDTH,  // Target bus width from axi_common_defs.svh
    parameter int unsigned MEMORY_SIZE_BYTES = MEMORY_SIZE_BYTES,  // Memory size from axi_common_defs.svh
    parameter int unsigned ADDR_WIDTH = $clog2(MEMORY_SIZE_BYTES),     // RAM address width auto-calculated
    parameter int unsigned RAM_DEPTH = MEMORY_SIZE_BYTES / (AXI_TARGET_WIDTH / 8)  // RAM depth calculated from memory size
) (
    input  logic                    aclk,
    input  logic                    aresetn,
    
    // 32bit AXI4 Source Interface (Master)
    input  logic [ADDR_WIDTH-1:0]             s_axi_awaddr,
    input  logic [2:0]              s_axi_awsize,
    input  logic [7:0]              s_axi_awlen,
    input  logic [1:0]              s_axi_awburst,
    input  logic [7:0]              s_axi_awid,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,
    
    input  logic [SOURCE_WIDTH-1:0] s_axi_wdata,
    input  logic [SOURCE_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,
    input  logic                    s_axi_wlast,
    
    output logic [7:0]              s_axi_bid,
    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,
    
    input  logic [ADDR_WIDTH-1:0]             s_axi_araddr,
    input  logic [2:0]              s_axi_arsize,
    input  logic [7:0]              s_axi_arlen,
    input  logic [1:0]              s_axi_arburst,
    input  logic [7:0]              s_axi_arid,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,
    
    output logic [SOURCE_WIDTH-1:0] s_axi_rdata,
    output logic [7:0]              s_axi_rid,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,
    output logic                    s_axi_rlast
);

// Internal AXI4 signals between converter and RAM
logic [ADDR_WIDTH-1:0] m_axi_awaddr;
logic [2:0]  m_axi_awsize;
logic [7:0]  m_axi_awlen;
logic [1:0]  m_axi_awburst;
logic [7:0]  m_axi_awid;
logic        m_axi_awvalid;
logic        m_axi_awready;
logic [TARGET_WIDTH-1:0] m_axi_wdata;
logic [TARGET_WIDTH/8-1:0] m_axi_wstrb;
logic        m_axi_wvalid;
logic        m_axi_wready;
logic        m_axi_wlast;
logic [7:0]  m_axi_bid;
logic [1:0]  m_axi_bresp;
logic        m_axi_bvalid;
logic        m_axi_bready;
logic [ADDR_WIDTH-1:0] m_axi_araddr;
logic [2:0]  m_axi_arsize;
logic [7:0]  m_axi_arlen;
logic [1:0]  m_axi_arburst;
logic [7:0]  m_axi_arid;
logic        m_axi_arvalid;
logic        m_axi_arready;
logic [TARGET_WIDTH-1:0] m_axi_rdata;
logic [7:0]  m_axi_rid;
logic [1:0]  m_axi_rresp;
logic        m_axi_rvalid;
logic        m_axi_rready;
logic        m_axi_rlast;

// Bus width converter instance (32bit -> 64bit)
axi_narrow_to_wide #(
    .SOURCE_WIDTH(SOURCE_WIDTH),    // 32bit source
    .TARGET_WIDTH(TARGET_WIDTH),    // 64bit target
    .ADDR_WIDTH(ADDR_WIDTH)        // Address width from DUT parameter
) bus_width_converter (
    .aclk(aclk),
    .aresetn(aresetn),
    
    // Upstream interface (32bit source)
    .u_axi_awaddr(s_axi_awaddr),
    .u_axi_awsize(s_axi_awsize),
    .u_axi_awlen(s_axi_awlen),
    .u_axi_awburst(s_axi_awburst),
    .u_axi_awid(s_axi_awid),
    .u_axi_awvalid(s_axi_awvalid),
    .u_axi_awready(s_axi_awready),
    .u_axi_wdata(s_axi_wdata),
    .u_axi_wstrb(s_axi_wstrb),
    .u_axi_wvalid(s_axi_wvalid),
    .u_axi_wready(s_axi_wready),
    .u_axi_wlast(s_axi_wlast),
    .u_axi_bid(s_axi_bid),
    .u_axi_bresp(s_axi_bresp),
    .u_axi_bvalid(s_axi_bvalid),
    .u_axi_bready(s_axi_bready),
    .u_axi_araddr(s_axi_araddr),
    .u_axi_arsize(s_axi_arsize),
    .u_axi_arlen(s_axi_arlen),
    .u_axi_arburst(s_axi_arburst),
    .u_axi_arid(s_axi_arid),
    .u_axi_arvalid(s_axi_arvalid),
    .u_axi_arready(s_axi_arready),
    .u_axi_rdata(s_axi_rdata),
    .u_axi_rid(s_axi_rid),
    .u_axi_rresp(s_axi_rresp),
    .u_axi_rvalid(s_axi_rvalid),
    .u_axi_rready(s_axi_rready),
    .u_axi_rlast(s_axi_rlast),
    
    // Downstream interface (64bit to RAM)
    .d_axi_awaddr(m_axi_awaddr),
    .d_axi_awsize(m_axi_awsize),
    .d_axi_awlen(m_axi_awlen),
    .d_axi_awburst(m_axi_awburst),
    .d_axi_awid(m_axi_awid),
    .d_axi_awvalid(m_axi_awvalid),
    .d_axi_awready(m_axi_awready),
    .d_axi_wdata(m_axi_wdata),
    .d_axi_wstrb(m_axi_wstrb),
    .d_axi_wvalid(m_axi_wvalid),
    .d_axi_wready(m_axi_wready),
    .d_axi_wlast(m_axi_wlast),
    .d_axi_bid(m_axi_bid),
    .d_axi_bresp(m_axi_bresp),
    .d_axi_bvalid(m_axi_bvalid),
    .d_axi_bready(m_axi_bready),
    .d_axi_araddr(m_axi_araddr),
    .d_axi_arsize(m_axi_arsize),
    .d_axi_arlen(m_axi_arlen),
    .d_axi_arburst(m_axi_arburst),
    .d_axi_arid(m_axi_arid),
    .d_axi_arvalid(m_axi_arvalid),
    .d_axi_arready(m_axi_arready),
    .d_axi_rdata(m_axi_rdata),
    .d_axi_rid(m_axi_rid),
    .d_axi_rresp(m_axi_rresp),
    .d_axi_rvalid(m_axi_rvalid),
    .d_axi_rready(m_axi_rready),
    .d_axi_rlast(m_axi_rlast)
);

// RAM instance (64bit interface)
axi_simple_single_port_ram #(
    .MEMORY_SIZE_BYTES(MEMORY_SIZE_BYTES),
    .AXI_DATA_WIDTH(TARGET_WIDTH),
    .AXI_ADDR_WIDTH(ADDR_WIDTH)
) ram_instance (
    .axi_clk(aclk),
    .axi_resetn(aresetn),
    
    .axi_aw_addr(m_axi_awaddr),
    .axi_aw_size(m_axi_awsize),
    .axi_aw_len(m_axi_awlen),
    .axi_aw_burst(m_axi_awburst),
    .axi_aw_id(m_axi_awid),
    .axi_aw_valid(m_axi_awvalid),
    .axi_aw_ready(m_axi_awready),
    .axi_w_data(m_axi_wdata),
    .axi_w_last(m_axi_wlast),
    .axi_w_strb(m_axi_wstrb),
    .axi_w_valid(m_axi_wvalid),
    .axi_w_ready(m_axi_wready),
    .axi_b_id(m_axi_bid),
    .axi_b_resp(m_axi_bresp),
    .axi_b_valid(m_axi_bvalid),
    .axi_b_ready(m_axi_bready),
    .axi_ar_addr(m_axi_araddr),
    .axi_ar_size(m_axi_arsize),
    .axi_ar_len(m_axi_arlen),
    .axi_ar_burst(m_axi_arburst),
    .axi_ar_id(m_axi_arid),
    .axi_ar_valid(m_axi_arvalid),
    .axi_ar_ready(m_axi_arready),
    .axi_r_data(m_axi_rdata),
    .axi_r_id(m_axi_rid),
    .axi_r_resp(m_axi_rresp),
    .axi_r_last(m_axi_rlast),
    .axi_r_valid(m_axi_rvalid),
    .axi_r_ready(m_axi_rready)
);

endmodule
