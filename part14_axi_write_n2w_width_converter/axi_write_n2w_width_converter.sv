// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.

module axi_write_n2w_width_converter #(
    // ライト側パラメータ
    parameter int unsigned WRITE_SOURCE_WIDTH = 64,        // ライト上流側バス幅（ビット）
    parameter int unsigned WRITE_TARGET_WIDTH = 128,       // ライト下流側バス幅（ビット）
    
    // リード側パラメータ（変換なし、同じ幅）
    parameter int unsigned READ_SOURCE_WIDTH = 64,         // リード上流側バス幅（ビット）
    parameter int unsigned READ_TARGET_WIDTH = 64,         // リード下流側バス幅（ビット）
    
    parameter int unsigned ADDR_WIDTH = 32,                // アドレスバス幅（ビット）
    
    // 派生パラメータ（自動計算）
    parameter int unsigned WRITE_SOURCE_BYTES = WRITE_SOURCE_WIDTH / 8,        // ライト上流側バイト数
    parameter int unsigned WRITE_TARGET_BYTES = WRITE_TARGET_WIDTH / 8,        // ライト下流側バイト数
    parameter int unsigned READ_SOURCE_BYTES = READ_SOURCE_WIDTH / 8,          // リード上流側バイト数
    parameter int unsigned READ_TARGET_BYTES = READ_TARGET_WIDTH / 8,          // リード下流側バイト数
    parameter int unsigned WRITE_SOURCE_ADDR_BITS = $clog2(WRITE_SOURCE_BYTES), // ライト上流側アドレスビット数
    parameter int unsigned WRITE_TARGET_ADDR_BITS = $clog2(WRITE_TARGET_BYTES), // ライト下流側アドレスビット数
    parameter int unsigned READ_SOURCE_ADDR_BITS = $clog2(READ_SOURCE_BYTES),   // リード上流側アドレスビット数
    parameter int unsigned READ_TARGET_ADDR_BITS = $clog2(READ_TARGET_BYTES)    // リード下流側アドレスビット数
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
    input  logic [WRITE_SOURCE_BYTES-1:0] s_axi_wstrb,
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
    output logic                    s_axi_rlast,
    
    // マスター側AXI4インターフェース
    // ライトアドレスチャネル
    output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
    output logic [2:0]              m_axi_awsize,
    output logic [7:0]              m_axi_awlen,
    output logic [1:0]              m_axi_awburst,
    output logic [7:0]              m_axi_awid,
    output logic                    m_axi_awvalid,
    input  logic                    m_axi_awready,
    
    // ライトデータチャネル
    output logic [WRITE_TARGET_WIDTH-1:0] m_axi_wdata,
    output logic [WRITE_TARGET_BYTES-1:0] m_axi_wstrb,
    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,
    output logic                    m_axi_wlast,
    
    // ライト応答チャネル
    input  logic [7:0]              m_axi_bid,
    input  logic [1:0]              m_axi_bresp,
    input  logic                    m_axi_bvalid,
    output logic                    m_axi_bready,
    
    // リードアドレスチャネル
    output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic [2:0]              m_axi_arsize,
    output logic [7:0]              m_axi_arlen,
    output logic [1:0]              m_axi_arburst,
    output logic [7:0]              m_axi_arid,
    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,
    
    // リードデータチャネル
    input  logic [READ_TARGET_WIDTH-1:0] m_axi_rdata,
    input  logic [7:0]              m_axi_rid,
    input  logic [1:0]              m_axi_rresp,
    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready,
    input  logic                    m_axi_rlast
);

    // ライト側パイプライン内部信号
    // T0Aステージ（アドレス）
    reg [ADDR_WIDTH-1:0]   w_t0a_addr;        // T0Aステージアドレスレジスタ
    reg [1:0]              w_t0a_burst;       // T0Aステージバーストタイプ
    reg [2:0]              w_t0a_size;        // T0AステージSIZE信号
    reg [7:0]              w_t0a_id;          // T0AステージID
    reg                    w_t0a_burst_valid; // T0Aステージバースト有効
    reg                    w_t0a_valid;       // T0Aステージ有効（レディ状態）
    reg [7:0]              w_t0a_count;       // T0Aステージバーストカウンタ
    reg                    w_t0a_idle;        // T0Aステージアイドルフラグ
    wire                   w_t0a_last;        // T0Aステージ最終信号
    wire                   w_t0a_state_ready; // T0Aステージレディ状態
    reg [ADDR_WIDTH-1:0]   w_t0a_start_addr;  // 開始アドレス保存
    reg [7:0]              w_t0a_len;         // LEN値保存

    // T0Dステージ（データ）
    reg [WRITE_SOURCE_WIDTH-1:0] w_t0d_data;        // T0Dステージデータ
    reg [WRITE_SOURCE_BYTES-1:0] w_t0d_strb;        // T0Dステージストローブ
    reg                    w_t0d_valid;       // T0Dステージ有効
    reg                    w_t0d_last;        // T0Dステージ最終

    // T1Aステージ（アドレス）
    reg [ADDR_WIDTH-1:0]   w_t1a_addr;        // T1Aステージアドレスレジスタ
    reg [1:0]              w_t1a_burst;       // T1Aステージバーストタイプ
    reg [2:0]              w_t1a_size;        // T1AステージSIZE信号
    reg [7:0]              w_t1a_id;          // T1AステージID
    reg                    w_t1a_valid;       // T1Aステージ有効
    reg [7:0]              w_t1a_count;       // T1Aステージバーストカウンタ
    reg                    w_t1a_idle;        // T1Aステージアイドルフラグ
    wire                   w_t1a_last;        // T1Aステージ最終信号
    wire                   w_t1a_state_ready; // T1Aステージレディ状態
    reg [ADDR_WIDTH-1:0]   w_t1a_start_addr;  // 開始アドレス保存
    reg [7:0]              w_t1a_len;         // LEN値保存

    // T1Dステージ（データ変換）
    reg [WRITE_TARGET_WIDTH-1:0] w_t1d_data;        // T1Dステージデータ
    reg [WRITE_TARGET_BYTES-1:0] w_t1d_strb;        // T1Dステージストローブ
    reg                    w_t1d_valid;       // T1Dステージ有効
    reg                    w_t1d_last;        // T1Dステージ最終

    // T2ステージ（応答）
    // T2ステージ（ライト応答）は削除 - 直結のため不要

    // ライトパイプライン制御信号
    wire w_t0a_m_ready;      // T0Aマージレディ信号
    wire w_t0d_m_ready;      // T0Dマージレディ信号

    // リード側は直結（変換なし）
    assign s_axi_arready = m_axi_arready;
    assign m_axi_araddr = s_axi_araddr;
    assign m_axi_arsize = s_axi_arsize;
    assign m_axi_arlen = s_axi_arlen;
    assign m_axi_arburst = s_axi_arburst;
    assign m_axi_arid = s_axi_arid;
    assign m_axi_arvalid = s_axi_arvalid;
    
    assign s_axi_rdata = m_axi_rdata;
    assign s_axi_rid = m_axi_rid;
    assign s_axi_rresp = m_axi_rresp;
    assign s_axi_rvalid = m_axi_rvalid;
    assign m_axi_rready = s_axi_rready;
    assign s_axi_rlast = m_axi_rlast;

    // ライトパイプラインT0Aステージ - アドレスカウンタとバースト制御
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            // 全レジスタをリセット
            w_t0a_addr <= '0;
            w_t0a_burst <= '0;
            w_t0a_size <= '0;
            w_t0a_id <= '0;
            w_t0a_burst_valid <= 1'b0;
            w_t0a_valid <= 1'b0;
            w_t0a_count <= '0;
            w_t0a_idle <= 1'b1;
            w_t0a_start_addr <= '0;
            w_t0a_len <= '0;
        end else if (m_axi_awready) begin
            if (w_t0a_m_ready) begin
                case (w_t0a_state_ready)
                    1'b1: begin // レディ状態（アイドルまたは最終サイクル）
                        if (s_axi_awvalid) begin
                            // 新しいアドレストランザクションをラッチ
                            w_t0a_start_addr <= s_axi_awaddr;
                            w_t0a_addr <= s_axi_awaddr;
                            w_t0a_burst <= s_axi_awburst;
                            w_t0a_size <= s_axi_awsize;
                            w_t0a_id <= s_axi_awid;
                            w_t0a_burst_valid <= 1'b1;
                            w_t0a_valid <= 1'b1;  // 新しいアドレストランザクションをラッチ
                            w_t0a_count <= s_axi_awlen;
                            w_t0a_idle <= 1'b0;
                            w_t0a_len <= s_axi_awlen;
                        end else begin
                            // 有効信号をクリアしてアイドルに設定
                            w_t0a_burst_valid <= 1'b0;
                            w_t0a_valid <= 1'b0;  // アドレス無効
                            w_t0a_count <= '0;
                            w_t0a_idle <= 1'b1;
                        end
                    end
                    1'b0: begin // レディでない状態（バースト中）
                        w_t0a_valid <= 1'b0;  // バースト中はアドレス無効
                        w_t0a_count <= w_t0a_count - 1;
                        case (w_t0a_burst)
                            2'b00: begin // FIXEDバースト
                                w_t0a_addr <= w_t0a_start_addr;  // アドレスは固定
                            end
                            2'b01: begin // INCRバースト
                                w_t0a_addr <= w_t0a_addr + size_to_bytes(w_t0a_size);
                            end
                            2'b10: begin // WRAPバースト
                                w_t0a_addr <= calculate_wrap_address_bit_mask(w_t0a_start_addr, w_t0a_len, w_t0a_count, w_t0a_size);
                            end
                            default: begin // デフォルトはINCR動作
                                w_t0a_addr <= w_t0a_start_addr + size_to_bytes(w_t0a_size);
                            end
                        endcase
                    end
                endcase
            end
        end
    end

    // ライトパイプラインT0Dステージ - データパイプライン
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_t0d_data <= '0;
            w_t0d_strb <= '0;
            w_t0d_valid <= 1'b0;
            w_t0d_last <= 1'b0;
        end else if (m_axi_wready) begin
            if (w_t0d_m_ready) begin
                w_t0d_data <= s_axi_wdata;
                w_t0d_strb <= s_axi_wstrb;
                w_t0d_valid <= s_axi_wvalid;
                w_t0d_last <= s_axi_wlast;
            end
        end
    end

    // ライトパイプラインT1Aステージ - アドレスパイプライン（そのまま接続）
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_t1a_addr <= '0;
            w_t1a_burst <= '0;
            w_t1a_size <= '0;
            w_t1a_id <= '0;
            w_t1a_valid <= 1'b0;
            w_t1a_count <= '0;
            w_t1a_idle <= 1'b1;
            w_t1a_start_addr <= '0;
            w_t1a_len <= '0;
        end else if (m_axi_awready) begin
            w_t1a_addr <= w_t0a_addr;
            w_t1a_burst <= w_t0a_burst;
            w_t1a_size <= w_t0a_size;
            w_t1a_id <= w_t0a_id;
            w_t1a_valid <= w_t0a_valid;
            w_t1a_count <= w_t0a_count;
            w_t1a_idle <= w_t0a_idle;
            w_t1a_start_addr <= w_t0a_start_addr;
            w_t1a_len <= w_t0a_len;
        end
    end

    // ライトパイプラインT1Dステージ - データ変換
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_t1d_data <= '0;
            w_t1d_strb <= '0;
            w_t1d_valid <= 1'b0;
            w_t1d_last <= 1'b0;
        end else if (m_axi_wready) begin
            // 2.3章の計算式に基づくシフト量計算
            logic [7:0] data_shift_amount;
            logic [7:0] strb_shift_amount;
            
            data_shift_amount = calculate_data_shift_amount(w_t1a_addr);
            strb_shift_amount = calculate_strb_shift_amount(w_t1a_addr);
            
            w_t1d_data <= w_t0d_data << data_shift_amount;
            w_t1d_strb <= w_t0d_strb << strb_shift_amount;
            w_t1d_valid <= w_t0d_valid;
            w_t1d_last <= w_t0d_last;
        end
    end

    // ライトパイプラインT2ステージ - 応答生成
    // T2ステージ処理は削除 - ライト応答信号が直結のため不要

    // ライト制御信号生成
    assign w_t0a_last = !w_t0a_idle && (w_t0a_count == 0);
    assign w_t0a_state_ready = w_t0a_idle || (!w_t0a_idle && (w_t0a_count == 0));
    assign w_t1a_last = !w_t1a_idle && (w_t1a_count == 0);
    assign w_t1a_state_ready = w_t1a_idle || (!w_t1a_idle && (w_t1a_count == 0));

    // ライトマージレディ生成
    assign w_t0a_m_ready = (w_t0d_valid && !w_t0a_burst_valid) || (!w_t0d_valid && !w_t0a_burst_valid) || (w_t0d_valid && w_t0a_burst_valid);
    assign w_t0d_m_ready = (!w_t0d_valid && w_t0a_burst_valid) || (!w_t0d_valid && !w_t0a_burst_valid) || (w_t0d_valid && w_t0a_burst_valid);

    // ユーティリティ関数：SIZEをバイト数に変換
    function automatic int size_to_bytes(input logic [2:0] size);
        return (1 << size);
    endfunction

    // 2.3章の計算式に基づく汎用データシフト量計算
    function automatic logic [7:0] calculate_data_shift_amount(input logic [ADDR_WIDTH-1:0] addr);
        // パラメータ化された計算
        localparam int SOURCE_BYTES = WRITE_SOURCE_WIDTH / 8;
        localparam int TARGET_BYTES = WRITE_TARGET_WIDTH / 8;
        localparam int RATIO = TARGET_BYTES / SOURCE_BYTES;
        localparam int ADDR_BITS_NEEDED = $clog2(RATIO);
        localparam int SOURCE_ADDR_BITS = $clog2(SOURCE_BYTES);
        localparam int SHIFT_MULTIPLIER = SOURCE_BYTES;
        
        // 汎用的な計算式: (アドレス[下位ビット範囲]) * 8 * ソース幅の倍数
        // 下位ビット範囲: [ADDR_BITS_NEEDED + SOURCE_ADDR_BITS - 1 : SOURCE_ADDR_BITS]
        logic [7:0] addr_extract;
        
        // アドレスの下位ビットを抽出（最大7ビットまで対応）
        if (ADDR_BITS_NEEDED + SOURCE_ADDR_BITS <= 7) begin
            addr_extract = addr[ADDR_BITS_NEEDED + SOURCE_ADDR_BITS - 1 : SOURCE_ADDR_BITS];
        end else begin
            // 7ビットを超える場合はエラーを表示して終了
            $error("Data shift calculation: Address bit range exceeds 7 bits: ADDR_BITS_NEEDED=%0d + SOURCE_ADDR_BITS=%0d = %0d > 7. Maximum supported address bit range is 7 bits.", 
                   ADDR_BITS_NEEDED, SOURCE_ADDR_BITS, ADDR_BITS_NEEDED + SOURCE_ADDR_BITS);
            $finish;
        end
        
        return (addr_extract * 8 * SHIFT_MULTIPLIER);
    endfunction

    // 2.3章の計算式に基づく汎用ストローブシフト量計算
    function automatic logic [7:0] calculate_strb_shift_amount(input logic [ADDR_WIDTH-1:0] addr);
        // パラメータ化された計算
        localparam int SOURCE_BYTES = WRITE_SOURCE_WIDTH / 8;
        localparam int TARGET_BYTES = WRITE_TARGET_WIDTH / 8;
        localparam int RATIO = TARGET_BYTES / SOURCE_BYTES;
        localparam int ADDR_BITS_NEEDED = $clog2(RATIO);
        localparam int SOURCE_ADDR_BITS = $clog2(SOURCE_BYTES);
        localparam int SHIFT_MULTIPLIER = SOURCE_BYTES;
        
        // 汎用的な計算式: (アドレス[下位ビット範囲]) * ソース幅の倍数
        // 下位ビット範囲: [ADDR_BITS_NEEDED + SOURCE_ADDR_BITS - 1 : SOURCE_ADDR_BITS]
        logic [7:0] addr_extract;
        
        // アドレスの下位ビットを抽出（最大7ビットまで対応）
        if (ADDR_BITS_NEEDED + SOURCE_ADDR_BITS <= 7) begin
            addr_extract = addr[ADDR_BITS_NEEDED + SOURCE_ADDR_BITS - 1 : SOURCE_ADDR_BITS];
        end else begin
            // 7ビットを超える場合はエラーを表示して終了
            $error("Strobe shift calculation: Address bit range exceeds 7 bits: ADDR_BITS_NEEDED=%0d + SOURCE_ADDR_BITS=%0d = %0d > 7. Maximum supported address bit range is 7 bits.", 
                   ADDR_BITS_NEEDED, SOURCE_ADDR_BITS, ADDR_BITS_NEEDED + SOURCE_ADDR_BITS);
            $finish;
        end
        
        return (addr_extract * SHIFT_MULTIPLIER);
    endfunction

    // 関数：WRAPアドレス計算用ビットマスク作成（合成フレンドリー）
    function automatic logic [ADDR_WIDTH-1:0] create_wrap_bit_mask(
        input logic [2:0] size,
        input logic [7:0] len
    );
        int changing_bits;
        logic [ADDR_WIDTH-1:0] bit_mask;
        
        // 変更ビット計算：SIZE + log2(LEN + 1)
        // WRAPバーストLENは2, 4, 8, 16（1, 3, 7, 15）に制限
        // log2(LEN + 1)値：log2(2)=1, log2(4)=2, log2(8)=3, log2(16)=4
        case (len)
            8'd1:  changing_bits = size + 1;  // LEN=1（2転送）：log2(2)=1
            8'd3:  changing_bits = size + 2;  // LEN=3（4転送）：log2(4)=2
            8'd7:  changing_bits = size + 3;  // LEN=7（8転送）：log2(8)=3
            8'd15: changing_bits = size + 4;  // LEN=15（16転送）：log2(16)=4
            default: begin
                changing_bits = size + 1; // デフォルト値
            end
        endcase
        
        // ビットマスク作成：(1 << changing_bits) - 1
        bit_mask = (1 << changing_bits) - 1;
        
        return bit_mask;
    endfunction

    // 関数：ビットマスク法によるWRAPアドレス計算
    function automatic logic [ADDR_WIDTH-1:0] calculate_wrap_address_bit_mask(
        input logic [ADDR_WIDTH-1:0] start_addr,
        input logic [7:0] len,
        input logic [7:0] count,
        input logic [2:0] size
    );
        logic [ADDR_WIDTH-1:0] bit_mask;
        logic [ADDR_WIDTH-1:0] upper_bits;
        logic [ADDR_WIDTH-1:0] lower_bits;
        logic [ADDR_WIDTH-1:0] calculated_addr;
        logic [ADDR_WIDTH-1:0] wrapped_addr;
        
        // 変更ビット用ビットマスク作成
        bit_mask = create_wrap_bit_mask(size, len);
        
        // 上位ビット抽出（変更されない部分）
        upper_bits = start_addr & ~bit_mask;
        
        // 転送オフセットでアドレス計算
        calculated_addr = start_addr + ((len - count + 1'b1) * size_to_bytes(size));
        
        // 下位ビット抽出（変更部分）してマスク適用
        lower_bits = calculated_addr & bit_mask;
        
        // 上位と下位ビット結合
        wrapped_addr = upper_bits | lower_bits;
        
        return wrapped_addr;
    endfunction

    // ライトレディ信号生成
    assign s_axi_awready = w_t0a_state_ready && w_t0a_m_ready && m_axi_awready;
    assign s_axi_wready = w_t0d_m_ready && m_axi_wready;

    // ライト応答信号（直結）
    assign s_axi_bid = m_axi_bid;
    assign s_axi_bresp = m_axi_bresp;
    assign s_axi_bvalid = m_axi_bvalid;

    // マスター側ライト信号
    assign m_axi_awaddr = w_t1a_addr;
    assign m_axi_awsize = w_t1a_size;
    assign m_axi_awlen = w_t1a_len;  // バースト長は変更なし
    assign m_axi_awburst = w_t1a_burst;
    assign m_axi_awid = w_t1a_id;
    assign m_axi_awvalid = w_t1a_valid;
    assign m_axi_wdata = w_t1d_data;
    assign m_axi_wstrb = w_t1d_strb;
    assign m_axi_wvalid = w_t1d_valid;
    assign m_axi_wlast = w_t1d_last;
    assign m_axi_bready = s_axi_bready;

endmodule
