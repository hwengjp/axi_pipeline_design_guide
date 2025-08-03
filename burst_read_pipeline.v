// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

module burst_read_pipeline #(
    parameter DATA_WIDTH = 32,        // Data width in bits
    parameter ADDR_WIDTH = 32,        // Address width in bits
    parameter MAX_BURST_LENGTH = 4    // Maximum burst length
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Upstream Interface (Input)
    input  wire [ADDR_WIDTH-1:0]   u_addr,
    input  wire [7:0]              u_length,  // Burst length - 1
    input  wire                     u_valid,
    output wire                     u_ready,
    
    // Downstream Interface (Output)
    output wire [DATA_WIDTH-1:0]   d_data,
    output wire                     d_valid,
    output wire                     d_last,
    input  wire                     d_ready
);

    // T0 stage internal signals (Address counter and Read Enable)
    reg [7:0]                      t0_count;
    reg [ADDR_WIDTH-1:0]           t0_mem_addr;
    reg                             t0_mem_read_en;
    reg                             t0_valid;
    reg                             t0_last;
    reg                             t0_ready;
    reg [1:0]                      t0_state;  // 0: Idle, 1: Bursting, 2: Final cycle
    
    // T1 stage internal signals (Memory access)
    reg [DATA_WIDTH-1:0]           t1_data;
    reg                             t1_valid;
    reg                             t1_last;
    reg                             t1_ready;
    
    // Internal memory interface (not exposed externally)
    wire [DATA_WIDTH-1:0]          mem_data;
    wire                            mem_valid;
    
    // Downstream interface assignments
    assign d_data = t1_data;
    assign d_valid = t1_valid;
    assign d_last = t1_last;
    
    // T0 stage u_ready generation (T0_Ready AND d_ready)
    assign u_ready = t0_ready && d_ready;
    
    // T0 stage control (Address counter and Read Enable)
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
                2'b00: begin // Idle state
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
                
                2'b01: begin // Bursting state
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
                
                2'b10: begin // Final cycle
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
    
    // T1 stage control (Memory access)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t1_data <= {DATA_WIDTH{1'b0}};
            t1_valid <= 1'b0;
            t1_last <= 1'b0;
            t1_ready <= 1'b1;
        end else if (d_ready) begin
            if (t0_valid) begin
                // Memory latency 1: use address as data
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