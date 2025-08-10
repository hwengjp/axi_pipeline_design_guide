// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

module burst_write_pipeline #(
    parameter DATA_WIDTH = 32,        // Data width in bits
    parameter ADDR_WIDTH = 32,        // Address width in bits
    parameter MAX_BURST_LENGTH = 4    // Maximum burst length
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Upstream Address Interface (Input)
    input  wire [ADDR_WIDTH-1:0]   u_addr,
    input  wire [7:0]              u_length,  // Burst length - 1
    input  wire                     u_addr_valid,
    output wire                     u_addr_ready,
    
    // Upstream Data Interface (Input)
    input  wire [DATA_WIDTH-1:0]   u_data,
    input  wire                     u_data_valid,
    output wire                     u_data_ready,
    
    // Downstream Response Interface (Output)
    output wire [ADDR_WIDTH-1:0]   d_response,
    output wire                     d_valid,
    input  wire                     d_ready,
    
    // Debug signals for T1 stage
    output wire [ADDR_WIDTH-1:0]   test_t1_addr,
    output wire [DATA_WIDTH-1:0]   test_t1_data,
    output wire                     test_t1_we,
    output wire                     test_t1_valid,
    output wire                     test_t1_last,
    output wire                     test_d_ready
);

    // T0A stage internal signals (Address counter)
    reg [7:0]                      t0a_count;
    reg [ADDR_WIDTH-1:0]           t0a_mem_addr;
    reg                             t0a_valid;
    reg                             t0a_last;
    reg                             t0a_ready;
    reg [1:0]                      t0a_state;  // 0: Idle, 1: Bursting, 2: Final cycle
    
    // T0D stage internal signals (Data pipeline)
    reg [DATA_WIDTH-1:0]           t0d_data;
    reg                             t0d_valid;
    reg                             t0d_last;
    reg                             t0d_ready;
    
    // T1 stage internal signals (Merge control)
    reg [ADDR_WIDTH-1:0]           t1_addr;
    reg [DATA_WIDTH-1:0]           t1_data;
    reg                             t1_we;
    reg                             t1_valid;
    reg                             t1_last;
    reg                             t1_ready;
    
    // T2 stage internal signals (Response generation)
    reg [ADDR_WIDTH-1:0]           t2_response;
    reg                             t2_valid;
    reg                             t2_ready;
    
    // Merge control signals
    wire                            t0a_m_ready;
    wire                            t0d_m_ready;
    
    // Downstream interface assignments
    assign d_response = t2_response;
    assign d_valid = t2_valid;
    
    // Debug signal assignments
    assign test_t1_addr = t1_addr;
    assign test_t1_data = t1_data;
    assign test_t1_we = t1_we;
    assign test_t1_valid = t1_valid;
    assign test_t1_last = t1_last;
    assign test_d_ready = d_ready;
    
    // Ready signal assignments
    assign u_addr_ready = t0a_ready && t0a_m_ready && d_ready;
    assign u_data_ready = t0d_ready && t0d_m_ready && d_ready;
    
    // Merge ready generation
    // T0A_M_Ready: T0DがValid && T0Aがnot Valid またはT0DとT0Aの両方がnot Valid またはT0DとT0Aの両方がValid
    assign t0a_m_ready = (t0d_valid && !t0a_valid) || (!t0d_valid && !t0a_valid) || (t0d_valid && t0a_valid);
    // T0D_M_Ready: T0Dがnot Valid && T0AがValid またはT0DとT0Aの両方がnot Valid またはT0DとT0Aの両方がValid
    assign t0d_m_ready = (!t0d_valid && t0a_valid) || (!t0d_valid && !t0a_valid) || (t0d_valid && t0a_valid);
    
    // T0A stage control (Address counter - similar to burst_read_pipeline)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t0a_count <= 8'hFF;
            t0a_mem_addr <= {ADDR_WIDTH{1'b0}};
            t0a_valid <= 1'b0;
            t0a_last <= 1'b0;
            t0a_ready <= 1'b1;
            t0a_state <= 2'b00;
        end else if (d_ready) begin
            case (t0a_state)
                2'b00: begin // Idle state
                    if (u_addr_valid && u_addr_ready) begin
                        t0a_count <= u_length;
                        t0a_mem_addr <= u_addr;
                        t0a_valid <= 1'b1;
                        t0a_last <= (u_length == 8'h00);
                        t0a_ready <= (u_length == 8'h00);
                        t0a_state <= (u_length == 8'h00) ? 2'b00 : 2'b01;
                    end else begin
                        t0a_valid <= 1'b0;
                        t0a_last <= 1'b0;
                    end
                end
                
                2'b01: begin // Bursting state
                    if (t0a_count > 8'h00) begin
                        t0a_count <= t0a_count - 8'h01;
                        t0a_mem_addr <= t0a_mem_addr + 1;
                        t0a_valid <= 1'b1;
                        t0a_last <= (t0a_count == 8'h01);
                        t0a_ready <= (t0a_count == 8'h01) ? 1'b1 : 1'b0;  // H only when T0A_Count=1
                        t0a_state <= (t0a_count == 8'h01) ? 2'b10 : 2'b01;
                    end
                end
                
                2'b10: begin // Final cycle
                    if (u_addr_valid && u_addr_ready) begin
                        // T0A_u_Ready && T0A_u_Valid true: process new burst request
                        t0a_count <= u_length;
                        t0a_mem_addr <= u_addr;
                        t0a_valid <= 1'b1;
                        t0a_last <= (u_length == 8'h00);
                        t0a_ready <= (u_length == 8'h00);
                        t0a_state <= (u_length == 8'h00) ? 2'b00 : 2'b01;
                    end else begin
                        // T0A_u_Ready && T0A_u_Valid false: return to idle state
                        t0a_count <= 8'hFF;
                        t0a_valid <= 1'b0;
                        t0a_last <= 1'b0;
                        t0a_ready <= 1'b1;
                        t0a_state <= 2'b00;
                    end
                end
                
                default: begin
                    t0a_count <= 8'hFF;
                    t0a_mem_addr <= {ADDR_WIDTH{1'b0}};
                    t0a_valid <= 1'b0;
                    t0a_last <= 1'b0;
                    t0a_ready <= 1'b1;
                    t0a_state <= 2'b00;
                end
            endcase
        end
    end
    
    // T0D stage control (Data pipeline)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t0d_data <= {DATA_WIDTH{1'b0}};
            t0d_valid <= 1'b0;
            t0d_last <= 1'b0;
            t0d_ready <= 1'b1;
        end else if (d_ready) begin
            if (u_data_valid && u_data_ready) begin
                t0d_data <= u_data;
                t0d_valid <= 1'b1;
                t0d_last <= 1'b0; // Data doesn't have last signal in this implementation
            end else begin
                t0d_valid <= 1'b0;
                t0d_last <= 1'b0;
            end
        end
    end
    
    // T1 stage control (Merge control)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t1_addr <= {ADDR_WIDTH{1'b0}};
            t1_data <= {DATA_WIDTH{1'b0}};
            t1_we <= 1'b0;
            t1_valid <= 1'b0;
            t1_last <= 1'b0;
            t1_ready <= 1'b1;
        end else if (d_ready) begin
            if (t0a_valid && t0d_valid) begin
                // Both address and data are valid, proceed with write
                t1_addr <= t0a_mem_addr;
                t1_data <= t0d_data;
                t1_we <= 1'b1;
                t1_valid <= 1'b1;
                t1_last <= t0a_last;
            end else begin
                t1_valid <= 1'b0;
                t1_we <= 1'b0;
                t1_last <= 1'b0;
            end
        end
    end
    
    // T2 stage control (Response generation)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t2_response <= {ADDR_WIDTH{1'b0}};
            t2_valid <= 1'b0;
            t2_ready <= 1'b1;
        end else if (d_ready) begin
            if (t1_valid) begin
                // Check if write is successful (address equals data and WE is asserted)
                if (t1_addr == t1_data && t1_we) begin
                    t2_response <= t1_addr; // Use address as response
                end else begin
                    t2_response <= {ADDR_WIDTH{1'bx}}; // Invalid response
                end
                t2_valid <= 1'b1;
            end else begin
                t2_valid <= 1'b0;
            end
        end
    end

endmodule 