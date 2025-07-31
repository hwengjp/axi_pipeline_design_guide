// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

module pipeline_insert #(
    parameter DATA_WIDTH = 64
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Upstream Interface (Input) - axi_ram_core側
    input  wire [DATA_WIDTH-1:0]    u_data,
    input  wire                     u_valid,
    output wire                     u_ready,
    
    // Downstream Interface (Output) - バス側
    output wire [DATA_WIDTH-1:0]    d_data,
    output wire                     d_valid,
    input  wire                     d_ready
);

    // Internal signals for 1-stage pipeline
    reg [DATA_WIDTH-1:0] pipe_data;
    reg                   pipe_valid;
    
    // d_readyの1クロック遅延信号
    reg                   d_ready_d;
    
    // State信号（State=[Ready_u,Ready_d]）
    wire [1:0] state;
    assign state = {u_ready, d_ready_d};
    
    // u_readyで制御された1段のパイプライン
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pipe_data  <= {DATA_WIDTH{1'b0}};
            pipe_valid <= 1'b0;
        end else if (u_ready) begin
            pipe_data  <= u_data;
            pipe_valid <= u_valid;
        end
    end
    
    // d_readyの1クロック遅延
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d_ready_d <= 1'b0;
        end else begin
            d_ready_d <= d_ready;
        end
    end
    
    // d_ready_dをu_readyに接続
    assign u_ready = d_ready_d;
    
    // Stateに基づくd_dataとd_validの生成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d_data  <= {DATA_WIDTH{1'b0}};
            d_valid <= 1'b0;
        end else begin
            case (state)
                2'b00: begin // State=0: ホールド（現在の値を保持）
                    // 出力値を保持（変更なし）
                end
                2'b01: begin // State=1: T4（パイプラインT4の値を出力）
                    d_data  <= pipe_data;
                    d_valid <= pipe_valid;
                end
                2'b10: begin // State=2: T4（パイプラインT4の値を出力）
                    d_data  <= pipe_data;
                    d_valid <= pipe_valid;
                end
                2'b11: begin // State=3: T3（パイプラインT3の値を出力）
                    d_data  <= u_data;
                    d_valid <= u_valid;
                end
            endcase
        end
    end

endmodule 