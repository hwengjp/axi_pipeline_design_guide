// AXI4 Utility Functions Header File
// This file contains common utility functions for the testbench

`ifndef AXI_UTILITY_FUNCTIONS_SVH
`define AXI_UTILITY_FUNCTIONS_SVH

// Include common definitions
`include "axi_common_defs.svh"

// Utility functions
function automatic logic [1:0] get_burst_type_value(input string burst_type);
    case (burst_type)
        "FIXED": return 2'b00;
        "INCR":  return 2'b01;
        "WRAP":  return 2'b10;
        default: return 2'b01;  // Default to INCR
    endcase
endfunction

function automatic int size_to_bytes(input logic [2:0] size);
    return (1 << size);
endfunction

function automatic string size_to_string(input logic [2:0] size);
    case (size)
        3'b000: return "1BYTE";
        3'b001: return "2BYTE";
        3'b010: return "4BYTE";
        3'b011: return "8BYTE";
        3'b100: return "16BYTE";
        3'b101: return "32BYTE";
        3'b110: return "64BYTE";
        3'b111: return "128BYTE";
        default: return "UNKNOWN";
    endcase
endfunction

function automatic logic [AXI_ADDR_WIDTH-1:0] align_address_to_boundary(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input int burst_size_bytes,
    input string burst_type,
    input logic [2:0] size
);
    logic [AXI_ADDR_WIDTH-1:0] aligned_addr;
    int burst_size;
    
    burst_size = 1 << size;
    
    case (burst_type)
        "FIXED": begin
            // For FIXED burst, align to burst size boundary
            aligned_addr = (address / burst_size) * burst_size;
        end
        "INCR": begin
            // For INCR burst, no special alignment needed
            aligned_addr = address;
        end
        "WRAP": begin
            // For WRAP burst, align to burst size boundary
            aligned_addr = (address / burst_size) * burst_size;
        end
        default: begin
            // Default to INCR behavior
            aligned_addr = address;
        end
    endcase
    
    return aligned_addr;
endfunction

function automatic bit check_read_data(
    input logic [AXI_DATA_WIDTH-1:0] actual_data,
    input logic [AXI_DATA_WIDTH-1:0] expected_data,
    input logic [AXI_STRB_WIDTH-1:0] expected_strobe
);
    logic [AXI_DATA_WIDTH-1:0] masked_actual;
    logic [AXI_DATA_WIDTH-1:0] masked_expected;
    int byte_idx;
    
    // Apply strobe mask to both actual and expected data
    masked_actual = 0;
    masked_expected = 0;
    
    for (byte_idx = 0; byte_idx < AXI_STRB_WIDTH; byte_idx++) begin
        if (expected_strobe[byte_idx]) begin
            masked_actual[byte_idx*8 +: 8] = actual_data[byte_idx*8 +: 8];
            masked_expected[byte_idx*8 +: 8] = expected_data[byte_idx*8 +: 8];
        end
    end
    
    return (masked_actual === masked_expected);
endfunction

function automatic string get_burst_type_string(input logic [1:0] burst);
    case (burst)
        2'b00: return "FIXED";
        2'b01: return "INCR";
        2'b10: return "WRAP";
        default: return "UNKNOWN";
    endcase
endfunction

function automatic logic [AXI_STRB_WIDTH-1:0] generate_strobe_pattern(
    input logic [AXI_ADDR_WIDTH-1:0] addr,
    input logic [2:0] size,
    input string burst_type
);
    logic [AXI_STRB_WIDTH-1:0] strobe;
    int byte_offset;
    int num_bytes;
    
    // Calculate byte offset from address
    byte_offset = addr % (AXI_DATA_WIDTH / 8);
    num_bytes = 1 << size;
    
    // Initialize strobe to all zeros
    strobe = '0;
    
    // Set strobe bits based on address alignment and transfer size
    for (int i = 0; i < AXI_STRB_WIDTH; i++) begin
        if (i >= byte_offset && i < (byte_offset + num_bytes)) begin
            strobe[i] = 1'b1;
        end
    end
    
    return strobe;
endfunction

function automatic logic [AXI_STRB_WIDTH-1:0] generate_fixed_strobe_pattern(
    input logic [AXI_ADDR_WIDTH-1:0] addr,
    input logic [2:0] size
);
    logic [AXI_STRB_WIDTH-1:0] strobe;
    int byte_offset;
    int num_bytes;
    
    // Calculate byte offset from address
    byte_offset = addr % (AXI_DATA_WIDTH / 8);
    num_bytes = 1 << size;
    
    // Initialize strobe to all zeros
    strobe = '0;
    
    // Set strobe bits based on address alignment and transfer size
    for (int i = 0; i < AXI_STRB_WIDTH; i++) begin
        if (i >= byte_offset && i < (byte_offset + num_bytes)) begin
            strobe[i] = 1'b1;
        end
    end
    
    return strobe;
endfunction

`endif // AXI_UTILITY_FUNCTIONS_SVH
