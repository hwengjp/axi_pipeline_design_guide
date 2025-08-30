// Dual Port RAM Module
// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.

module dual_port_ram #(
    parameter DATA_WIDTH = 64,                                    // Data width in bits
    parameter MEM_DEPTH = 256,                                    // Memory depth (number of words)
    parameter ADDR_WIDTH = $clog2(MEM_DEPTH)                      // Address width (auto-calculated)
)(
    input  wire                     clk,                         // Clock input
    
    // Read port interface
    input  wire [ADDR_WIDTH-1:0]   read_addr,                   // Read address
    input  wire                     read_enable,                 // Read enable
    output reg  [DATA_WIDTH-1:0]   read_data,                   // Read data output
    
    // Write port interface
    input  wire [ADDR_WIDTH-1:0]   write_addr,                  // Write address
    input  wire [DATA_WIDTH-1:0]   write_data,                  // Write data input
    input  wire [DATA_WIDTH/8-1:0] write_enable                 // Write enable (byte strobe)
);

    // Memory array declaration
    reg [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];
    
    // Loop variable for write operation
    integer i;
    
    // Read operation (synchronous)
    always @(posedge clk) begin
        if (read_enable) begin
            read_data <= memory[read_addr];  // Memory read with 1 clock latency
        end
    end
    
    // Write operation with byte-level control
    always @(posedge clk) begin
        for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
            if (write_enable[i]) begin
                memory[write_addr][i*8 +: 8] <= write_data[i*8 +: 8];
            end
        end
    end

endmodule
