// AXI4 Simple Dual Port RAM Testbench
// Generated from part08_axi4_bus_testbench_abstraction.md
// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.

`timescale 1ns/1ps

module axi_simple_dual_port_ram_tb;

// Clock and Reset
reg clk;
reg rst_n;

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz clock
end

// Reset generation
initial begin
    rst_n = 0;
    repeat(10) @(posedge clk);
    #1;
    rst_n = 1;
end

// Testbench parameters
parameter MEMORY_SIZE_BYTES = 33554432;     // 32MB
parameter AXI_DATA_WIDTH = 32;              // 32bit
parameter AXI_ID_WIDTH = 8;                 // 8bit ID
parameter TOTAL_TEST_COUNT = 1000;          // Total test count
parameter PHASE_TEST_COUNT = 100;           // Tests per phase
parameter TEST_COUNT_ADDR_SIZE_BYTES = 4096; // Address size per test count
parameter CLK_PERIOD = 10;                  // 10ns period
parameter CLK_HALF_PERIOD = 5;             // 5ns half period
parameter RESET_CYCLES = 10;                // Reset cycles

// Derived parameters
parameter AXI_ADDR_WIDTH = $clog2(MEMORY_SIZE_BYTES);
parameter AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;

// AXI4 Write Address Channel
logic [AXI_ADDR_WIDTH-1:0] axi_aw_addr;
logic [1:0]                axi_aw_burst;
logic [2:0]                axi_aw_size;
logic [AXI_ID_WIDTH-1:0]   axi_aw_id;
logic [7:0]                axi_aw_len;
logic                      axi_aw_valid;
logic                      axi_aw_ready;

// AXI4 Write Data Channel
logic [AXI_DATA_WIDTH-1:0] axi_w_data;
logic [AXI_STRB_WIDTH-1:0] axi_w_strb;
logic                       axi_w_last;
logic                       axi_w_valid;
logic                       axi_w_ready;

// AXI4 Write Response Channel
logic [1:0]                axi_b_resp;
logic [AXI_ID_WIDTH-1:0]   axi_b_id;
logic                      axi_b_valid;
logic                      axi_b_ready;

// AXI4 Read Address Channel
logic [AXI_ADDR_WIDTH-1:0] axi_ar_addr;
logic [1:0]                axi_ar_burst;
logic [2:0]                axi_ar_size;
logic [AXI_ID_WIDTH-1:0]   axi_ar_id;
logic [7:0]                axi_ar_len;
logic                      axi_ar_valid;
logic                      axi_ar_ready;

// AXI4 Read Data Channel
logic [AXI_DATA_WIDTH-1:0] axi_r_data;
logic [AXI_ID_WIDTH-1:0]   axi_r_id;
logic [1:0]                axi_r_resp;
logic                       axi_r_last;
logic                      axi_r_valid;
logic                      axi_r_ready;

// Test data generation completion flag
logic generate_stimulus_expected_done = 1'b0;

// Test execution completion flag
logic test_execution_completed = 1'b0;

// Ready negate control parameters
parameter READY_NEGATE_ARRAY_LENGTH = 1000;  // Length of ready negate pulse array

// Ready negate pulse arrays for each channel
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_aw_ready_negate_pulses;
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_w_ready_negate_pulses;
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_b_ready_negate_pulses;

// Ready negate array index counter
logic [$clog2(READY_NEGATE_ARRAY_LENGTH):0] ready_negate_index = 0;


// Weighted random generation structures
typedef struct {
    int weight;
    int length_min;
    int length_max;
    string burst_type;
} burst_config_t;

typedef struct {
    int weight;
    int cycles;
} bubble_param_t;

// Weighted random generation arrays
burst_config_t burst_config_weights[] = '{
    '{weight: 40, length_min: 0, length_max: 3, burst_type: "INCR"},
    '{weight: 30, length_min: 4, length_max: 7, burst_type: "INCR"},
    '{weight: 20, length_min: 8, length_max: 15, burst_type: "INCR"},
    '{weight: 10, length_min: 0, length_max: 3, burst_type: "WRAP"}
};

bubble_param_t write_addr_bubble_weights[] = '{
    '{weight: 70, cycles: 0},
    '{weight: 20, cycles: 1},
    '{weight: 10, cycles: 2}
};

bubble_param_t write_data_bubble_weights[] = '{
    '{weight: 80, cycles: 0},
    '{weight: 15, cycles: 1},
    '{weight: 5, cycles: 2}
};

bubble_param_t read_addr_bubble_weights[] = '{
    '{weight: 75, cycles: 0},
    '{weight: 20, cycles: 1},
    '{weight: 5, cycles: 2}
};

// Ready negate weights for each channel
bubble_param_t axi_aw_ready_negate_weights[] = '{
    '{weight: 80, cycles: 0},  // 80% probability: no negate
    '{weight: 5, cycles: 1},  // 15% probability: negate for 1 cycle
    '{weight: 5, cycles: 2}    // 5% probability: negate for 2 cycles
};

bubble_param_t axi_w_ready_negate_weights[] = '{
    '{weight: 80, cycles: 0},  // 85% probability: no negate
    '{weight: 5, cycles: 1},  // 12% probability: negate for 1 cycle
    '{weight: 5, cycles: 2}    // 3% probability: negate for 2 cycles
};

bubble_param_t axi_b_ready_negate_weights[] = '{
    '{weight: 80, cycles: 0},  // 90% probability: no negate
    '{weight: 5, cycles: 1},   // 8% probability: negate for 1 cycle
    '{weight: 5, cycles: 2}    // 2% probability: negate for 2 cycles
};

// Payload structures
typedef struct {
    int                         test_count;
    logic [AXI_ADDR_WIDTH-1:0] addr;
    logic [1:0]                burst;
    logic [2:0]                size;
    logic [AXI_ID_WIDTH-1:0]   id;
    logic [7:0]                len;
    logic                      valid;
    int                         phase;
} write_addr_payload_t;

typedef struct {
    int                         test_count;
    logic [AXI_DATA_WIDTH-1:0] data;
    logic [AXI_STRB_WIDTH-1:0] strb;
    logic                       last;
    logic                       valid;
    int                         phase;
} write_data_payload_t;

typedef struct {
    int                         test_count;
    logic [AXI_ADDR_WIDTH-1:0] addr;
    logic [1:0]                burst;
    logic [2:0]                size;
    logic [AXI_ID_WIDTH-1:0]   id;
    logic [7:0]                len;
    logic                      valid;
    int                         phase;
} read_addr_payload_t;

// Payload arrays
write_addr_payload_t write_addr_payloads[int];
write_addr_payload_t write_addr_payloads_with_stall[int];
write_data_payload_t write_data_payloads[int];
write_data_payload_t write_data_payloads_with_stall[int];
read_addr_payload_t read_addr_payloads[int];
read_addr_payload_t read_addr_payloads_with_stall[int];

// Expected value structures
typedef struct {
    int                         test_count;
    logic [AXI_DATA_WIDTH-1:0] expected_data;
    int                         phase;
} read_data_expected_t;

typedef struct {
    int                         test_count;
    logic [1:0]                expected_resp;
    logic [AXI_ID_WIDTH-1:0]   expected_id;
    int                         phase;
} write_resp_expected_t;

// Expected value arrays
read_data_expected_t read_data_expected[int];
write_resp_expected_t write_resp_expected[int];

// Phase control signals
logic [7:0] current_phase = 8'd0;
logic write_addr_phase_start = 1'b0;
logic read_addr_phase_start = 1'b0;
logic write_data_phase_start = 1'b0;
logic read_data_phase_start = 1'b0;
logic clear_phase_latches = 1'b0;  // Clear signal for phase completion latches

// Phase completion signals
logic write_addr_phase_done = 1'b0;
logic read_addr_phase_done = 1'b0;
logic write_data_phase_done = 1'b0;
logic read_data_phase_done = 1'b0;

// Phase completion signal latches
logic write_addr_phase_done_latched = 1'b0;
logic read_addr_phase_done_latched = 1'b0;
logic write_data_phase_done_latched = 1'b0;
logic read_data_phase_done_latched = 1'b0;

// Log control parameters
parameter LOG_ENABLE = 1'b1;
parameter DEBUG_LOG_ENABLE = 1'b1;

// Test data generation functions
function automatic void generate_write_addr_payloads();
    int test_count = 0;
    int i;
    int selected_length;
    string selected_type;
    int phase;
    logic [AXI_ADDR_WIDTH-1:0] random_offset;
    int burst_size_bytes;
    logic [AXI_ADDR_WIDTH-1:0] aligned_offset;
    logic [AXI_ADDR_WIDTH-1:0] base_addr;
    
    foreach (burst_config_weights[i]) begin
        burst_config_t burst_cfg = burst_config_weights[i];
        
        for (int weight_count = 0; weight_count < burst_cfg.weight; weight_count++) begin
            selected_length = $urandom_range(burst_cfg.length_min, burst_cfg.length_max);
            selected_type = burst_cfg.burst_type;
            
            phase = test_count / PHASE_TEST_COUNT;
            
            // Generate random offset within TEST_COUNT_ADDR_SIZE_BYTES/4
            random_offset = $urandom_range(0, TEST_COUNT_ADDR_SIZE_BYTES / 4 - 1);
            
            // Align to address boundary
            burst_size_bytes = (selected_length + 1) * (AXI_DATA_WIDTH / 8);
            aligned_offset = align_address_to_boundary(random_offset, burst_size_bytes, selected_type);
            
            // Add phase offset
            base_addr = aligned_offset + (phase * TEST_COUNT_ADDR_SIZE_BYTES);
            
            write_addr_payloads[test_count] = '{
                test_count: test_count,
                addr: base_addr,
                burst: get_burst_type_value(selected_type),
                size: $clog2(AXI_DATA_WIDTH / 8),
                id: $urandom_range(0, (1 << AXI_ID_WIDTH) - 1),
                len: selected_length,
                valid: 1'b1,
                phase: phase
            };
            
            test_count++;
        end
    end
endfunction

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
                addr: payload.addr,
                burst: payload.burst,
                size: payload.size,
                id: payload.id,
                len: payload.len,
                valid: 1'b0,
                phase: payload.phase
            };
            stall_index++;
        end
    end
endfunction

function automatic void generate_write_data_payloads();
    int i;
    write_addr_payload_t addr_payload;
    logic [AXI_DATA_WIDTH-1:0] random_data;
    logic [AXI_STRB_WIDTH-1:0] strobe_pattern;
    logic [AXI_DATA_WIDTH-1:0] strobe_mask;
    logic [AXI_DATA_WIDTH-1:0] masked_data;
    logic last_flag;
    int byte_idx;
    
    foreach (write_addr_payloads[i]) begin
        addr_payload = write_addr_payloads[i];
        
        // Generate random data
        random_data = $urandom();
        
        // Generate strobe pattern
        if (addr_payload.burst == 2'b00) begin // FIXED
            strobe_pattern = generate_fixed_strobe_pattern(
                addr_payload.addr, 
                addr_payload.size, 
                AXI_DATA_WIDTH
            );
        end else begin // INCR, WRAP
            strobe_pattern = {AXI_STRB_WIDTH{1'b1}};
        end
        
        // Create strobe mask for data masking
        strobe_mask = 0;
        
        for (byte_idx = 0; byte_idx < AXI_STRB_WIDTH; byte_idx++) begin
            if (strobe_pattern[byte_idx]) begin
                strobe_mask[byte_idx*8 +: 8] = 8'hFF;
            end
        end
        
        masked_data = random_data & strobe_mask;
        
        // Set last flag based on burst length
        last_flag = (i == write_addr_payloads.size() - 1) ? 1'b1 : 1'b0;
        
        write_data_payloads[i] = '{
            test_count: addr_payload.test_count,
            data: masked_data,
            strb: strobe_pattern,
            last: last_flag,
            valid: 1'b1,
            phase: addr_payload.phase
        };
    end
endfunction

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
                data: payload.data,
                strb: payload.strb,
                last: payload.last,
                valid: 1'b0,
                phase: payload.phase
            };
            stall_index++;
        end
    end
endfunction

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
                addr: payload.addr,
                burst: payload.burst,
                size: payload.size,
                id: payload.id,
                len: payload.len,
                valid: 1'b0,
                phase: payload.phase
            };
            stall_index++;
        end
    end
endfunction

function automatic void generate_read_data_expected();
    int i;
    foreach (write_data_payloads[i]) begin
        read_data_expected[i] = '{
            test_count: write_data_payloads[i].test_count,
            expected_data: write_data_payloads[i].data,
            phase: write_data_payloads[i].phase
        };
    end
endfunction

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

// (extract_weights_generic removed to avoid returning int[] which some tools reject)

// Direct bubble weight helper functions (avoid packed arrays)
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

// Helper functions
function automatic logic [1:0] get_burst_type_value(input string burst_type);
    case (burst_type)
        "FIXED": return 2'b00;
        "INCR":  return 2'b01;
        "WRAP":  return 2'b10;
        default: return 2'b01;
    endcase
endfunction

function automatic logic [AXI_ADDR_WIDTH-1:0] align_address_to_boundary(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input int burst_size_bytes,
    input string burst_type
);
    logic [AXI_ADDR_WIDTH-1:0] aligned_addr = address;
    case (burst_type)
        "WRAP": begin
            int wrap_boundary = burst_size_bytes;
            aligned_addr = (address / wrap_boundary) * wrap_boundary;
        end
        "INCR", "FIXED": begin
            int bus_width_bytes = AXI_DATA_WIDTH / 8;
            aligned_addr = (address / bus_width_bytes) * bus_width_bytes;
        end
        default: begin
            int bus_width_bytes = AXI_DATA_WIDTH / 8;
            aligned_addr = (address / bus_width_bytes) * bus_width_bytes;
        end
    endcase
    return aligned_addr;
endfunction

function automatic logic [AXI_STRB_WIDTH-1:0] generate_fixed_strobe_pattern(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input int data_width
);
    logic [AXI_STRB_WIDTH-1:0] strobe_pattern = 0;
    int bus_width_bytes = data_width / 8;
    int burst_size_bytes = (1 << size);
    
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

// Weighted random generation functions
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

function automatic int calculate_total_weight(input int weights[]);
    int total = 0;
    int i;
    foreach (weights[i]) begin
        total += weights[i];
    end
    return total;
endfunction

// Ready negate pulse array initialization function
function automatic void initialize_ready_negate_pulses();
    int i;
    int total_weight;
    int selected_index;
    int negate_cycles;
    
    for (i = 0; i < READY_NEGATE_ARRAY_LENGTH; i = i + 1) begin
        // Generate AW ready negate pulses using weighted random
        total_weight = calculate_total_weight_generic(axi_aw_ready_negate_weights, axi_aw_ready_negate_weights.size());
        selected_index = generate_weighted_random_index_generic(axi_aw_ready_negate_weights, total_weight);
        negate_cycles = axi_aw_ready_negate_weights[selected_index].cycles;
        axi_aw_ready_negate_pulses[i] = (negate_cycles > 0) ? 1'b1 : 1'b0;
        
        // Generate W ready negate pulses using weighted random
        total_weight = calculate_total_weight_generic(axi_w_ready_negate_weights, axi_w_ready_negate_weights.size());
        selected_index = generate_weighted_random_index_generic(axi_w_ready_negate_weights, total_weight);
        negate_cycles = axi_w_ready_negate_weights[selected_index].cycles;
        axi_w_ready_negate_pulses[i] = (negate_cycles > 0) ? 1'b1 : 1'b0;
        
        // Generate B ready negate pulses using weighted random
        total_weight = calculate_total_weight_generic(axi_b_ready_negate_weights, axi_b_ready_negate_weights.size());
        selected_index = generate_weighted_random_index_generic(axi_b_ready_negate_weights, total_weight);
        negate_cycles = axi_b_ready_negate_weights[selected_index].cycles;
        axi_b_ready_negate_pulses[i] = (negate_cycles > 0) ? 1'b1 : 1'b0;
    end
endfunction

// Log output functions
function automatic void write_log(input string message);
    if (LOG_ENABLE) begin
        $display("[%0t] %s", $time, message);
    end
endfunction

function automatic void write_debug_log(input string message);
    if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
        $display("[%0t] [DEBUG] %s", $time, message);
    end
endfunction

// DUT instantiation
axi_simple_dual_port_ram #(
    .MEMORY_SIZE_BYTES(MEMORY_SIZE_BYTES),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH)
) dut (
    .axi_clk(clk),
    .axi_resetn(rst_n),
    .axi_aw_addr(axi_aw_addr),
    .axi_aw_burst(axi_aw_burst),
    .axi_aw_size(axi_aw_size),
    .axi_aw_id(axi_aw_id),
    .axi_aw_len(axi_aw_len),
    .axi_aw_valid(axi_aw_valid),
    .axi_aw_ready(axi_aw_ready),
    .axi_w_data(axi_w_data),
    .axi_w_last(axi_w_last),
    .axi_w_strb(axi_w_strb),
    .axi_w_valid(axi_w_valid),
    .axi_w_ready(axi_w_ready),
    .axi_b_resp(axi_b_resp),
    .axi_b_id(axi_b_id),
    .axi_b_valid(axi_b_valid),
    .axi_b_ready(axi_b_ready),
    .axi_ar_addr(axi_ar_addr),
    .axi_ar_burst(axi_ar_burst),
    .axi_ar_size(axi_ar_size),
    .axi_ar_id(axi_ar_id),
    .axi_ar_len(axi_ar_len),
    .axi_ar_valid(axi_ar_valid),
    .axi_ar_ready(axi_ar_ready),
    .axi_r_data(axi_r_data),
    .axi_r_id(axi_r_id),
    .axi_r_resp(axi_r_resp),
    .axi_r_last(axi_r_last),
    .axi_r_valid(axi_r_valid),
    .axi_r_ready(axi_r_ready)
);


// Time 0 payload and expected value generation
initial begin
    // Generate Write Address Channel payloads
    generate_write_addr_payloads();
    generate_write_addr_payloads_with_stall();
    
    // Generate Write Data Channel payloads
    generate_write_data_payloads();
    generate_write_data_payloads_with_stall();
    
    // Generate Read Address Channel payloads
    generate_read_addr_payloads();
    generate_read_addr_payloads_with_stall();
    
    // Generate Read Data Channel expected values
    generate_read_data_expected();
    
    // Generate Write Response Channel expected values
    generate_write_resp_expected();
    
    // Initialize ready negate pulse arrays
    initialize_ready_negate_pulses();
    
    $display("Payloads and Expected Values Generated:");
    $display("  Write Address - Basic: %0d, Stall: %0d", 
             write_addr_payloads.size(), write_addr_payloads_with_stall.size());
    $display("  Write Data - Basic: %0d, Stall: %0d", 
             write_data_payloads.size(), write_data_payloads_with_stall.size());
    $display("  Read Address - Basic: %0d, Stall: %0d", 
             read_addr_payloads.size(), read_addr_payloads_with_stall.size());
    $display("  Read Data Expected - %0d", read_data_expected.size());
    $display("  Write Response Expected - %0d", write_resp_expected.size());
    
    // Set completion flag
    #1;
    generate_stimulus_expected_done = 1'b1;
end

// Test scenario control
initial begin
    
    // Initialize
    current_phase = 8'd0;
    write_addr_phase_start = 1'b0;
    read_addr_phase_start = 1'b0;
    write_data_phase_start = 1'b0;
    read_data_phase_start = 1'b0;
    
    // Wait for stimulus generation completion
    wait(generate_stimulus_expected_done);
    $display("Phase %0d: Stimulus and Expected Values Generation Confirmed", current_phase);
    
    // Wait for reset deassertion
    wait(rst_n);
    $display("Phase %0d: Reset Deassertion Confirmed", current_phase);
    
    // Start first phase
    repeat(2) @(posedge clk);
    #1;
    write_addr_phase_start = 1'b1;
    write_data_phase_start = 1'b1;
    
    @(posedge clk);
    #1;
    write_addr_phase_start = 1'b0;
    write_data_phase_start = 1'b0;
    
    // Wait for first phase completion
    wait(write_addr_phase_done_latched && write_data_phase_done_latched);
    
    $display("Phase %0d: All Channels Completed", current_phase);
    
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b1;  // Assert clear signal
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b0;  // Deassert clear signal
        
    current_phase = current_phase + 8'd1;
    
    // Phase control loop
    for (int phase = 0; phase < (TOTAL_TEST_COUNT / PHASE_TEST_COUNT) - 1; phase++) begin
        @(posedge clk);
        #1;
        // Start all channels
        write_addr_phase_start = 1'b1;
        read_addr_phase_start = 1'b1;
        write_data_phase_start = 1'b1;
        read_data_phase_start = 1'b1;
        
        @(posedge clk);
        #1;
        write_addr_phase_start = 1'b0;
        read_addr_phase_start = 1'b0;
        write_data_phase_start = 1'b0;
        read_data_phase_start = 1'b0;
        
        // Wait for all channels completion
        wait(write_addr_phase_done_latched && read_addr_phase_done_latched && 
             write_data_phase_done_latched && read_data_phase_done_latched);
        
        $display("Phase %0d: All Channels Completed", current_phase);
        
        @(posedge clk);
        #1;
        clear_phase_latches = 1'b1;  // Assert clear signal
        @(posedge clk);
        #1;
        clear_phase_latches = 1'b0;  // Deassert clear signal
        
        current_phase = current_phase + 8'd1;
    end
    
    // Final phase
    @(posedge clk);
    #1;
    read_addr_phase_start = 1'b1;
    read_data_phase_start = 1'b1;
    
    @(posedge clk);
    #1;
    read_addr_phase_start = 1'b0;
    read_data_phase_start = 1'b0;
    
    // Wait for final phase completion
    wait(read_addr_phase_done_latched && read_data_phase_done_latched);
    
    $display("Phase %0d: All Channels Completed", current_phase);
    
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b1;  // Assert clear signal
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b0;  // Deassert clear signal
        
        // All phases completed
    $display("All Phases Completed. Test Scenario Finished.");
    test_execution_completed = 1'b1;  // Set test completion flag
    #1 // Wait for test completion log to be written
    $finish;
end

// Phase completion signal latches
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_addr_phase_done_latched <= 1'b0;
        read_addr_phase_done_latched <= 1'b0;
        write_data_phase_done_latched <= 1'b0;
        read_data_phase_done_latched <= 1'b0;
    end else if (clear_phase_latches) begin
        // Clear latched signals when clear signal is asserted
        write_addr_phase_done_latched <= 1'b0;
        read_addr_phase_done_latched <= 1'b0;
        write_data_phase_done_latched <= 1'b0;
        read_data_phase_done_latched <= 1'b0;
    end else begin
        if (write_addr_phase_done) write_addr_phase_done_latched <= 1'b1;
        if (read_addr_phase_done) read_addr_phase_done_latched <= 1'b1;
        if (write_data_phase_done) write_data_phase_done_latched <= 1'b1;
        if (read_data_phase_done) read_data_phase_done_latched <= 1'b1;
    end
end

// Write Address Channel Control Circuit
typedef enum logic [1:0] {
    WRITE_ADDR_IDLE,        // 待機状態
    WRITE_ADDR_ACTIVE,      // アクティブ状態（ストール処理も含む）
    WRITE_ADDR_FINISH       // 終了処理状態
} write_addr_state_t;

write_addr_state_t write_addr_state = WRITE_ADDR_IDLE;
logic [7:0] write_addr_phase_counter = 8'd0;
logic write_addr_phase_busy = 1'b0;
int write_addr_array_index = 0;

// Write Address Channel Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_addr_state <= WRITE_ADDR_IDLE;
        write_addr_phase_counter <= 8'd0;
        write_addr_phase_busy <= 1'b0;
        write_addr_phase_done <= 1'b0;
        write_addr_array_index <= 0;
        
        // AXI4 signals
        axi_aw_addr <= '0;
        axi_aw_burst <= '0;
        axi_aw_size <= '0;
        axi_aw_id <= '0;
        axi_aw_len <= '0;
        axi_aw_valid <= 1'b0;
    end else begin
        case (write_addr_state)
            WRITE_ADDR_IDLE: begin
                if (write_addr_phase_start) begin
                    write_addr_state <= WRITE_ADDR_ACTIVE;
                    write_addr_phase_busy <= 1'b1;
                    write_addr_phase_counter <= 8'd0;
                    write_addr_array_index <= 0;
                    write_addr_phase_done <= 1'b0;
                end
            end
            
            WRITE_ADDR_ACTIVE: begin
                if (write_addr_phase_counter < PHASE_TEST_COUNT && 
                    write_addr_array_index < write_addr_payloads_with_stall.size()) begin
                    
                    if (axi_aw_ready) begin
                        // Output payload when ready is asserted
                        automatic write_addr_payload_t payload = write_addr_payloads_with_stall[write_addr_array_index];
                        
                        axi_aw_addr <= payload.addr;
                        axi_aw_burst <= payload.burst;
                        axi_aw_size <= payload.size;
                        axi_aw_id <= payload.id;
                        axi_aw_len <= payload.len;
                        axi_aw_valid <= payload.valid;
                        
                        // Debug output
                        if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                            write_debug_log($sformatf("Write Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                write_addr_array_index, payload.test_count, payload.addr, payload.burst, 
                                payload.size, payload.id, payload.len, payload.valid));
                        end
                        
                        write_addr_array_index <= write_addr_array_index + 1;
                        
                        if (payload.valid) begin
                            write_addr_phase_counter <= write_addr_phase_counter + 8'd1;
                        end
                    end
                end else begin
                    // Array end reached: transition to finish state
                    write_addr_state <= WRITE_ADDR_FINISH;
                    write_addr_phase_done <= 1'b1;
                end
            end
            
            WRITE_ADDR_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                write_addr_phase_done <= 1'b0;
                write_addr_phase_busy <= 1'b0;
                write_addr_state <= WRITE_ADDR_IDLE;
            end
        endcase
    end
end

// Read Address Channel Control Circuit
typedef enum logic [1:0] {
    READ_ADDR_IDLE,        // 待機状態
    READ_ADDR_ACTIVE,      // アクティブ状態（ストール処理も含む）
    READ_ADDR_FINISH       // 終了処理状態
} read_addr_state_t;

read_addr_state_t read_addr_state = READ_ADDR_IDLE;
logic [7:0] read_addr_phase_counter = 8'd0;
logic read_addr_phase_busy = 1'b0;
int read_addr_array_index = 0;

// Read Address Channel Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_addr_state <= READ_ADDR_IDLE;
        read_addr_phase_counter <= 8'd0;
        read_addr_phase_busy <= 1'b0;
        read_addr_phase_done <= 1'b0;
        read_addr_array_index <= 0;
        
        // AXI4 signals
        axi_ar_addr <= '0;
        axi_ar_burst <= '0;
        axi_ar_size <= '0;
        axi_ar_id <= '0;
        axi_ar_len <= '0;
        axi_ar_valid <= 1'b0;
    end else begin
        case (read_addr_state)
            READ_ADDR_IDLE: begin
                if (read_addr_phase_start) begin
                    read_addr_state <= READ_ADDR_ACTIVE;
                    read_addr_phase_busy <= 1'b1;
                    read_addr_phase_counter <= 8'd0;
                    read_addr_array_index <= 0;
                    read_addr_phase_done <= 1'b0;
                end
            end
            
            READ_ADDR_ACTIVE: begin
                if (read_addr_phase_counter < PHASE_TEST_COUNT && 
                    read_addr_array_index < read_addr_payloads_with_stall.size()) begin
                    
                    if (axi_ar_ready) begin
                        // Output payload when ready is asserted
                        automatic read_addr_payload_t payload = read_addr_payloads_with_stall[read_addr_array_index];
                        
                        axi_ar_addr <= payload.addr;
                        axi_ar_burst <= payload.burst;
                        axi_ar_size <= payload.size;
                        axi_ar_id <= payload.id;
                        axi_ar_len <= payload.len;
                        axi_ar_valid <= payload.valid;
                        
                        // Debug output
                        if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                            write_debug_log($sformatf("Read Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                read_addr_array_index, payload.test_count, payload.addr, payload.burst, 
                                payload.size, payload.id, payload.len, payload.valid));
                        end
                        
                        read_addr_array_index <= read_addr_array_index + 1;
                        
                        if (payload.valid) begin
                            read_addr_phase_counter <= read_addr_phase_counter + 8'd1;
                        end
                    end
                end else begin
                    // Array end reached: transition to finish state
                    read_addr_state <= READ_ADDR_FINISH;
                    read_addr_phase_done <= 1'b1;
                end
            end
            
            READ_ADDR_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                read_addr_phase_done <= 1'b0;
                read_addr_phase_busy <= 1'b0;
                read_addr_state <= READ_ADDR_IDLE;
            end
        endcase
    end
end

// Write Data Channel Control Circuit
typedef enum logic [1:0] {
    WRITE_DATA_IDLE,        // 待機状態
    WRITE_DATA_ACTIVE,      // アクティブ状態（ストール処理も含む）
    WRITE_DATA_FINISH       // 終了処理状態
} write_data_state_t;

write_data_state_t write_data_state = WRITE_DATA_IDLE;
logic [7:0] write_data_phase_counter = 8'd0;
logic write_data_phase_busy = 1'b0;
int write_data_array_index = 0;

// Write Data Channel Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_data_state <= WRITE_DATA_IDLE;
        write_data_phase_counter <= 8'd0;
        write_data_phase_busy <= 1'b0;
        write_data_phase_done <= 1'b0;
        write_data_array_index <= 0;
        
        // AXI4 signals
        axi_w_data <= '0;
        axi_w_strb <= '0;
        axi_w_last <= 1'b0;
        axi_w_valid <= 1'b0;
    end else begin
        case (write_data_state)
            WRITE_DATA_IDLE: begin
                if (write_data_phase_start) begin
                    write_data_state <= WRITE_DATA_ACTIVE;
                    write_data_phase_busy <= 1'b1;
                    write_data_phase_counter <= 8'd0;
                    write_data_array_index <= 0;
                    write_data_phase_done <= 1'b0;
                end
            end
            
            WRITE_DATA_ACTIVE: begin
                if (write_data_phase_counter < PHASE_TEST_COUNT && 
                    write_data_array_index < write_data_payloads_with_stall.size()) begin
                    
                    if (axi_w_ready) begin
                        // Output payload when ready is asserted
                        automatic write_data_payload_t payload = write_data_payloads_with_stall[write_data_array_index];
                        
                        axi_w_data <= payload.data;
                        axi_w_strb <= payload.strb;
                        axi_w_last <= payload.last;
                        axi_w_valid <= payload.valid;
                        
                        // Debug output
                        if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                            write_debug_log($sformatf("Write Data[%0d]: test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d", 
                                write_data_array_index, payload.test_count, payload.data, payload.strb, 
                                payload.last, payload.valid));
                        end
                        
                        write_data_array_index <= write_data_array_index + 1;
                        
                        if (payload.valid) begin
                            write_data_phase_counter <= write_data_phase_counter + 8'd1;
                        end
                    end
                end else begin
                    // Array end reached: transition to finish state
                    write_data_state <= WRITE_DATA_FINISH;
                    write_data_phase_done <= 1'b1;
                end
            end
            
            WRITE_DATA_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                write_data_phase_done <= 1'b0;
                write_data_phase_busy <= 1'b0;
                write_data_state <= WRITE_DATA_IDLE;
            end
        endcase
    end
end

// Read Data Channel Control Circuit
typedef enum logic [1:0] {
    READ_DATA_IDLE,        // 待機状態
    READ_DATA_ACTIVE,      // アクティブ状態（期待値検証も含む）
    READ_DATA_FINISH       // 終了処理状態
} read_data_state_t;

read_data_state_t read_data_state = READ_DATA_IDLE;
logic [7:0] read_data_phase_counter = 8'd0;
logic read_data_phase_busy = 1'b0;
int read_data_array_index = 0;

// Read Data Channel Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_data_state <= READ_DATA_IDLE;
        read_data_phase_counter <= 8'd0;
        read_data_phase_busy <= 1'b0;
        read_data_phase_done <= 1'b0;
        read_data_array_index <= 0;
        
        // AXI4 signals
        axi_r_ready <= 1'b0;
    end else begin
        case (read_data_state)
            READ_DATA_IDLE: begin
                if (read_data_phase_start) begin
                    read_data_state <= READ_DATA_ACTIVE;
                    read_data_phase_busy <= 1'b1;
                    read_data_phase_counter <= 8'd0;
                    read_data_array_index <= 0;
                    read_data_phase_done <= 1'b0;
                    axi_r_ready <= 1'b1;
                end
            end
            
            READ_DATA_ACTIVE: begin
                if (read_data_phase_counter < PHASE_TEST_COUNT && 
                    read_data_array_index < read_data_expected.size()) begin
                    
                    if (axi_r_valid && axi_r_ready) begin
                        // Verify expected data
                        automatic read_data_expected_t expected = read_data_expected[read_data_array_index];
                        
                        if (axi_r_data !== expected.expected_data) begin
                            $error("Read Data Mismatch at index %0d: Expected 0x%h, Got 0x%h", 
                                   read_data_array_index, expected.expected_data, axi_r_data);
                            $finish;
                        end
                        
                        // Debug output
                        if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                            write_debug_log($sformatf("Read Data[%0d]: test_count=%0d, data=0x%h, expected=0x%h, last=%0d", 
                                read_data_array_index, expected.test_count, axi_r_data, expected.expected_data, axi_r_last));
                        end
                        
                        read_data_array_index <= read_data_array_index + 1;
                        read_data_phase_counter <= read_data_phase_counter + 8'd1;
                    end
                end else begin
                    // Array end reached: transition to finish state
                    read_data_state <= READ_DATA_FINISH;
                    read_data_phase_done <= 1'b1;
                end
            end
            
            READ_DATA_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                read_data_phase_done <= 1'b0;
                read_data_phase_busy <= 1'b0;
                read_data_state <= READ_DATA_IDLE;
                axi_r_ready <= 1'b0;
            end
        endcase
    end
end

// Protocol Verification System
// 1-clock delayed signals for payload hold check
logic [AXI_ADDR_WIDTH-1:0] axi_aw_addr_delayed;
logic [1:0]                axi_aw_burst_delayed;
logic [2:0]                axi_aw_size_delayed;
logic [AXI_ID_WIDTH-1:0]   axi_aw_id_delayed;
logic [7:0]                axi_aw_len_delayed;
logic                      axi_aw_valid_delayed;
logic                      axi_aw_ready_delayed;

logic [AXI_DATA_WIDTH-1:0] axi_w_data_delayed;
logic [AXI_STRB_WIDTH-1:0] axi_w_strb_delayed;
logic                       axi_w_last_delayed;
logic                       axi_w_valid_delayed;
logic                       axi_w_ready_delayed;

logic [AXI_ADDR_WIDTH-1:0] axi_ar_addr_delayed;
logic [1:0]                axi_ar_burst_delayed;
logic [2:0]                axi_ar_size_delayed;
logic [AXI_ID_WIDTH-1:0]   axi_ar_id_delayed;
logic [7:0]                axi_ar_len_delayed;
logic                      axi_ar_valid_delayed;
logic                      axi_ar_ready_delayed;

logic [AXI_DATA_WIDTH-1:0] axi_r_data_delayed;
logic [AXI_ID_WIDTH-1:0]   axi_r_id_delayed;
logic [1:0]                axi_r_resp_delayed;
logic                       axi_r_last_delayed;
logic                       axi_r_valid_delayed;
logic                       axi_r_ready_delayed;

// 1-clock delay circuit
always_ff @(posedge clk) begin
    // Write Address Channel
    axi_aw_addr_delayed <= axi_aw_addr;
    axi_aw_burst_delayed <= axi_aw_burst;
    axi_aw_size_delayed <= axi_aw_size;
    axi_aw_id_delayed <= axi_aw_id;
    axi_aw_len_delayed <= axi_aw_len;
    axi_aw_valid_delayed <= axi_aw_valid;
    axi_aw_ready_delayed <= axi_aw_ready;
    
    // Write Data Channel
    axi_w_data_delayed <= axi_w_data;
    axi_w_strb_delayed <= axi_w_strb;
    axi_w_last_delayed <= axi_w_last;
    axi_w_valid_delayed <= axi_w_valid;
    axi_w_ready_delayed <= axi_w_ready;
    
    // Read Address Channel
    axi_ar_addr_delayed <= axi_ar_addr;
    axi_ar_burst_delayed <= axi_ar_burst;
    axi_ar_size_delayed <= axi_ar_size;
    axi_ar_id_delayed <= axi_ar_id;
    axi_ar_len_delayed <= axi_ar_len;
    axi_ar_valid_delayed <= axi_ar_valid;
    axi_ar_ready_delayed <= axi_ar_ready;
    
    // Read Data Channel
    axi_r_data_delayed <= axi_r_data;
    axi_r_id_delayed <= axi_r_id;
    axi_r_resp_delayed <= axi_r_resp;
    axi_r_last_delayed <= axi_r_last;
    axi_r_valid_delayed <= axi_r_valid;
    axi_r_ready_delayed <= axi_r_ready;
end

// Write Address Channel payload hold check (start monitoring after reset deassertion)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Don't monitor during reset
    end else begin
        if (!axi_aw_ready_delayed) begin
            // Check if payload changed during Ready negated
            if (axi_aw_addr !== axi_aw_addr_delayed) begin
                $error("Write Address Channel: Address changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_aw_addr, axi_aw_addr_delayed);
                $finish;
            end
            if (axi_aw_burst !== axi_aw_burst_delayed) begin
                $error("Write Address Channel: Burst changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_aw_burst, axi_aw_burst_delayed);
                $finish;
            end
            if (axi_aw_size !== axi_aw_size_delayed) begin
                $error("Write Address Channel: Size changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_aw_size, axi_aw_size_delayed);
                $finish;
            end
            if (axi_aw_id !== axi_aw_id_delayed) begin
                $error("Write Address Channel: ID changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_aw_id, axi_aw_id_delayed);
                $finish;
            end
            if (axi_aw_len !== axi_aw_len_delayed) begin
                $error("Write Address Channel: Length changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_aw_len, axi_aw_len_delayed);
                $finish;
            end
            if (axi_aw_valid !== axi_aw_valid_delayed) begin
                $error("Write Address Channel: Valid changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_aw_valid, axi_aw_valid_delayed);
                $finish;
            end
        end
    end
end

// Write Data Channel payload hold check
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Don't monitor during reset
    end else begin
        if (!axi_w_ready_delayed) begin
            if (axi_w_data !== axi_w_data_delayed) begin
                $error("Write Data Channel: Data changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_w_data, axi_w_data_delayed);
                $finish;
            end
            if (axi_w_strb !== axi_w_strb_delayed) begin
                $error("Write Data Channel: Strobe changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_w_strb, axi_w_strb_delayed);
                $finish;
            end
            if (axi_w_last !== axi_w_last_delayed) begin
                $error("Write Data Channel: Last changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_w_last, axi_w_last_delayed);
                $finish;
            end
            if (axi_w_valid !== axi_w_valid_delayed) begin
                $error("Write Data Channel: Valid changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_w_valid, axi_w_valid_delayed);
                $finish;
            end
        end
    end
end

// Read Address Channel payload hold check
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Don't monitor during reset
    end else begin
        if (!axi_ar_ready_delayed) begin
            if (axi_ar_addr !== axi_ar_addr_delayed) begin
                $error("Read Address Channel: Address changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_ar_addr, axi_ar_addr_delayed);
                $finish;
            end
            if (axi_ar_burst !== axi_ar_burst_delayed) begin
                $error("Read Address Channel: Burst changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_ar_burst, axi_ar_burst_delayed);
                $finish;
            end
            if (axi_ar_size !== axi_ar_size_delayed) begin
                $error("Read Address Channel: Size changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_ar_size, axi_ar_size_delayed);
                $finish;
            end
            if (axi_ar_id !== axi_ar_id_delayed) begin
                $error("Read Address Channel: ID changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_ar_id, axi_ar_id_delayed);
                $finish;
            end
            if (axi_ar_len !== axi_ar_len_delayed) begin
                $error("Read Address Channel: Length changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_ar_len, axi_ar_len_delayed);
                $finish;
            end
            if (axi_ar_valid !== axi_ar_valid_delayed) begin
                $error("Read Address Channel: Valid changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_ar_valid, axi_ar_valid_delayed);
                $finish;
            end
        end
    end
end

// Read Data Channel payload hold check
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Don't monitor during reset
    end else begin
        if (!axi_r_ready_delayed) begin
            if (axi_r_data !== axi_r_data_delayed) begin
                $error("Read Data Channel: Data changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_r_data, axi_r_data_delayed);
                $finish;
            end
            if (axi_r_id !== axi_r_id_delayed) begin
                $error("Read Data Channel: ID changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_r_id, axi_r_id_delayed);
                $finish;
            end
            if (axi_r_resp !== axi_r_resp_delayed) begin
                $error("Read Data Channel: Response changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_r_resp, axi_r_resp_delayed);
                $finish;
            end
            if (axi_r_last !== axi_r_last_delayed) begin
                $error("Read Data Channel: Last changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_r_last, axi_r_last_delayed);
                $finish;
            end
            if (axi_r_valid !== axi_r_valid_delayed) begin
                $error("Read Data Channel: Valid changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_r_valid, axi_r_valid_delayed);
                $finish;
            end
        end
    end
end

// Test start and completion summary
initial begin
    if (LOG_ENABLE) begin
        // Phase 1: Display test configuration
        write_log("=== AXI4 Testbench Configuration ===");
        write_log("Test Configuration:");
        write_log($sformatf("  - Memory Size: %0d bytes (%0d MB)", MEMORY_SIZE_BYTES, MEMORY_SIZE_BYTES/1024/1024));
        write_log($sformatf("  - Data Width: %0d bits", AXI_DATA_WIDTH));
        write_log($sformatf("  - Total Test Count: %0d", TOTAL_TEST_COUNT));
        write_log($sformatf("  - Phase Test Count: %0d", PHASE_TEST_COUNT));
        write_log($sformatf("  - Number of Phases: %0d", (TOTAL_TEST_COUNT / PHASE_TEST_COUNT)));
        
        // Wait for stimulus generation completion
        wait(generate_stimulus_expected_done);
        
        // Phase 2: Display generated payloads summary
        write_log("=== Generated Payloads Summary ===");
        write_log("Generated Test Data:");
        write_log($sformatf("  - Write Address Payloads: %0d", write_addr_payloads.size()));
        write_log($sformatf("  - Write Address with Stall: %0d", write_addr_payloads_with_stall.size()));
        write_log($sformatf("  - Write Data Payloads: %0d", write_data_payloads.size()));
        write_log($sformatf("  - Write Data with Stall: %0d", write_data_payloads_with_stall.size()));
        write_log($sformatf("  - Read Address Payloads: %0d", read_addr_payloads.size()));
        write_log($sformatf("  - Read Address with Stall: %0d", read_addr_payloads_with_stall.size()));
        write_log($sformatf("  - Read Data Expected: %0d", read_data_expected.size()));
        write_log($sformatf("  - Write Response Expected: %0d", write_resp_expected.size()));
        
        // Wait for test execution completion
        wait(test_execution_completed);
        
        // Phase 3: Display test execution results summary
        write_log("=== Test Execution Results Summary ===");
        write_log("Test Results:");
        write_log($sformatf("  - Total Tests Executed: %0d", TOTAL_TEST_COUNT));
        write_log($sformatf("  - Total Phases Completed: %0d", (TOTAL_TEST_COUNT / PHASE_TEST_COUNT)));
        write_log("  - All Phases: PASS");
        write_log("  - Test Status: COMPLETED SUCCESSFULLY");
        write_log("=== AXI4 Testbench Log End ===");
    end
end

// Ready negate control logic
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ready_negate_index <= 0;
        axi_aw_ready <= 1'b1;
        axi_w_ready <= 1'b1;
        axi_b_ready <= 1'b1;
    end else begin
        // Update ready negate index
        if (ready_negate_index >= READY_NEGATE_ARRAY_LENGTH - 1) begin
            ready_negate_index <= 0;  // Reset to 0 when reaching maximum
        end else begin
            ready_negate_index <= ready_negate_index + 1;
        end
        
        // Control ready signals based on pulse arrays
        // Note: ! is used because axi_*_ready_negate_pulses[i] = 1 means "negate ready signal"
        //       So we need to invert: !1 = 0 (negate), !0 = 1 (active)
        axi_aw_ready <= !axi_aw_ready_negate_pulses[ready_negate_index];
        axi_w_ready <= !axi_w_ready_negate_pulses[ready_negate_index];
        axi_b_ready <= !axi_b_ready_negate_pulses[ready_negate_index];
    end
end

// Logging and monitoring
// Phase execution logging
always @(posedge clk) begin
    if (LOG_ENABLE && write_addr_phase_start) begin
        write_log($sformatf("Phase %0d: Write Address Channel started", current_phase));
    end
    if (LOG_ENABLE && read_addr_phase_start) begin
        write_log($sformatf("Phase %0d: Read Address Channel started", current_phase));
    end
    if (LOG_ENABLE && write_data_phase_start) begin
        write_log($sformatf("Phase %0d: Write Data Channel started", current_phase));
    end
    if (LOG_ENABLE && read_data_phase_start) begin
        write_log($sformatf("Phase %0d: Read Data Channel started", current_phase));
    end
end

// AXI4 transfer logging (debug)
always @(posedge clk) begin
    if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
        // Write Address Channel transfer
        if (axi_aw_valid && axi_aw_ready) begin
            write_debug_log($sformatf("Write Addr Transfer: addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d", 
                axi_aw_addr, axi_aw_burst, axi_aw_size, axi_aw_id, axi_aw_len));
        end
        
        // Write Data Channel transfer
        if (axi_w_valid && axi_w_ready) begin
            write_debug_log($sformatf("Write Data Transfer: data=0x%h, strb=0x%h, last=%0d", 
                axi_w_data, axi_w_strb, axi_w_last));
        end
        
        // Read Address Channel transfer
        if (axi_ar_valid && axi_ar_ready) begin
            write_debug_log($sformatf("Read Addr Transfer: addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d", 
                axi_ar_addr, axi_ar_burst, axi_ar_size, axi_ar_id, axi_ar_len));
        end
        
        // Read Data Channel transfer
        if (axi_r_valid && axi_r_ready) begin
            write_debug_log($sformatf("Read Data Transfer: data=0x%h, resp=%0d, last=%0d", 
                axi_r_data, axi_r_resp, axi_r_last));
        end
    end
end

// Stall cycle logging (debug)
always @(posedge clk) begin
    if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
        // Write Address Channel stall
        if (axi_aw_valid && !axi_aw_ready) begin
            write_debug_log("Write Addr Channel: Stall detected");
        end
        
        // Write Data Channel stall
        if (axi_w_valid && !axi_w_ready) begin
            write_debug_log("Write Data Channel: Stall detected");
        end
        
        // Read Address Channel stall
        if (axi_ar_valid && !axi_ar_ready) begin
            write_debug_log("Read Addr Channel: Stall detected");
        end
        
        // Read Data Channel stall
        if (axi_r_valid && !axi_r_ready) begin
            write_debug_log("Read Data Channel: Stall detected");
        end
    end
end

// Write Response Channel Control and Verification
// axi_b_ready is already declared at line 62, so we just use it

// Write Response verification
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Don't verify during reset
    end else begin
        if (axi_b_valid && axi_b_ready) begin
            // Find corresponding expected response
            automatic int found_index = -1;
            automatic int i;
            foreach (write_resp_expected[i]) begin
                if (write_resp_expected[i].expected_id === axi_b_id) begin
                    found_index = i;
                    break;
                end
            end
            
            if (found_index >= 0) begin
                automatic write_resp_expected_t expected = write_resp_expected[found_index];
                
                // Verify response
                if (axi_b_resp !== expected.expected_resp) begin
                    $error("Write Response Mismatch: Expected %0d, Got %0d for ID %0d", 
                           expected.expected_resp, axi_b_resp, axi_b_id);
                    $finish;
                end
                
                // Debug output
                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                    write_debug_log($sformatf("Write Response Verified: ID=%0d, Resp=%0d, Expected=%0d", 
                        axi_b_id, axi_b_resp, expected.expected_resp));
                end
            end else begin
                $error("Write Response: No expected value found for ID %0d", axi_b_id);
                $finish;
            end
        end
    end
end

endmodule
