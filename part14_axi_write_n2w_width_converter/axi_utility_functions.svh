// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// AXI4 Utility and Helper Functions

`ifndef AXI_UTILITY_FUNCTIONS_SVH
`define AXI_UTILITY_FUNCTIONS_SVH

// Include common definitions
`include "axi_common_defs.svh"

// Function: get_burst_type_value
function automatic logic [1:0] get_burst_type_value(input string burst_type);
    case (burst_type)
        "FIXED": return 2'b00;
        "INCR":  return 2'b01;
        "WRAP":  return 2'b10;
        default: return 2'b01;
    endcase
endfunction

// Function: size_to_bytes
function automatic int size_to_bytes(input logic [2:0] size);
    return (1 << size);
endfunction

// Function: size_to_string
function automatic string size_to_string(input logic [2:0] size);
    return $sformatf("%0d(%0d bytes)", size, size_to_bytes(size));
endfunction

// Function: align_address_to_boundary
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
function automatic bit check_read_data(
    input logic [READ_SOURCE_WIDTH-1:0] actual_data,
    input logic [READ_SOURCE_WIDTH-1:0] expected_data,
    input logic [READ_SOURCE_STRB_WIDTH-1:0] expected_strobe
);
    bit check_result = 1'b1;
    int byte_idx;
    
    // Check only bytes with valid strobe
    for (byte_idx = 0; byte_idx < READ_SOURCE_STRB_WIDTH; byte_idx++) begin
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
function automatic string get_burst_type_string(input logic [1:0] burst);
    case (burst)
        2'b00: return "FIXED";
        2'b01: return "INCR";
        2'b10: return "WRAP";
        default: return "INCR";
    endcase
endfunction

// Function: generate_strobe_pattern
function automatic logic [WRITE_SOURCE_STRB_WIDTH-1:0] generate_strobe_pattern(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input int data_width,
    input string burst_type
);
    logic [WRITE_SOURCE_STRB_WIDTH-1:0] strobe_pattern = 0;
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
function automatic logic [WRITE_SOURCE_STRB_WIDTH-1:0] generate_fixed_strobe_pattern(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input int data_width
);
    logic [WRITE_SOURCE_STRB_WIDTH-1:0] strobe_pattern = 0;
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

// Function: generate_random_strobe_no_alignment
// INCR/WRAP転送用のランダムストローブ生成（アドレス丸めなし）
function automatic logic [WRITE_SOURCE_STRB_WIDTH-1:0] generate_random_strobe_no_alignment(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input int data_width
);
    logic [WRITE_SOURCE_STRB_WIDTH-1:0] strobe_pattern = 0;
    int bus_width_bytes = data_width / 8;
    int burst_size_bytes = size_to_bytes(size);
    
    // アドレス丸めなしで、元のアドレスのまま処理
    int addr_offset = address % bus_width_bytes;
    
    // 転送サイズに基づいて、最低限必要なバイト数を決定
    int min_required_bytes = burst_size_bytes;
    
    // 最低限必要なバイト数分のストローブを必ず1にする
    for (int byte_idx = 0; byte_idx < min_required_bytes && byte_idx < bus_width_bytes; byte_idx++) begin
        strobe_pattern[byte_idx] = 1'b1;
    end
    
    // 残りのバイトをランダムに設定（50%の確率で1）
    for (int byte_idx = min_required_bytes; byte_idx < bus_width_bytes; byte_idx++) begin
        strobe_pattern[byte_idx] = ($urandom % 2) ? 1'b1 : 1'b0;
    end
    
    return strobe_pattern;
endfunction

// Function: calculate_strobe_by_size_and_address_with_transfer
// SIZEとアドレスに基づく有効バイト位置の計算（バースト内ビート位置考慮）
function automatic logic [WRITE_SOURCE_STRB_WIDTH-1:0] calculate_strobe_by_size_and_address_with_transfer(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input int bus_width_bits,
    input int transfer_index
);
    logic [WRITE_SOURCE_STRB_WIDTH-1:0] strobe = '0;
    int bus_width_bytes = bus_width_bits / 8;
    int size_bytes = size_to_bytes(size);
    
    // 初期アドレスに基づく基本オフセット
    int base_offset = address % bus_width_bytes;
    
    // バースト内ビート位置に基づくオフセット
    int transfer_offset = (transfer_index * size_bytes) % bus_width_bytes;
    
    // 合計オフセット（バス幅で循環）
    int total_offset = (base_offset + transfer_offset) % bus_width_bytes;
    
    // 有効バイト位置の計算
    for (int byte_idx = 0; byte_idx < size_bytes; byte_idx++) begin
        int strobe_pos = (total_offset + byte_idx) % bus_width_bytes;
        strobe[strobe_pos] = 1'b1;
    end
    
    return strobe;
endfunction

// Function: generate_size_by_strategy
// SIZE生成関数（size_strategy対応）
function automatic logic [2:0] generate_size_by_strategy(
    input string size_strategy,
    input int bus_width_bits
);
    int bus_width_bytes = bus_width_bits / 8;
    
    case (size_strategy)
        "FULL": begin
            // バス幅に一致するSIZE
            return $clog2(bus_width_bytes);
        end
        "RANDOM": begin
            // バス幅以下の範囲でランダム
            return $urandom_range(0, $clog2(bus_width_bytes));
        end
        default: begin
            // デフォルトはFULL
            return $clog2(bus_width_bytes);
        end
    endcase
endfunction

// Function: align_address_by_size
// アドレス丸め関数（SIZE対応）
function automatic logic [AXI_ADDR_WIDTH-1:0] align_address_by_size(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input string size_strategy
);
    case (size_strategy)
        "FULL": begin
            // バス幅境界での丸め
            int bus_width_bytes = READ_SOURCE_WIDTH / 8;
            return (address / bus_width_bytes) * bus_width_bytes;
        end
        "RANDOM": begin
            // SIZEに基づく境界での丸め
            int size_bytes = size_to_bytes(size);
            return (address / size_bytes) * size_bytes;
        end
        default: begin
            // デフォルトはバス幅境界
            int bus_width_bytes = READ_SOURCE_WIDTH / 8;
            return (address / bus_width_bytes) * bus_width_bytes;
        end
    endcase
endfunction

// Function: calculate_strobe_by_size_and_address
// SIZEとアドレスに基づく有効バイト位置の計算
function automatic logic [WRITE_SOURCE_STRB_WIDTH-1:0] calculate_strobe_by_size_and_address(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input int bus_width_bits
);
    logic [WRITE_SOURCE_STRB_WIDTH-1:0] strobe = '0;
    int bus_width_bytes = bus_width_bits / 8;
    int size_bytes = size_to_bytes(size);
    
    // SIZEに基づくアドレス境界での丸め
    int aligned_addr = (address / size_bytes) * size_bytes;
    
    // 丸められたアドレスと元のアドレスの差分
    int offset = address - aligned_addr;
    
    // 有効バイト位置の計算
    for (int byte_idx = 0; byte_idx < size_bytes; byte_idx++) begin
        int strobe_pos = offset + byte_idx;
        if (strobe_pos < bus_width_bytes) begin
            strobe[strobe_pos] = 1'b1;
        end
    end
    
    return strobe;
endfunction

// Function: generate_strobe_by_size_strategy
// STROBE生成関数（SIZE対応、バースト内ビート位置考慮）
function automatic logic [WRITE_SOURCE_STRB_WIDTH-1:0] generate_strobe_by_size_strategy(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input string size_strategy,
    input int bus_width_bits,
    input int transfer_index
);
    case (size_strategy)
        "FULL": begin
            // 全ビット有効
            return '1;
        end
        "RANDOM": begin
            // SIZEとアドレスに基づく計算（バースト内ビート位置考慮）
            return calculate_strobe_by_size_and_address_with_transfer(address, size, bus_width_bits, transfer_index);
        end
        default: begin
            // デフォルトは全ビット有効
            return '1;
        end
    endcase
endfunction

`endif // AXI_UTILITY_FUNCTIONS_SVH
