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
    input  wire                     d_ready
);

    // T0A stage internal signals (Address counter)
    reg [7:0]                      t0a_count;      // Burst counter (0xFF = idle, 0x00 = last)
    reg [ADDR_WIDTH-1:0]           t0a_mem_addr;  // Current memory address
    reg                             t0a_valid;     // T0A stage valid signal
    wire                            t0a_last;      // Last burst cycle indicator
    wire                            t0a_state_ready;     // T0A stage ready signal
    
    // T0D stage internal signals (Data pipeline)
    reg [DATA_WIDTH-1:0]           t0d_data;      // T0D stage data output
    reg                             t0d_valid;     // T0D stage valid signal
    
    // T1 stage internal signals (Merge control)
    reg [ADDR_WIDTH-1:0]           t1_addr;       // T1 stage address output
    reg [DATA_WIDTH-1:0]           t1_data;       // T1 stage data output
    wire                            t1_we;         // T1 stage write enable
    reg                             t1_valid;      // T1 stage valid signal
    reg                             t1_last;       // T1 stage last signal
    
    // T2 stage internal signals (Response generation)
    reg [ADDR_WIDTH-1:0]           t2_response;   // T2 stage response output
    reg                             t2_valid;      // T2 stage valid signal
    
    // Merge control signals
    wire                            t0a_m_ready;   // T0A merge ready signal
    wire                            t0d_m_ready;   // T0D merge ready signal
    
    // Downstream interface assignments
    assign d_response = t2_response;
    assign d_valid = t2_valid;
    
    // T1 write enable assignment
    assign t1_we = t1_valid;
    
    // T0A stage control signals
    assign t0a_state_ready = (t0a_count == 8'hFF) || (t0a_count == 8'h00); // Ready when idle or last cycle
    assign t0a_last = (t0a_count == 8'h00); // Last cycle when counter reaches 0
    
    // Ready signal assignments
    assign u_addr_ready = t0a_state_ready && t0a_m_ready && d_ready; // Upstream address ready when all conditions met
    assign u_data_ready = t0d_m_ready && d_ready;       // Upstream data ready when all conditions met
    
    // Merge ready generation
    // T0A_M_Ready: T0DがValid && T0Aがnot Valid またはT0DとT0Aの両方がnot Valid またはT0DとT0Aの両方がValid
    assign t0a_m_ready = (t0d_valid && !t0a_valid) || (!t0d_valid && !t0a_valid) || (t0d_valid && t0a_valid);
    // T0D_M_Ready: T0Dがnot Valid && T0AがValid またはT0DとT0Aの両方がnot Valid またはT0DとT0Aの両方がValid
    assign t0d_m_ready = (!t0d_valid && t0a_valid) || (!t0d_valid && !t0a_valid) || (t0d_valid && t0a_valid);
    
    // T0A stage control logic (Address counter)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t0a_count <= 8'hFF;                        // Initialize to idle state
            t0a_mem_addr <= {ADDR_WIDTH{1'b0}};        // Initialize address to 0
            t0a_valid <= 1'b0;                         // Initialize valid to 0
        end else if (d_ready) begin
            if (t0a_m_ready) begin
                case (t0a_state_ready)
                    1'b1: begin // Ready state (Idle or last cycle)
                        t0a_count <= u_length;          // Load burst length
                        t0a_mem_addr <= u_addr;         // Load start address
                        t0a_valid <= u_addr_valid;      // Set valid based on upstream
                    end
                    1'b0: begin // Not ready state (Bursting)
                        t0a_count <= t0a_count - 8'h01; // Decrement burst counter
                        t0a_mem_addr <= t0a_mem_addr + 1; // Increment memory address
                        t0a_valid <= 1'b1;              // Keep valid during burst
                    end
                endcase
            end
        end
    end
    
    // T0D stage control logic (Data pipeline)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t0d_data <= {DATA_WIDTH{1'b0}};             // Initialize data to 0
            t0d_valid <= 1'b0;                          // Initialize valid to 0
        end else if (d_ready) begin
            if (t0d_m_ready) begin
                t0d_data <= u_data;                     // Update data from upstream
                t0d_valid <= u_data_valid;              // Set valid based on upstream
            end
        end
    end
    
    // T1 stage control logic (Merge control)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t1_addr <= {ADDR_WIDTH{1'b0}};              // Initialize address to 0
            t1_data <= {DATA_WIDTH{1'b0}};              // Initialize data to 0
            t1_valid <= 1'b0;                           // Initialize valid to 0
            t1_last <= 1'b0;                            // Initialize last to 0
        end else if (d_ready) begin
            t1_addr <= t0a_mem_addr;                    // Forward T0A address
            t1_data <= t0d_data;                        // Forward T0D data
            t1_valid <= (t0a_valid && t0d_valid);       // Valid when both T0A and T0D are valid
            t1_last <= t0a_last;                        // Forward T0A last signal
        end
    end
    
    // T2 stage control logic (Response generation)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t2_response <= {ADDR_WIDTH{1'b0}};           // Initialize response to 0
            t2_valid <= 1'b0;                           // Initialize valid to 0
        end else if (d_ready) begin
            t2_valid <= t1_valid;                       // Forward T1 valid signal
            t2_response <= ((t1_addr == t1_data) && t1_we) ? t1_addr : {ADDR_WIDTH{1'bx}}; // Generate response based on condition
        end
    end

endmodule 