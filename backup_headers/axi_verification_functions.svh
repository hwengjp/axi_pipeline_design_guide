// AXI4 Verification and Expected Value Generation Functions Header File
// This file contains functions for verification and expected value generation

`ifndef AXI_VERIFICATION_FUNCTIONS_SVH
`define AXI_VERIFICATION_FUNCTIONS_SVH

// Include common definitions and functions
`include "axi_common_defs.svh"
`include "axi_utility_functions.svh"

// Verification and expected value generation functions
function automatic void generate_read_data_expected();
    int expected_index = 0;
    write_addr_payload_t addr_payload;
    write_data_payload_t data_payload;
    logic [AXI_DATA_WIDTH-1:0] expected_data;
    logic [AXI_STRB_WIDTH-1:0] expected_strobe;
    int burst_length;
    
    foreach (write_addr_payloads[i]) begin
        addr_payload = write_addr_payloads[i];
        burst_length = addr_payload.len + 1; // len=0 means 1 transfer, len=2 means 3 transfers
        
        // Generate expected values for each transfer in the burst
        for (int transfer = 0; transfer < burst_length; transfer++) begin
            // Find corresponding write data payload
            data_payload = write_data_payloads[expected_index];
            
            // Expected data should match the written data
            expected_data = data_payload.data;
            
            // Expected strobe should match the written strobe
            expected_strobe = data_payload.strb;
            
            read_data_expected[expected_index] = '{
                test_count: addr_payload.test_count,
                expected_data: expected_data,
                expected_strobe: expected_strobe,
                phase: addr_payload.phase
            };
            
            expected_index++;
        end
    end
    
    $display("Generated %0d Read Data Expected Values", expected_index);
endfunction

function automatic void generate_write_resp_expected();
    foreach (write_addr_payloads[i]) begin
        write_resp_expected[i] = '{
            test_count: write_addr_payloads[i].test_count,
            expected_resp: 2'b00,  // OKAY response
            expected_id: write_addr_payloads[i].id,
            phase: write_addr_payloads[i].phase
        };
    end
    
    $display("Generated %0d Write Response Expected Values", write_addr_payloads.size());
endfunction

function automatic void initialize_ready_negate_pulses();
    int pulse_index = 0;
    int total_weight;
    int selected_index;
    int negate_cycles;
    
    // Initialize write address ready negate pulses
    foreach (write_addr_payloads_with_stall[i]) begin
        total_weight = calculate_total_weight_generic(axi_aw_ready_negate_weights, axi_aw_ready_negate_weights.size());
        selected_index = generate_weighted_random_index_generic(axi_aw_ready_negate_weights, total_weight);
        negate_cycles = axi_aw_ready_negate_weights[selected_index].cycles;
        
        axi_aw_ready_negate_pulses[pulse_index] = '{
            test_count: write_addr_payloads_with_stall[i].test_count,
            cycles: negate_cycles,
            phase: write_addr_payloads_with_stall[i].phase
        };
        pulse_index++;
    end
    
    // Initialize write data ready negate pulses
    foreach (write_data_payloads_with_stall[i]) begin
        total_weight = calculate_total_weight_generic(axi_w_ready_negate_weights, axi_w_ready_negate_weights.size());
        selected_index = generate_weighted_random_index_generic(axi_w_ready_negate_weights, total_weight);
        negate_cycles = axi_w_ready_negate_weights[selected_index].cycles;
        
        axi_w_ready_negate_pulses[pulse_index] = '{
            test_count: write_data_payloads_with_stall[i].test_count,
            cycles: negate_cycles,
            phase: write_data_payloads_with_stall[i].phase
        };
        pulse_index++;
    end
    
    // Initialize read address ready negate pulses
    foreach (read_addr_payloads_with_stall[i]) begin
        total_weight = calculate_total_weight_generic(axi_ar_ready_negate_weights, axi_ar_ready_negate_weights.size());
        selected_index = generate_weighted_random_index_generic(axi_ar_ready_negate_weights, total_weight);
        negate_cycles = axi_ar_ready_negate_weights[selected_index].cycles;
        
        axi_ar_ready_negate_pulses[pulse_index] = '{
            test_count: read_addr_payloads_with_stall[i].test_count,
            cycles: negate_cycles,
            phase: read_addr_payloads_with_stall[i].phase
        };
        pulse_index++;
    end
    
    $display("Initialized %0d Ready Negate Pulses", pulse_index);
endfunction

`endif // AXI_VERIFICATION_FUNCTIONS_SVH
