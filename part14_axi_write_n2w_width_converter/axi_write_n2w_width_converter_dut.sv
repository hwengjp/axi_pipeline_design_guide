// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.

module axi_write_n2w_width_converter_dut #(
    // ライト側パラメータ
    parameter int unsigned WRITE_SOURCE_WIDTH = 64,        // ライト上流側バス幅（ビット）
    parameter int unsigned WRITE_TARGET_WIDTH = 128,       // ライト下流側バス幅（ビット）
    
    // リード側パラメータ（変換なし、同じ幅）
    parameter int unsigned READ_SOURCE_WIDTH = 64,         // リード上流側バス幅（ビット）
    parameter int unsigned READ_TARGET_WIDTH = 64,         // リード下流側バス幅（ビット）
    
    parameter int unsigned ADDR_WIDTH = 32,                // アドレスバス幅（ビット）
    parameter int unsigned MEMORY_SIZE_BYTES = 4096        // メモリサイズ（バイト）
)(
    // クロック・リセット
    input  logic aclk,
    input  logic aresetn,
    
    // スレーブ側AXI4インターフェース
    // ライトアドレスチャネル
    input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic [2:0]              s_axi_awsize,
    input  logic [7:0]              s_axi_awlen,
    input  logic [1:0]              s_axi_awburst,
    input  logic [7:0]              s_axi_awid,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,
    
    // ライトデータチャネル
    input  logic [WRITE_SOURCE_WIDTH-1:0] s_axi_wdata,
    input  logic [WRITE_SOURCE_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,
    input  logic                    s_axi_wlast,
    
    // ライト応答チャネル
    output logic [7:0]              s_axi_bid,
    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,
    
    // リードアドレスチャネル
    input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic [2:0]              s_axi_arsize,
    input  logic [7:0]              s_axi_arlen,
    input  logic [1:0]              s_axi_arburst,
    input  logic [7:0]              s_axi_arid,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,
    
    // リードデータチャネル
    output logic [READ_SOURCE_WIDTH-1:0] s_axi_rdata,
    output logic [7:0]              s_axi_rid,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,
    output logic                    s_axi_rlast
);

    // 内部信号（バス幅変換器とメモリ間）
    logic [ADDR_WIDTH-1:0]   m_axi_awaddr;
    logic [2:0]              m_axi_awsize;
    logic [7:0]              m_axi_awlen;
    logic [1:0]              m_axi_awburst;
    logic [7:0]              m_axi_awid;
    logic                    m_axi_awvalid;
    logic                    m_axi_awready;
    
    logic [WRITE_TARGET_WIDTH-1:0] m_axi_wdata;
    logic [WRITE_TARGET_WIDTH/8-1:0] m_axi_wstrb;
    logic                    m_axi_wvalid;
    logic                    m_axi_wready;
    logic                    m_axi_wlast;
    
    logic [7:0]              m_axi_bid;
    logic [1:0]              m_axi_bresp;
    logic                    m_axi_bvalid;
    logic                    m_axi_bready;
    
    logic [ADDR_WIDTH-1:0]   m_axi_araddr;
    logic [2:0]              m_axi_arsize;
    logic [7:0]              m_axi_arlen;
    logic [1:0]              m_axi_arburst;
    logic [7:0]              m_axi_arid;
    logic                    m_axi_arvalid;
    logic                    m_axi_arready;
    
    logic [READ_TARGET_WIDTH-1:0] m_axi_rdata;
    logic [7:0]              m_axi_rid;
    logic [1:0]              m_axi_rresp;
    logic                    m_axi_rvalid;
    logic                    m_axi_rready;
    logic                    m_axi_rlast;

    // バス幅変換器インスタンス
    axi_write_n2w_width_converter #(
        .WRITE_SOURCE_WIDTH(WRITE_SOURCE_WIDTH),  // 32 bits from axi_common_defs.svh
        .WRITE_TARGET_WIDTH(WRITE_TARGET_WIDTH),  // 64 bits from axi_common_defs.svh
        .READ_SOURCE_WIDTH(READ_SOURCE_WIDTH),    // 32 bits from axi_common_defs.svh
        .READ_TARGET_WIDTH(READ_TARGET_WIDTH),    // 32 bits from axi_common_defs.svh
        .ADDR_WIDTH(ADDR_WIDTH)
    ) width_converter_inst (
        .aclk(aclk),
        .aresetn(aresetn),
        
        // スレーブ側インターフェース
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awsize(s_axi_awsize),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awid(s_axi_awid),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_wlast(s_axi_wlast),
        
        .s_axi_bid(s_axi_bid),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arsize(s_axi_arsize),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_arid(s_axi_arid),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .s_axi_rlast(s_axi_rlast),
        
        // マスター側インターフェース
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awid(m_axi_awid),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_wlast(m_axi_wlast),
        
        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arid(m_axi_arid),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rid(m_axi_rid),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .m_axi_rlast(m_axi_rlast)
    );

    // メモリインスタンス
    axi_dual_width_dual_port_ram #(
        .MEMORY_SIZE_BYTES(MEMORY_SIZE_BYTES),
        .READ_DATA_WIDTH(READ_TARGET_WIDTH),
        .WRITE_DATA_WIDTH(WRITE_TARGET_WIDTH),
        .AXI_ID_WIDTH(8),
        .AXI_ADDR_WIDTH(ADDR_WIDTH)
    ) memory_inst (
        .axi_clk(aclk),
        .axi_resetn(aresetn),
        
        // ライトアドレスチャネル
        .axi_aw_addr(m_axi_awaddr),
        .axi_aw_burst(m_axi_awburst),
        .axi_aw_size(m_axi_awsize),
        .axi_aw_id(m_axi_awid),
        .axi_aw_len(m_axi_awlen),
        .axi_aw_ready(m_axi_awready),
        .axi_aw_valid(m_axi_awvalid),
        
        // ライトデータチャネル
        .axi_w_data(m_axi_wdata),
        .axi_w_last(m_axi_wlast),
        .axi_w_strb(m_axi_wstrb),
        .axi_w_ready(m_axi_wready),
        .axi_w_valid(m_axi_wvalid),
        
        // ライト応答チャネル
        .axi_b_id(m_axi_bid),
        .axi_b_resp(m_axi_bresp),
        .axi_b_ready(m_axi_bready),
        .axi_b_valid(m_axi_bvalid),
        
        // リードアドレスチャネル
        .axi_ar_addr(m_axi_araddr),
        .axi_ar_burst(m_axi_arburst),
        .axi_ar_size(m_axi_arsize),
        .axi_ar_id(m_axi_arid),
        .axi_ar_len(m_axi_arlen),
        .axi_ar_ready(m_axi_arready),
        .axi_ar_valid(m_axi_arvalid),
        
        // リードデータチャネル
        .axi_r_data(m_axi_rdata),
        .axi_r_id(m_axi_rid),
        .axi_r_resp(m_axi_rresp),
        .axi_r_last(m_axi_rlast),
        .axi_r_ready(m_axi_rready),
        .axi_r_valid(m_axi_rvalid)
    );

endmodule
