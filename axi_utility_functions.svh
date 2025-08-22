// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// axi_utility_functions.svh
// Auto-generated from axi_simple_dual_port_ram_tb.sv
// DO NOT MODIFY - This file is auto-generated

`ifndef AXI_UTILITY_FUNCTIONS_SVH
`define AXI_UTILITY_FUNCTIONS_SVH

// Include common definitions
`include "axi_common_defs.svh"

// Function: get_burst_type_value
// Extracted from original testbench

function automatic logic [1:0] get_burst_type_value(input string burst_type);
    case (burst_type)
        "FIXED": return 2'b00;
        "INCR":  return 2'b01;
        "WRAP":  return 2'b10;
        default: return 2'b01;
    endcase
endfunction

// Function: size_to_bytes
// Extracted from original testbench

function automatic int size_to_bytes(input logic [2:0] size);
    return (1 << size);
endfunction

// Function: size_to_string
// Extracted from original testbench

function automatic string size_to_string(input logic [2:0] size);
    return $sformatf("%0d(%0d bytes)", size, size_to_bytes(size));
endfunction

// Function: align_address_to_boundary
// Extracted from original testbench

function automatic logic [AXI_ADDR_WIDTH-1:0] align_address_to_boundary(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input int burst_size_bytes,
    input string burst_type,
    input logic [2:0] size
);
    logic [AXI_ADDR_WIDTH-1:0] aligned_addr = address;
    case (burst_type)
        "WRAP": begin
            int wrap_boundary = burst_size_bytes;
            aligned_addr = (address / wrap_boundary) * wrap_boundary;
        end
        "INCR", "FIXED": begin
            int size_bytes = 2 ** size;  // Byte count based on SIZE
            aligned_addr = (address / size_bytes) * size_bytes;
        end
        default: begin
            int size_bytes = 2 ** size;  // Byte count based on SIZE
            aligned_addr = (address / size_bytes) * size_bytes;
        end
    endcase
    return aligned_addr;
endfunction

// Function: check_read_data
// Extracted from original testbench

function automatic bit check_read_data(
    input logic [AXI_DATA_WIDTH-1:0] actual_data,
    input logic [AXI_DATA_WIDTH-1:0] expected_data,
    input logic [AXI_STRB_WIDTH-1:0] expected_strobe
);
    bit check_result = 1'b1;
    int byte_idx;
    
    // Check only bytes with valid strobe
    for (byte_idx = 0; byte_idx < AXI_STRB_WIDTH; byte_idx++) begin
        if (expected_strobe[byte_idx]) begin
            // If this byte is valid, compare data
            if (actual_data[byte_idx*8 +: 8] !== expected_data[byte_idx*8 +: 8]) begin
                check_result = 1'b0;
                $error("Byte %0d mismatch: expected=0x%02h, actual=0x%02h", 
                       byte_idx, expected_data[byte_idx*8 +: 8], actual_data[byte_idx*8 +: 8]);
            end
        end
    end
    
    return check_result;
endfunction

// Function: get_burst_type_string
// Extracted from original testbench

function automatic string get_burst_type_string(input logic [1:0] burst);
    case (burst)
        2'b00: return "FIXED";
        2'b01: return "INCR";
        2'b10: return "WRAP";
        default: return "INCR";
    endcase
endfunction

// Function: generate_strobe_pattern
// Extracted from original testbench

function automatic logic [AXI_STRB_WIDTH-1:0] generate_strobe_pattern(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input int data_width,
    input string burst_type
);
    logic [AXI_STRB_WIDTH-1:0] strobe_pattern = 0;
    int bus_width_bytes = data_width / 8;
    int burst_size_bytes = size_to_bytes(size);
    
    if (burst_type == "FIXED") begin
        // FIXED: Start from address offset
        int addr_offset = address % bus_width_bytes;
        int strobe_start = addr_offset;
        int strobe_end = strobe_start + burst_size_bytes - 1;
        
        // Check address and size consistency
        if (strobe_end >= bus_width_bytes) begin
            $error("FIXED transfer error: Address 0x%h with size %0d exceeds bus width %0d bytes. strobe_end=%0d", 
                   address, burst_size_bytes, bus_width_bytes, strobe_end);
            $finish;
        end
        
        // Generate STROBE pattern (byte-wise)
        for (int byte_idx = strobe_start; byte_idx <= strobe_end; byte_idx++) begin
            strobe_pattern[byte_idx] = 1'b1;
        end
    end else begin
        // INCR/WRAP: Start from least significant bits of address
        int addr_offset = address % bus_width_bytes;
        int strobe_start = addr_offset;
        int strobe_end = strobe_start + burst_size_bytes - 1;
        
        // Check if transfer crosses bus width boundary
        if (strobe_end >= bus_width_bytes) begin
            // Cross boundary: wrap around to start
            strobe_end = strobe_end % bus_width_bytes;
            
            // Set strobe from start to end (wrapped)
            for (int byte_idx = 0; byte_idx <= strobe_end; byte_idx++) begin
                strobe_pattern[byte_idx] = 1'b1;
            end
            for (int byte_idx = strobe_start; byte_idx < bus_width_bytes; byte_idx++) begin
                strobe_pattern[byte_idx] = 1'b1;
            end
        end else begin
            // No cross boundary: simple range
            for (int byte_idx = strobe_start; byte_idx <= strobe_end; byte_idx++) begin
                strobe_pattern[byte_idx] = 1'b1;
            end
        end
    end
    
    return strobe_pattern;
endfunction

// Function: generate_fixed_strobe_pattern
// Extracted from original testbench

function automatic logic [AXI_STRB_WIDTH-1:0] generate_fixed_strobe_pattern(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input int data_width
);
    logic [AXI_STRB_WIDTH-1:0] strobe_pattern = 0;
    int bus_width_bytes = data_width / 8;
    int burst_size_bytes = size_to_bytes(size);
    
    int addr_offset = address % bus_width_bytes;
    int strobe_start = addr_offset;
    int strobe_end = strobe_start + burst_size_bytes - 1;
    
    // Check address and size consistency
    if (strobe_end >= bus_width_bytes) begin
        $error("FIXED transfer error: Address 0x%h with size %0d exceeds bus width %0d bytes. strobe_end=%0d", 
               address, burst_size_bytes, bus_width_bytes, strobe_end);
        $finish;
    end
    
    // Generate STROBE pattern (byte-wise)
    for (int byte_idx = strobe_start; byte_idx <= strobe_end; byte_idx++) begin
        strobe_pattern[byte_idx] = 1'b1;
    end
    
    return strobe_pattern;
endfunction

`endif // AXI_UTILITY_FUNCTIONS_SVH
