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
        
        // Generate SIZE based on size_strategy
        selected_size = generate_size_by_strategy(burst_cfg.size_strategy, AXI_DATA_WIDTH);
        
        // Constraint check: SIZE must not exceed bus width
        if (size_to_bytes(selected_size) > AXI_DATA_WIDTH / 8) begin
            $error("SIZE constraint violation: SIZE %0d exceeds bus width %0d bytes", 
                   size_to_bytes(selected_size), AXI_DATA_WIDTH / 8);
            $finish;
        end
        
        // WRAP burst constraint check: burst length must be 2, 4, 8, or 16
        if (selected_type == "WRAP") begin
            if (!((selected_length + 1) inside {2, 4, 8, 16})) begin
                $error("WRAP burst constraint violation: burst length %0d must be 2, 4, 8, or 16", selected_length + 1);
                $finish;
            end
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
        
        // WRAP burst address alignment check: start address must be aligned to transfer size
        if (selected_type == "WRAP") begin
            int size_bytes = size_to_bytes(selected_size);
            if (base_addr % size_bytes != 0) begin
                $error("WRAP burst address alignment violation: start address 0x%x not aligned to transfer size %0d bytes", base_addr, size_bytes);
                $finish;
            end
        end
        
        write_addr_payloads[test_count] = '{
            test_count: test_count,
            addr: base_addr,
            burst: get_burst_type_value(selected_type),
            size: selected_size,
            id: $urandom_range(0, (1 << AXI_ID_WIDTH) - 1),
            len: selected_length,
            valid: 1'b1,
            phase: phase,
            size_strategy: burst_cfg.size_strategy
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
                phase: payload.phase,
                size_strategy: payload.size_strategy
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
            // Use strobe strategy from burst configuration
            if (get_burst_type_string(addr_payload.burst) == "FIXED" && addr_payload.len == 0) begin
                // FIXED single access: Generate random STROBE (existing logic)
                strobe_pattern = generate_strobe_pattern(
                    addr_payload.addr, 
                    addr_payload.size, 
                    AXI_DATA_WIDTH,
                    get_burst_type_string(addr_payload.burst)
                );
            end else begin
                // INCR/WRAP or FIXED burst: Use configured strobe strategy
                // 新しいsize_strategyベースのSTROBE生成（バースト内ビート位置考慮）
                strobe_pattern = generate_strobe_by_size_strategy(addr_payload.addr, addr_payload.size, addr_payload.size_strategy, AXI_DATA_WIDTH, transfer);
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
            phase: write_addr_payloads[i].phase,
            size_strategy: write_addr_payloads[i].size_strategy
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
                phase: payload.phase,
                size_strategy: payload.size_strategy
            };
            stall_index++;
        end
    end
endfunction

// =============================================================================
// Byte Verification Stimulus Generation Functions
// =============================================================================

// Function: generate_byte_verification_arrays
// Generates byte-level verification arrays based on written data
function automatic void generate_byte_verification_arrays();
    int byte_index = 0;
    int test_count;
    int total_bytes;
    int bytes_per_transfer;
    int byte_offset;
    int transfer_index;
    int byte_in_transfer;
    logic [AXI_ADDR_WIDTH-1:0] base_addr;
    logic [AXI_DATA_WIDTH-1:0] write_data;
    logic [AXI_STRB_WIDTH-1:0] strb;
    logic [7:0] burst_len;
    logic [2:0] transfer_size;
    logic [AXI_ADDR_WIDTH-1:0] byte_addr;
    logic [7:0] expected_byte;
    int write_data_index;
    
    write_debug_log("Starting byte verification array generation...");
    
    // Debug: Show write_data_payloads contents
    write_debug_log($sformatf("DEBUG: write_data_payloads.size() = %0d", write_data_payloads.size()));
    foreach (write_data_payloads[i]) begin
        write_debug_log($sformatf("DEBUG: write_data_payloads[%0d]: data=0x%x, strb=0x%x, test_count=%0d", 
                                i, write_data_payloads[i].data, write_data_payloads[i].strb, write_data_payloads[i].test_count));
    end
    
    // Clear existing arrays
    byte_verification_read_addr_payloads.delete();
    byte_verification_expected.delete();
    
    // Generate byte verification arrays for each test case
    foreach (write_addr_payloads[test_count]) begin
        if (write_data_payloads.exists(test_count)) begin
            // Get the write address and data for this test
            base_addr = write_addr_payloads[test_count].addr;
            burst_len = write_addr_payloads[test_count].len;
            transfer_size = write_addr_payloads[test_count].size;
            
            // Calculate number of bytes to verify based on actual data width
            bytes_per_transfer = AXI_DATA_WIDTH / 8;  // 32/8 = 4 bytes per transfer
            total_bytes = (burst_len + 1) * bytes_per_transfer;
            
            write_debug_log($sformatf("Test %0d: base_addr=0x%x, burst_len=%0d, transfer_size=%0d, total_bytes=%0d, bytes_per_transfer=%0d", 
                                    test_count, base_addr, burst_len, transfer_size, total_bytes, bytes_per_transfer));
            
            // Generate byte verification for each transfer (not for each byte)
            // Process all transfers for this test case
            for (transfer_index = 0; transfer_index <= burst_len; transfer_index++) begin
                // Calculate the correct index for this transfer
                // Test 0: 0, 1, 2, ..., 10 (11 transfers)
                // Test 1: 11, 12, 13, 14, 15 (5 transfers)
                // Test 2: 16, 17, 18, 19, 20, 21 (6 transfers)
                // Test 3: 22, 23, 24, ..., 45 (24 transfers)
                int transfer_data_index;
                if (test_count == 0) begin
                    transfer_data_index = 0 + transfer_index;   // Test 0: 0, 1, 2, ..., 10
                end else if (test_count == 1) begin
                    transfer_data_index = 11 + transfer_index;  // Test 1: 11, 12, 13, 14, 15
                end else if (test_count == 2) begin
                    transfer_data_index = 16 + transfer_index;  // Test 2: 16, 17, 18, 19, 20, 21
                end else if (test_count == 3) begin
                    transfer_data_index = 22 + transfer_index;  // Test 3: 22, 23, 24, ..., 45
                end else begin
                    transfer_data_index = transfer_index;       // Fallback for other tests
                end
                
                if (write_data_payloads.exists(transfer_data_index)) begin
                    write_data = write_data_payloads[transfer_data_index].data;
                    strb = write_data_payloads[transfer_data_index].strb;
                    
                    write_debug_log($sformatf("  Test %0d Transfer %0d: data=0x%x, strb=0x%x (from index %0d)", 
                                            test_count, transfer_index, write_data, strb, transfer_data_index));
                    
                    // Debug: Show the actual payload data
                    write_debug_log($sformatf("    DEBUG: write_data_payloads[%0d].data = 0x%x", transfer_data_index, write_data_payloads[transfer_data_index].data));
                    write_debug_log($sformatf("    DEBUG: write_data_payloads[%0d].strb = 0x%x", transfer_data_index, write_data_payloads[transfer_data_index].strb));
                    
                    // Check each byte in this transfer
                    for (byte_in_transfer = 0; byte_in_transfer < bytes_per_transfer; byte_in_transfer++) begin
                        // Calculate correct byte address for this specific byte
                        byte_addr = base_addr + transfer_index * bytes_per_transfer + byte_in_transfer;
                        
                        // Debug: Show STROBE bit check details
                        write_debug_log($sformatf("    Checking byte_in_transfer=%0d, strb[%0d]=%b, strb=0x%x", 
                                                byte_in_transfer, byte_in_transfer, strb[byte_in_transfer], strb));
                        
                        // Check if this byte is enabled by strobe
                        if (strb[byte_in_transfer]) begin
                            // Extract expected byte value from write data
                            if (byte_in_transfer * 8 + 8 <= AXI_DATA_WIDTH) begin
                                expected_byte = write_data[(byte_in_transfer * 8) +: 8];
                                
                                write_debug_log($sformatf("    Byte %0d: addr=0x%x, byte_in_transfer=%0d, expected_byte=0x%02x (STROBE_ENABLED) - ADDING TO ARRAY", 
                                                        transfer_index * bytes_per_transfer + byte_in_transfer, byte_addr, byte_in_transfer, expected_byte));
                                
                                // Create byte verification read address payload
                                byte_verification_read_addr_payloads[byte_index] = '{
                                    test_count: test_count,
                                    addr: byte_addr,
                                    size: 3'b000,                    // Always 1 byte transfer
                                    id: write_addr_payloads[test_count].id,
                                    len: 8'h00,                      // Always single transfer
                                    valid: 1'b1,
                                    phase: 0                         // Byte verification phase
                                };
                                
                                // Create byte verification expected value
                                byte_verification_expected[byte_index] = '{
                                    test_count: test_count,
                                    expected_byte: expected_byte,
                                    byte_addr: byte_addr,
                                    phase: 0                         // Byte verification phase
                                };
                                
                                write_debug_log($sformatf("      Added to array at index %0d", byte_index));
                                byte_index++;
                            end else begin
                                write_debug_log($sformatf("    Warning: byte_in_transfer=%0d exceeds bus width", byte_in_transfer));
                            end
                        end else begin
                            // This byte is not enabled by strobe - skip verification
                            write_debug_log($sformatf("    Byte %0d: addr=0x%x, byte_in_transfer=%0d, STROBE_DISABLED (not adding to array)", 
                                                    transfer_index * bytes_per_transfer + byte_in_transfer, byte_addr, byte_in_transfer));
                        end
                    end
                end else begin
                    // Transfer data not found
                    write_debug_log($sformatf("Warning: transfer data not found for test_count=%0d, transfer_index=%0d, transfer_data_index=%0d", 
                                            test_count, transfer_index, transfer_data_index));
                end
            end
        end
    end
    
    write_debug_log($sformatf("Generated %0d byte verification entries", byte_index));
endfunction



`endif // AXI_STIMULUS_FUNCTIONS_SVH
