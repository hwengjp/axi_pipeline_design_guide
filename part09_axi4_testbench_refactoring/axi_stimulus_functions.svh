// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// AXI4 Test Stimulus Generation Functions

`ifndef AXI_STIMULUS_FUNCTIONS_SVH
`define AXI_STIMULUS_FUNCTIONS_SVH

// Include common definitions
`include "axi_common_defs.svh"

// Function: generate_write_addr_payloads
function automatic void generate_write_addr_payloads();
    int test_count = 0;
    int i;
    int selected_length;
    string selected_type;
    logic [2:0] selected_size;
    int phase;
    logic [AXI_ADDR_WIDTH-1:0] random_offset;
    int burst_size_bytes;
    logic [AXI_ADDR_WIDTH-1:0] aligned_offset;
    logic [AXI_ADDR_WIDTH-1:0] base_addr;
    int total_weight;
    int selected_config_index;
    burst_config_t burst_cfg;
    
    // Calculate total weight for burst configuration
    total_weight = 0;
    foreach (burst_config_weights[i]) begin
        total_weight += burst_config_weights[i].weight;
    end
    
    write_debug_log($sformatf("Total weight for burst config: %0d", total_weight));
    
    // Generate TOTAL_TEST_COUNT number of payloads using weighted random selection
    for (test_count = 0; test_count < TOTAL_TEST_COUNT; test_count++) begin
        // Generate weighted random selection for burst configuration
        selected_config_index = generate_weighted_random_index_burst_config(
            burst_config_weights, 
            total_weight
        );
        
        burst_cfg = burst_config_weights[selected_config_index];
        
        // Generate random length within the selected configuration range
        selected_length = $urandom_range(burst_cfg.length_min, burst_cfg.length_max);
        selected_type = burst_cfg.burst_type;
        
        // Generate SIZE based on burst length
        if (selected_length > 0) begin
            // Burst access (LEN > 0): SIZE fixed to bus width for efficiency
            selected_size = $clog2(AXI_DATA_WIDTH / 8);  // 32-bit bus = 2 (4 bytes), 64-bit bus = 3 (8 bytes)
        end else begin
            // Single access (LEN = 0): Random SIZE for flexibility
            selected_size = $urandom_range(0, $clog2(AXI_DATA_WIDTH / 8));
        end
        
        // Calculate phase for logging purposes (not used in address calculation)
        phase = test_count / PHASE_TEST_COUNT;
        
        // Generate random offset within TEST_COUNT_ADDR_SIZE_BYTES/4
        random_offset = $urandom_range(0, TEST_COUNT_ADDR_SIZE_BYTES / 4 - 1);
        
        // Calculate burst size based on SIZE field, not bus width
        burst_size_bytes = (selected_length + 1) * (2 ** selected_size);
        
        // Align to address boundary based on SIZE
        aligned_offset = align_address_to_boundary(random_offset, burst_size_bytes, selected_type, selected_size);
        
        // Add test_count offset to avoid address overlap within same phase
        base_addr = aligned_offset + (test_count * TEST_COUNT_ADDR_SIZE_BYTES);
        
        write_addr_payloads[test_count] = '{
            test_count: test_count,
            addr: base_addr,
            burst: get_burst_type_value(selected_type),
            size: selected_size,
            id: $urandom_range(0, (1 << AXI_ID_WIDTH) - 1),
            len: selected_length,
            valid: 1'b1,
            phase: phase
        };
        
        write_debug_log($sformatf("Generated payload[%0d]: config_index=%0d, weight=%0d, type=%s, len=%0d, size=%0d(%0d bytes)", 
            test_count, selected_config_index, burst_cfg.weight, selected_type, selected_length, selected_size, 2**selected_size));
    end
    
    write_debug_log($sformatf("Generated %0d Write Address Payloads (TOTAL_TEST_COUNT=%0d)", test_count, TOTAL_TEST_COUNT));
endfunction

// Function: generate_write_addr_payloads_with_stall
function automatic void generate_write_addr_payloads_with_stall();
    int stall_index = 0;
    int i;
    int total_weight;
    int selected_index;
    int stall_cycles;
    
    foreach (write_addr_payloads[i]) begin
        write_addr_payload_t payload = write_addr_payloads[i];
        
        // Copy payload
        write_addr_payloads_with_stall[stall_index] = payload;
        stall_index++;
        
        // Insert stall based on weights
        total_weight = calculate_total_weight_generic(write_addr_bubble_weights, write_addr_bubble_weights.size());
        selected_index = generate_weighted_random_index_generic(write_addr_bubble_weights, total_weight);
        stall_cycles = write_addr_bubble_weights[selected_index].cycles;
        
        // Insert stall cycles
        for (int stall = 0; stall < stall_cycles; stall++) begin
            write_addr_payloads_with_stall[stall_index] = '{
                test_count: payload.test_count,
                addr: '0,        // Clear address to 0 when valid=0
                burst: '0,       // Clear burst to 0 when valid=0
                size: '0,        // Clear size to 0 when valid=0
                id: '0,          // Clear ID to 0 when valid=0
                len: '0,         // Clear length to 0 when valid=0
                valid: 1'b0,
                phase: payload.phase
            };
            stall_index++;
        end
    end
endfunction

// Function: generate_write_data_payloads
function automatic void generate_write_data_payloads();
    int data_index = 0;
    int i;
    write_addr_payload_t addr_payload;
    logic [AXI_DATA_WIDTH-1:0] random_data;
    logic [AXI_STRB_WIDTH-1:0] strobe_pattern;
    logic [AXI_DATA_WIDTH-1:0] strobe_mask;
    logic [AXI_DATA_WIDTH-1:0] masked_data;
    logic last_flag;
    int byte_idx;
    int burst_length;
    
    foreach (write_addr_payloads[i]) begin
        addr_payload = write_addr_payloads[i];
        burst_length = addr_payload.len + 1; // len=0 means 1 transfer, len=2 means 3 transfers
        
        // Generate data for each transfer in the burst
        for (int transfer = 0; transfer < burst_length; transfer++) begin
            // Generate random data
            random_data = $urandom();
            
            // Generate strobe pattern based on address, size, and burst type
            // Random STROBE only for FIXED single access
            if (get_burst_type_string(addr_payload.burst) == "FIXED" && addr_payload.len == 0) begin
                // FIXED single access: Generate random STROBE
                strobe_pattern = generate_strobe_pattern(
                    addr_payload.addr, 
                    addr_payload.size, 
                    AXI_DATA_WIDTH,
                    get_burst_type_string(addr_payload.burst)
                );
            end else begin
                // INCR/WRAP or FIXED burst: Use all-1 STROBE pattern
                strobe_pattern = '1;  // All bits 1
            end
            
            // Create strobe mask for data masking
            strobe_mask = 0;
            
            for (byte_idx = 0; byte_idx < AXI_STRB_WIDTH; byte_idx++) begin
                if (strobe_pattern[byte_idx]) begin
                    strobe_mask[byte_idx*8 +: 8] = 8'hFF;
                end
            end
            
            masked_data = random_data & strobe_mask;
            
            // Set last flag for the last transfer in the burst
            last_flag = (transfer == burst_length - 1) ? 1'b1 : 1'b0;
            
            write_data_payloads[data_index] = '{
                test_count: addr_payload.test_count,
                data: masked_data,
                strb: strobe_pattern,
                last: last_flag,
                valid: 1'b1,
                phase: addr_payload.phase
            };
            data_index++;
        end
    end
endfunction

// Function: generate_write_data_payloads_with_stall
function automatic void generate_write_data_payloads_with_stall();
    int stall_index = 0;
    int i;
    int total_weight;
    int selected_index;
    int stall_cycles;
    
    foreach (write_data_payloads[i]) begin
        write_data_payload_t payload = write_data_payloads[i];
        
        // Copy payload
        write_data_payloads_with_stall[stall_index] = payload;
        stall_index++;
        
        // Insert stall based on weights
        total_weight = calculate_total_weight_generic(write_data_bubble_weights, write_data_bubble_weights.size());
        selected_index = generate_weighted_random_index_generic(write_data_bubble_weights, total_weight);
        stall_cycles = write_data_bubble_weights[selected_index].cycles;
        
        // Insert stall cycles
        for (int stall = 0; stall < stall_cycles; stall++) begin
            write_data_payloads_with_stall[stall_index] = '{
                test_count: payload.test_count,
                data: '0,        // Clear data to 0 when valid=0
                strb: '0,        // Clear strobe to 0 when valid=0
                last: 1'b0,      // Clear last to 0 when valid=0
                valid: 1'b0,
                phase: payload.phase
            };
            stall_index++;
        end
    end
endfunction

// Function: generate_read_addr_payloads
function automatic void generate_read_addr_payloads();
    int i;
    foreach (write_addr_payloads[i]) begin
        read_addr_payloads[i] = '{
            test_count: write_addr_payloads[i].test_count,
            addr: write_addr_payloads[i].addr,
            burst: write_addr_payloads[i].burst,
            size: write_addr_payloads[i].size,
            id: write_addr_payloads[i].id,
            len: write_addr_payloads[i].len,
            valid: 1'b1,
            phase: write_addr_payloads[i].phase
        };
    end
endfunction

// Function: generate_read_addr_payloads_with_stall
function automatic void generate_read_addr_payloads_with_stall();
    int stall_index = 0;
    int i;
    int total_weight;
    int selected_index;
    int stall_cycles;
    
    foreach (read_addr_payloads[i]) begin
        read_addr_payload_t payload = read_addr_payloads[i];
        
        // Copy payload
        read_addr_payloads_with_stall[stall_index] = payload;
        stall_index++;
        
        // Insert stall based on weights
        total_weight = calculate_total_weight_generic(read_addr_bubble_weights, read_addr_bubble_weights.size());
        selected_index = generate_weighted_random_index_generic(read_addr_bubble_weights, total_weight);
        stall_cycles = read_addr_bubble_weights[selected_index].cycles;
        
        // Insert stall cycles
        for (int stall = 0; stall < stall_cycles; stall++) begin
            read_addr_payloads_with_stall[stall_index] = '{
                test_count: payload.test_count,
                addr: '0,        // Clear address to 0 when valid=0
                burst: '0,       // Clear burst to 0 when valid=0
                size: '0,        // Clear size to 0 when valid=0
                id: '0,          // Clear ID to 0 when valid=0
                len: '0,         // Clear length to 0 when valid=0
                valid: 1'b0,
                phase: payload.phase
            };
            stall_index++;
        end
    end
endfunction

`endif // AXI_STIMULUS_FUNCTIONS_SVH
