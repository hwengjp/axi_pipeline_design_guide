// AXI4 Random Generation Functions Header File
// This file contains weighted random generation functions for the testbench

`ifndef AXI_RANDOM_GENERATION_SVH
`define AXI_RANDOM_GENERATION_SVH

// Include common definitions
`include "axi_common_defs.svh"

// Random generation functions
function automatic int calculate_total_weight_generic(
    input bubble_param_t weights[],
    input int array_size
);
    int total = 0;
    for (int i = 0; i < array_size; i++) begin
        total += weights[i].weight;
    end
    return total;
endfunction

function automatic int generate_weighted_random_index_generic(
    input bubble_param_t weights[],
    input int total_weight
);
    int random_value;
    int cumulative_weight = 0;
    
    // Generate random value between 0 and total_weight-1
    random_value = $urandom_range(total_weight - 1);
    
    // Find corresponding index based on cumulative weights
    for (int i = 0; i < weights.size(); i++) begin
        cumulative_weight += weights[i].weight;
        if (random_value < cumulative_weight) begin
            return i;
        end
    end
    
    // Fallback to last index if something goes wrong
    return weights.size() - 1;
endfunction

function automatic int generate_weighted_random_index_burst_config(
    input burst_config_t burst_configs[],
    input int total_weight
);
    int random_value;
    int cumulative_weight = 0;
    
    // Generate random value between 0 and total_weight-1
    random_value = $urandom_range(total_weight - 1);
    
    // Find corresponding index based on cumulative weights
    for (int i = 0; i < burst_configs.size(); i++) begin
        cumulative_weight += burst_configs[i].weight;
        if (random_value < cumulative_weight) begin
            return i;
        end
    end
    
    // Fallback to last index if something goes wrong
    return burst_configs.size() - 1;
endfunction

function automatic int generate_weighted_random_index(
    input int weights[],
    input int total_weight
);
    int random_value;
    int cumulative_weight = 0;
    
    // Generate random value between 0 and total_weight-1
    random_value = $urandom_range(total_weight - 1);
    
    // Find corresponding index based on cumulative weights
    for (int i = 0; i < weights.size(); i++) begin
        cumulative_weight += weights[i];
        if (random_value < cumulative_weight) begin
            return i;
        end
    end
    
    // Fallback to last index if something goes wrong
    return weights.size() - 1;
endfunction

function automatic int calculate_total_weight(input int weights[]);
    int total = 0;
    for (int i = 0; i < weights.size(); i++) begin
        total += weights[i];
    end
    return total;
endfunction

`endif // AXI_RANDOM_GENERATION_SVH
