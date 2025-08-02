// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

module burst_read_pipeline #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MAX_BURST_LENGTH = 4
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Upstream Interface (Input) - アドレスチャネル
    input  wire [ADDR_WIDTH-1:0]   u_addr,
    input  wire [7:0]              u_length,  // バースト長-1
    input  wire                     u_valid,
    output wire                     u_ready,
    
    // Memory Interface
    output wire [ADDR_WIDTH-1:0]   mem_addr,
    output wire                     mem_read_en,
    input  wire [DATA_WIDTH-1:0]   mem_data,
    input  wire                     mem_valid,
    
    // Downstream Interface (Output) - データチャネル
    output wire [DATA_WIDTH-1:0]   d_data,
    output wire                     d_valid,
    output wire                     d_last,
    input  wire                     d_ready
);

    // T0ステージ（アドレスカウンタとRE）の内部信号
    reg [7:0]                      t0_count;
    reg [ADDR_WIDTH-1:0]           t0_mem_addr;
    reg                             t0_mem_read_en;
    reg                             t0_valid;
    reg                             t0_last;
    reg                             t0_ready;
    reg [1:0]                      t0_state;  // 0:アイドル, 1:バースト中, 2:最終サイクル
    
    // T1ステージ（メモリアクセス）の内部信号
    reg [DATA_WIDTH-1:0]           t1_data;
    reg                             t1_valid;
    reg                             t1_last;
    reg                             t1_ready;
    
    // メモリインターフェースの割り当て
    assign mem_addr = t0_mem_addr;
    assign mem_read_en = t0_mem_read_en;
    
    // 下流インターフェースの割り当て
    assign d_data = t1_data;
    assign d_valid = t1_valid;
    assign d_last = t1_last;
    
    // T0ステージのu_ready生成（T0_Readyとd_readyの論理AND）
    assign u_ready = t0_ready && d_ready;
    
    // T0ステージの制御（アドレスカウンタとRE）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t0_count <= 8'hFF;
            t0_mem_addr <= {ADDR_WIDTH{1'b0}};
            t0_mem_read_en <= 1'b0;
            t0_valid <= 1'b0;
            t0_last <= 1'b0;
            t0_ready <= 1'b1;
            t0_state <= 2'b00;
        end else if (d_ready) begin
            case (t0_state)
                2'b00: begin // アイドル状態
                    if (u_valid && u_ready) begin
                        t0_count <= u_length;
                        t0_mem_addr <= u_addr;
                        t0_mem_read_en <= 1'b1;
                        t0_valid <= 1'b1;
                        t0_last <= (u_length == 8'h00);
                        t0_ready <= (u_length == 8'h00);
                        t0_state <= (u_length == 8'h00) ? 2'b00 : 2'b01;
                    end else begin
                        t0_mem_read_en <= 1'b0;
                        t0_valid <= 1'b0;
                        t0_last <= 1'b0;
                    end
                end
                
                2'b01: begin // バースト中
                    if (t0_count > 8'h00) begin
                        t0_count <= t0_count - 8'h01;
                        t0_mem_addr <= t0_mem_addr + 1;
                        t0_mem_read_en <= 1'b1;
                        t0_valid <= 1'b1;
                        t0_last <= (t0_count == 8'h01);
                        t0_ready <= 1'b0;
                        t0_state <= (t0_count == 8'h01) ? 2'b10 : 2'b01;
                    end
                end
                
                2'b10: begin // 最終サイクル
                    t0_count <= 8'hFF;
                    t0_mem_read_en <= 1'b0;
                    t0_valid <= 1'b0;
                    t0_last <= 1'b0;
                    t0_ready <= 1'b1;
                    t0_state <= 2'b00;
                end
                
                default: begin
                    t0_count <= 8'hFF;
                    t0_mem_addr <= {ADDR_WIDTH{1'b0}};
                    t0_mem_read_en <= 1'b0;
                    t0_valid <= 1'b0;
                    t0_last <= 1'b0;
                    t0_ready <= 1'b1;
                    t0_state <= 2'b00;
                end
            endcase
        end
    end
    
    // T1ステージの制御（メモリアクセス）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t1_data <= {DATA_WIDTH{1'b0}};
            t1_valid <= 1'b0;
            t1_last <= 1'b0;
            t1_ready <= 1'b1;
        end else if (d_ready) begin
            if (t0_valid) begin
                // メモリレイテンシ1のため、アドレスをデータとして使用
                t1_data <= t0_mem_addr;
                t1_valid <= 1'b1;
                t1_last <= t0_last;
            end else begin
                t1_valid <= 1'b0;
                t1_last <= 1'b0;
            end
        end
    end

endmodule 