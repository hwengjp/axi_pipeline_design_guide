// axi_verification_functions.svh
// Auto-generated from axi_simple_dual_port_ram_tb.sv
// DO NOT MODIFY - This file is auto-generated

`ifndef AXI_VERIFICATION_FUNCTIONS_SVH
`define AXI_VERIFICATION_FUNCTIONS_SVH

// Include common definitions
`include "axi_common_defs.svh"

// Function: generate_read_data_expected
// Extracted from original testbench

function automatic void generate_read_data_expected();
    int i;
    foreach (write_data_payloads[i]) begin
        read_data_expected[i] = '{
            test_count: write_data_payloads[i].test_count,
            expected_data: write_data_payloads[i].data,
            expected_strobe: write_data_payloads[i].strb,  // ストローブ情報をコピー
            phase: write_data_payloads[i].phase
        };
    end
endfunction

// Function: generate_write_resp_expected
// Extracted from original testbench

function automatic void generate_write_resp_expected();
    int i;
    foreach (write_addr_payloads[i]) begin
        write_resp_expected[i] = '{
            test_count: write_addr_payloads[i].test_count,
            expected_resp: 2'b00, // Always OKAY
            expected_id: write_addr_payloads[i].id,
            phase: write_addr_payloads[i].phase
        };
    end
endfunction

// Function: initialize_ready_negate_pulses
// Extracted from original testbench

function automatic void initialize_ready_negate_pulses();
    int i;
    int total_weight;
    int selected_index;
    int negate_cycles;
    
    for (i = 0; i < READY_NEGATE_ARRAY_LENGTH; i = i + 1) begin
        // Generate R ready negate pulses using weighted random
        total_weight = calculate_total_weight_generic(axi_r_ready_negate_weights, axi_r_ready_negate_weights.size());
        selected_index = generate_weighted_random_index_generic(axi_r_ready_negate_weights, total_weight);
        negate_cycles = axi_r_ready_negate_weights[selected_index].cycles;
        axi_r_ready_negate_pulses[i] = (negate_cycles > 0) ? 1'b1 : 1'b0;
        
        // Generate B ready negate pulses using weighted random
        total_weight = calculate_total_weight_generic(axi_b_ready_negate_weights, axi_b_ready_negate_weights.size());
        selected_index = generate_weighted_random_index_generic(axi_b_ready_negate_weights, total_weight);
        negate_cycles = axi_b_ready_negate_weights[selected_index].cycles;
        axi_b_ready_negate_pulses[i] = (negate_cycles > 0) ? 1'b1 : 1'b0;
    end
endfunction

`endif // AXI_VERIFICATION_FUNCTIONS_SVH
