// Dual Port RAM Module with Different Read/Write Data Widths
// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.

module dual_width_dual_port_ram #(
    parameter READ_DATA_WIDTH = 64,                              // Read data width in bits
    parameter WRITE_DATA_WIDTH = 32,                             // Write data width in bits
    parameter MEM_DEPTH = 256,                                   // Memory depth (number of words)
    parameter READ_ADDR_WIDTH = $clog2(MEM_DEPTH),               // Read address width
    parameter WRITE_ADDR_WIDTH = $clog2(MEM_DEPTH)               // Write address width
)(
    input  wire                     clk,                         // Clock input
    
    // Read port interface
    input  wire [READ_ADDR_WIDTH-1:0]   read_addr,               // Read address
    input  wire                         read_enable,             // Read enable
    output reg  [READ_DATA_WIDTH-1:0]   read_data,               // Read data output
    
    // Write port interface
    input  wire [WRITE_ADDR_WIDTH-1:0]  write_addr,              // Write address
    input  wire [WRITE_DATA_WIDTH-1:0]  write_data,              // Write data input
    input  wire [WRITE_DATA_WIDTH/8-1:0] write_enable            // Write enable (byte strobe)
);

    // Internal memory implemented with maximum data width (read/write max width)
    localparam MAX_DATA_WIDTH = (READ_DATA_WIDTH > WRITE_DATA_WIDTH) ? READ_DATA_WIDTH : WRITE_DATA_WIDTH;
    reg [MAX_DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];
    
    // Loop variable for write operation
    integer i;
    
    // Read operation (synchronous)
    always @(posedge clk) begin
        if (read_enable) begin
            // Data width conversion: convert from internal memory to read data width
            if (READ_DATA_WIDTH <= MAX_DATA_WIDTH) begin
                read_data <= memory[read_addr][READ_DATA_WIDTH-1:0];
            end else begin
                // For larger read width, combine multiple words
                read_data <= {memory[read_addr+1], memory[read_addr]};
            end
        end
    end
    
    // Write operation with byte-level control
    always @(posedge clk) begin
        for (i = 0; i < WRITE_DATA_WIDTH/8; i = i + 1) begin
            if (write_enable[i]) begin
                // Data width conversion: convert write data to internal memory width
                if (WRITE_DATA_WIDTH <= MAX_DATA_WIDTH) begin
                    memory[write_addr][i*8 +: 8] <= write_data[i*8 +: 8];
                end else begin
                    // For larger write width, split into multiple words
                    memory[write_addr][i*8 +: 8] <= write_data[i*8 +: 8];
                end
            end
        end
    end

endmodule
