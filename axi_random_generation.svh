// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// axi_random_generation.svh
// Auto-generated from axi_simple_dual_port_ram_tb.sv
// DO NOT MODIFY - This file is auto-generated

`ifndef AXI_RANDOM_GENERATION_SVH
`define AXI_RANDOM_GENERATION_SVH

// Include common definitions
`include "axi_common_defs.svh"

// Function: calculate_total_weight_generic
// Extracted from original testbench

function automatic int calculate_total_weight_generic(
    input bubble_param_t weight_field[],
    input int array_size
);
    int total = 0;
    for (int i = 0; i < array_size; i++) begin
        total += weight_field[i].weight;
    end
    return total;
endfunction

// Function: generate_weighted_random_index_generic
// Extracted from original testbench

function automatic int generate_weighted_random_index_generic(
    input bubble_param_t weight_field[],
    input int total_weight
);
    int random_val;
    int cumulative_weight = 0;
    
    random_val = $urandom_range(0, total_weight - 1);
    
    for (int i = 0; i < weight_field.size(); i++) begin
        cumulative_weight += weight_field[i].weight;
        if (random_val < cumulative_weight) begin
            return i;
        end
    end
    
    return 0;
endfunction

// Function: generate_weighted_random_index_burst_config
// Extracted from original testbench

function automatic int generate_weighted_random_index_burst_config(
    input burst_config_t weight_field[],
    input int total_weight
);
    int random_val;
    int cumulative_weight = 0;
    
    random_val = $urandom_range(0, total_weight - 1);
    
    for (int i = 0; i < weight_field.size(); i++) begin
        cumulative_weight += weight_field[i].weight;
        if (random_val < cumulative_weight) begin
            return i;
        end
    end
    
    return 0;
endfunction

// Function: generate_weighted_random_index
// Extracted from original testbench

function automatic int generate_weighted_random_index(
    input int weights[],
    input int total_weight
);
    int random_val;
    int cumulative_weight = 0;
    
    random_val = $urandom_range(0, total_weight - 1);
    
    for (int i = 0; i < weights.size(); i++) begin
        cumulative_weight += weights[i];
        if (random_val < cumulative_weight) begin
            return i;
        end
    end
    
    return 0;
endfunction

// Function: calculate_total_weight
// Extracted from original testbench

function automatic int calculate_total_weight(input int weights[]);
    int total = 0;
    int i;
    foreach (weights[i]) begin
        total += weights[i];
    end
    return total;
endfunction

`endif // AXI_RANDOM_GENERATION_SVH
