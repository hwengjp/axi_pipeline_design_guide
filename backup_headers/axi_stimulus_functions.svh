// AXI4 Stimulus Generation Functions Header File
// This file contains functions for generating test stimulus

`ifndef AXI_STIMULUS_FUNCTIONS_SVH
`define AXI_STIMULUS_FUNCTIONS_SVH

// Include common definitions and functions
`include "axi_common_defs.svh"
`include "axi_utility_functions.svh"
`include "axi_random_generation.svh"

// Stimulus generation functions
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
        
        // Generate random SIZE (0=1byte, 1=2bytes, 2=4bytes for 32-bit bus)
        selected_size = $urandom_range(0, $clog2(AXI_DATA_WIDTH / 8));
        
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

function automatic void generate_write_addr_payloads_with_stall();
    int stall_index = 0;
    int i;
    int total_weight;
    int selected_index;
    int stall_cycles;
    
    foreach (write_addr_payloads[i]) begin
        write_addr_payload_t payload = write_addr_payloads[i];
        
        // Copy original payload to stall array
        write_addr_payloads_with_stall[stall_index] = payload;
        stall_index++;
        
        // Generate stall cycles using weighted random selection
        total_weight = calculate_total_weight_generic(write_addr_bubble_weights, write_addr_bubble_weights.size());
        selected_index = generate_weighted_random_index_generic(write_addr_bubble_weights, total_weight);
        stall_cycles = write_addr_bubble_weights[selected_index].cycles;
        
        // Insert stall cycles with cleared signals
        for (int stall = 0; stall < stall_cycles; stall++) begin
            write_addr_payloads_with_stall[stall_index] = '{
                test_count: payload.test_count,
                addr: '0,        // Clear address when valid=0
                burst: '0,       // Clear burst type when valid=0
                size: '0,        // Clear transfer size when valid=0
                id: '0,          // Clear transaction ID when valid=0
                len: '0,         // Clear burst length when valid=0
                valid: 1'b0,     // Clear valid flag
                phase: payload.phase
            };
            stall_index++;
        end
    end
    
    $display("Generated %0d Write Address Payloads with Stall", stall_index);
endfunction

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
        
        // Generate data payloads for each transfer in the burst
        for (int transfer = 0; transfer < burst_length; transfer++) begin
            // Generate random data for this transfer
            random_data = $urandom();
            
            // Generate strobe pattern based on address, size, and burst type
            // Random STROBE only for FIXED single access, all-ones for others
            if (get_burst_type_string(addr_payload.burst) == "FIXED" && addr_payload.len == 0) begin
                // FIXED single access: generate random STROBE pattern
                strobe_pattern = generate_strobe_pattern(
                    addr_payload.addr, 
                    addr_payload.size, 
                    get_burst_type_string(addr_payload.burst)
                );
            end else begin
                // INCR/WRAP or FIXED burst: use all-ones STROBE pattern
                strobe_pattern = '1;  // All bits set to 1
            end
            
            // Create strobe mask for proper data masking
            strobe_mask = 0;
            
            for (byte_idx = 0; byte_idx < AXI_STRB_WIDTH; byte_idx++) begin
                if (strobe_pattern[byte_idx]) begin
                    strobe_mask[byte_idx*8 +: 8] = 8'hFF;
                end
            end
            
            masked_data = random_data & strobe_mask;
            
            // Set last flag for the final transfer in the burst
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
    
    $display("Generated %0d Write Data Payloads (should match total burst transfers)", data_index);
endfunction

function automatic void generate_write_data_payloads_with_stall();
    int data_index = 0;
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
        
        // Generate data payloads for each transfer in the burst
        for (int transfer = 0; transfer < burst_length; transfer++) begin
            // Generate random data for this transfer
            random_data = $urandom();
            
            // Generate strobe pattern based on address, size, and burst type
            // Random STROBE only for FIXED single access, all-ones for others
            if (get_burst_type_string(addr_payload.burst) == "FIXED" && addr_payload.len == 0) begin
                // FIXED single access: generate random STROBE pattern
                strobe_pattern = generate_strobe_pattern(
                    addr_payload.addr, 
                    addr_payload.size, 
                    get_burst_type_string(addr_payload.burst)
                );
            end else begin
                // INCR/WRAP or FIXED burst: use all-ones STROBE pattern
                strobe_pattern = '1;  // All bits set to 1
            end
            
            // Create strobe mask for proper data masking
            strobe_mask = 0;
            
            for (byte_idx = 0; byte_idx < AXI_STRB_WIDTH; byte_idx++) begin
                if (strobe_pattern[byte_idx]) begin
                    strobe_mask[byte_idx*8 +: 8] = 8'hFF;
                end
            end
            
            masked_data = random_data & strobe_mask;
            
            // Set last flag for the final transfer in the burst
            last_flag = (transfer == burst_length - 1) ? 1'b1 : 1'b0;
            
            write_data_payloads_with_stall[data_index] = '{
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
    
    $display("Generated %0d Write Data Payloads with Stall", data_index);
endfunction

function automatic void generate_read_addr_payloads();
    foreach (write_addr_payloads[i]) begin
        read_addr_payloads[i] = '{
            test_count: write_addr_payloads[i].test_count,
            addr: write_addr_payloads[i].addr,      // Same address as write
            burst: write_addr_payloads[i].burst,    // Same burst type
            size: write_addr_payloads[i].size,      // Same transfer size
            id: write_addr_payloads[i].id,          // Same transaction ID
            len: write_addr_payloads[i].len,        // Same burst length
            valid: 1'b1,
            phase: write_addr_payloads[i].phase
        };
    end
endfunction

function automatic void generate_read_addr_payloads_with_stall();
    int stall_index = 0;
    int i;
    int total_weight;
    int selected_index;
    int stall_cycles;
    
    foreach (read_addr_payloads[i]) begin
        read_addr_payload_t payload = read_addr_payloads[i];
        
        // Copy original payload to stall array
        read_addr_payloads_with_stall[stall_index] = payload;
        stall_index++;
        
        // Generate stall cycles using weighted random selection
        total_weight = calculate_total_weight_generic(read_addr_bubble_weights, read_addr_bubble_weights.size());
        selected_index = generate_weighted_random_index_generic(read_addr_bubble_weights, total_weight);
        stall_cycles = read_addr_bubble_weights[selected_index].cycles;
        
        // Insert stall cycles with cleared signals
        for (int stall = 0; stall < stall_cycles; stall++) begin
            read_addr_payloads_with_stall[stall_index] = '{
                test_count: payload.test_count,
                addr: '0,        // Clear address when valid=0
                burst: '0,       // Clear burst type when valid=0
                size: '0,        // Clear transfer size when valid=0
                id: '0,          // Clear transaction ID when valid=0
                len: '0,         // Clear burst length when valid=0
                valid: 1'b0,     // Clear valid flag
                phase: payload.phase
            };
            stall_index++;
        end
    end
    
    $display("Generated %0d Read Address Payloads with Stall", stall_index);
endfunction

`endif // AXI_STIMULUS_FUNCTIONS_SVH
