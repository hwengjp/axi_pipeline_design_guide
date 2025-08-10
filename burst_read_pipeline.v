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
    reg [7:0]                      t0_count;      // Burst counter (0xFF = idle, 0x00 = last)
    reg [ADDR_WIDTH-1:0]           t0_mem_addr;  // Current memory address
    wire                            t0_mem_read_en; // Memory read enable signal
    reg                             t0_valid;     // T0 stage valid signal
    wire                            t0_last;      // Last burst cycle indicator
    wire                            t0_ready;     // T0 stage ready signal
    wire [1:0]                     t0_state;     // State machine: 00=Idle, 01=Bursting, 10=Final

    // T1 stage internal signals (Memory access)
    reg [DATA_WIDTH-1:0]           t1_data;      // T1 stage data output
    reg                             t1_valid;     // T1 stage valid signal
    reg                             t1_last;      // T1 stage last signal
    reg                             t1_ready;     // T1 stage ready signal

    // Internal memory interface (not exposed externally)
    wire [DATA_WIDTH-1:0]          mem_data;     // Memory data input (unused in this implementation)
    wire                            mem_valid;    // Memory valid signal (unused in this implementation)

    // Downstream interface assignments
    assign d_data  = t1_data;
    assign d_valid = t1_valid;
    assign d_last  = t1_last;

    // T0 stage control signals
    assign u_ready      = t0_ready && d_ready;           // Upstream ready when both T0 and downstream are ready
    assign t0_ready     = (t0_count == 8'hFF) || (t0_count == 8'h00); // Ready when idle or last cycle
    assign t0_state     = ((t0_count == 8'hFF) || (t0_count == 8'h00)) ? 2'b00 : 2'b01; // State encoding
    assign t0_last      = (t0_count == 8'h00);           // Last cycle when counter reaches 0
    assign t0_mem_read_en = (t0_count != 8'hFF);        // Enable memory read when not idle

    // T0 stage control logic (Address counter and Read Enable)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t0_count    <= 8'hFF;                        // Initialize to idle state
            t0_mem_addr <= {ADDR_WIDTH{1'b0}};           // Initialize address to 0
            t0_valid    <= 1'b0;                         // Initialize valid to 0
        end else if (d_ready) begin
            case (t0_state)
                2'b00: begin // Idle state
                    t0_count    <= u_valid ? u_length : 8'hFF;  // Load burst length or stay idle
                    t0_mem_addr <= u_addr;                       // Load start address
                    t0_valid    <= u_valid;                      // Set valid based on upstream
                end
                2'b01: begin // Bursting state
                    t0_count    <= t0_count - 8'h01;            // Decrement burst counter
                    t0_mem_addr <= t0_mem_addr + 1;             // Increment memory address
                    t0_valid    <= 1'b1;                        // Keep valid during burst
                end
            endcase
        end
    end

    // T1 stage control logic (Memory access)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t1_data  <= {DATA_WIDTH{1'b0}};              // Initialize data to 0
            t1_valid <= 1'b0;                             // Initialize valid to 0
            t1_last  <= 1'b0;                             // Initialize last to 0
            t1_ready <= 1'b1;                             // Initialize ready to 1
        end else if (d_ready) begin
            // Memory latency 1: use address as data (simplified for demonstration)
            t1_data  <= (t0_mem_read_en) ? t0_mem_addr : t1_data; // Update data or hold at disable
            t1_valid <= t0_valid;                                // Forward T0 valid signal
            t1_last  <= t0_last;                                 // Forward T0 last signal
        end
    end

endmodule