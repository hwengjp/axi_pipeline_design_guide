// AXI4 Simple Dual Port RAM Testbench
// Comprehensive testbench for AXI4 bus protocol verification with weighted random stimulus

// Define TOP macro for hierarchical references
`define TOP axi_simple_dual_port_ram_tb

// Import common logging package
import axi_logger_pkg::*;

`timescale 1ns/1ps

module axi_simple_dual_port_ram_tb;

// Logging control parameters
parameter LOG_ENABLE = 1'b1;                // Enable general logging
parameter DEBUG_LOG_ENABLE = 1'b1;          // Enable debug-level logging

// Testbench configuration parameters
parameter MEMORY_SIZE_BYTES = 33554432;     // Memory size: 32MB
parameter AXI_DATA_WIDTH = 32;              // AXI data width: 32 bits
parameter AXI_ID_WIDTH = 8;                 // AXI ID width: 8 bits
parameter TOTAL_TEST_COUNT = 800;           // Total number of test cases
parameter PHASE_TEST_COUNT = 8;             // Number of tests per phase
parameter TEST_COUNT_ADDR_SIZE_BYTES = 4096; // Address space per test: 4KB
parameter CLK_PERIOD = 10;                  // Clock period: 10ns (100MHz)
parameter RESET_CYCLES = 4;                 // Reset duration: 4 clock cycles

// Derived parameters (auto-calculated)
parameter AXI_ADDR_WIDTH = $clog2(MEMORY_SIZE_BYTES);  // Address width: auto-calculated from memory size
parameter AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;         // Strobe width: 4 bytes for 32-bit data

// AXI4 Write Address Channel signals
logic [AXI_ADDR_WIDTH-1:0] axi_aw_addr;    // Write address
logic [1:0]                axi_aw_burst;   // Burst type (FIXED/INCR/WRAP)
logic [2:0]                axi_aw_size;    // Transfer size (0=1byte, 1=2bytes, 2=4bytes)
logic [AXI_ID_WIDTH-1:0]   axi_aw_id;      // Write transaction ID
logic [7:0]                axi_aw_len;     // Burst length (number of transfers - 1)
logic                      axi_aw_valid;   // Write address valid
wire                       axi_aw_ready;   // Write address ready

// AXI4 Write Data Channel signals
logic [AXI_DATA_WIDTH-1:0] axi_w_data;     // Write data
logic [AXI_STRB_WIDTH-1:0] axi_w_strb;     // Write strobe (byte enables)
logic                       axi_w_last;     // Last transfer in burst
logic                       axi_w_valid;    // Write data valid
wire                       axi_w_ready;    // Write data ready

// AXI4 Write Response Channel signals
wire [1:0]                axi_b_resp;      // Write response (OKAY/EXOKAY/SLVERR/DECERR)
wire [AXI_ID_WIDTH-1:0]   axi_b_id;        // Write response ID
wire                       axi_b_valid;    // Write response valid
logic                      axi_b_ready;    // Write response ready

// AXI4 Read Address Channel signals
logic [AXI_ADDR_WIDTH-1:0] axi_ar_addr;    // Read address
logic [1:0]                axi_ar_burst;   // Burst type (FIXED/INCR/WRAP)
logic [2:0]                axi_ar_size;    // Transfer size (0=1byte, 1=2bytes, 2=4bytes)
logic [AXI_ID_WIDTH-1:0]   axi_ar_id;      // Read transaction ID
logic [7:0]                axi_ar_len;     // Burst length (number of transfers - 1)
logic                      axi_ar_valid;   // Read address valid
wire                       axi_ar_ready;   // Read address ready

// AXI4 Read Data Channel signals
wire [AXI_DATA_WIDTH-1:0] axi_r_data;     // Read data
wire [AXI_ID_WIDTH-1:0]   axi_r_id;       // Read data ID
wire [1:0]                axi_r_resp;     // Read response (OKAY/EXOKAY/SLVERR/DECERR)
wire                       axi_r_last;     // Last transfer in burst
wire                       axi_r_valid;    // Read data valid
logic                      axi_r_ready;    // Read data ready

// Test control and status flags
logic generate_stimulus_expected_done = 1'b0;  // Flag: stimulus generation completed
logic test_execution_completed = 1'b0;         // Flag: test execution completed

// Ready signal control parameters for backpressure testing
parameter READY_NEGATE_ARRAY_LENGTH = 1000;   // Length of ready negate pulse array

// Ready negate pulse arrays for testbench-controlled channels
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_r_ready_negate_pulses;  // Read data ready negate pulses
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_b_ready_negate_pulses;  // Write response ready negate pulses

// Ready negate control index counter
logic [$clog2(READY_NEGATE_ARRAY_LENGTH):0] ready_negate_index = 0;  // Current pulse array index

// Weighted random generation data structures
typedef struct {
    int weight;           // Selection weight for random generation
    int length_min;       // Minimum burst length
    int length_max;       // Maximum burst length
    string burst_type;    // Burst type: "FIXED", "INCR", or "WRAP"
} burst_config_t;

typedef struct {
    int weight;           // Selection weight for random generation
    int cycles;           // Number of stall cycles to insert
} bubble_param_t;

// Burst configuration weights for weighted random selection (Total weight: 11)
burst_config_t burst_config_weights[] = '{
    '{weight: 4, length_min: 1, length_max: 3, burst_type: "INCR"},    // 4/11 = 36.4%: Short INCR bursts
    '{weight: 3, length_min: 4, length_max: 7, burst_type: "INCR"},    // 3/11 = 27.3%: Medium INCR bursts
    '{weight: 2, length_min: 8, length_max: 15, burst_type: "INCR"},   // 2/11 = 18.2%: Long INCR bursts
    '{weight: 1, length_min: 15, length_max: 31, burst_type: "WRAP"},  // 1/11 = 9.1%: WRAP bursts
    '{weight: 1, length_min: 0, length_max: 0, burst_type: "FIXED"}    // 1/11 = 9.1%: Single FIXED transfers
};

// Write address channel bubble weights for backpressure testing (Total weight: 104)
bubble_param_t write_addr_bubble_weights[] = '{
    '{weight: 70, cycles: 0},  // 70/104 = 67.3%: No stall
    '{weight: 20, cycles: 1},  // 20/104 = 19.2%: 1-cycle stall
    '{weight: 10, cycles: 2},  // 10/104 = 9.6%: 2-cycle stall
    '{weight: 4, cycles: 7}    // 4/104 = 3.8%: 7-cycle stall
};

// Write data channel bubble weights for backpressure testing (Total weight: 104)
bubble_param_t write_data_bubble_weights[] = '{
    '{weight: 80, cycles: 0},  // 80/104 = 76.9%: No stall
    '{weight: 15, cycles: 1},  // 15/104 = 14.4%: 1-cycle stall
    '{weight: 5, cycles: 2},   // 5/104 = 4.8%: 2-cycle stall
    '{weight: 4, cycles: 7}    // 4/104 = 3.8%: 7-cycle stall
};

// Read address channel bubble weights for backpressure testing (Total weight: 104)
bubble_param_t read_addr_bubble_weights[] = '{
    '{weight: 75, cycles: 0},  // 75/104 = 72.1%: No stall
    '{weight: 20, cycles: 1},  // 20/104 = 19.2%: 1-cycle stall
    '{weight: 5, cycles: 2},   // 5/104 = 4.8%: 2-cycle stall
    '{weight: 4, cycles: 7}    // 4/104 = 3.8%: 7-cycle stall
};

// Read data channel ready negate weights for backpressure testing (Total weight: 94)
bubble_param_t axi_r_ready_negate_weights[] = '{
    '{weight: 80, cycles: 0},  // 80/94 = 85.1%: No ready negate
    '{weight: 5, cycles: 1},   // 5/94 = 5.3%: 1-cycle ready negate
    '{weight: 5, cycles: 2},   // 5/94 = 5.3%: 2-cycle ready negate
    '{weight: 4, cycles: 7}    // 4/94 = 4.3%: 7-cycle ready negate
};

// Write response channel ready negate weights for backpressure testing (Total weight: 94)
bubble_param_t axi_b_ready_negate_weights[] = '{
    '{weight: 80, cycles: 0},  // 80/94 = 85.1%: No ready negate
    '{weight: 5, cycles: 1},   // 5/94 = 5.3%: 1-cycle ready negate
    '{weight: 5, cycles: 2},   // 5/94 = 5.3%: 2-cycle ready negate
    '{weight: 4, cycles: 7}    // 4/94 = 4.3%: 7-cycle ready negate
};

// Test payload data structures for AXI4 channels
typedef struct {
    int                         test_count;  // Test case identifier
    logic [AXI_ADDR_WIDTH-1:0] addr;        // Target address
    logic [1:0]                burst;       // Burst type (FIXED/INCR/WRAP)
    logic [2:0]                size;        // Transfer size (0=1byte, 1=2bytes, 2=4bytes)
    logic [AXI_ID_WIDTH-1:0]   id;          // Transaction ID
    logic [7:0]                len;         // Burst length (number of transfers - 1)
    logic                      valid;       // Valid signal
    int                         phase;       // Test phase number
} write_addr_payload_t;

typedef struct {
    int                         test_count;  // Test case identifier
    logic [AXI_DATA_WIDTH-1:0] data;        // Write data
    logic [AXI_STRB_WIDTH-1:0] strb;        // Write strobe (byte enables)
    logic                       last;        // Last transfer in burst
    logic                       valid;       // Valid signal
    int                         phase;       // Test phase number
} write_data_payload_t;

typedef struct {
    int                         test_count;  // Test case identifier
    logic [AXI_ADDR_WIDTH-1:0] addr;        // Target address
    logic [1:0]                burst;       // Burst type (FIXED/INCR/WRAP)
    logic [2:0]                size;        // Transfer size (0=1byte, 1=2bytes, 2=4bytes)
    logic [AXI_ID_WIDTH-1:0]   id;          // Transaction ID
    logic [7:0]                len;         // Burst length (number of transfers - 1)
    logic                      valid;       // Valid signal
    int                         phase;       // Test phase number
} read_addr_payload_t;

// Payload arrays
write_addr_payload_t write_addr_payloads[int];
write_addr_payload_t write_addr_payloads_with_stall[int];
write_data_payload_t write_data_payloads[int];
write_data_payload_t write_data_payloads_with_stall[int];
read_addr_payload_t read_addr_payloads[int];
read_addr_payload_t read_addr_payloads_with_stall[int];

// Expected value structures for verification
typedef struct {
    int                         test_count;  // Test case identifier
    logic [AXI_DATA_WIDTH-1:0] expected_data;    // Expected read data
    logic [AXI_STRB_WIDTH-1:0] expected_strobe;  // Expected strobe pattern for verification
    int                         phase;            // Test phase number
} read_data_expected_t;

typedef struct {
    int                         test_count;  // Test case identifier
    logic [1:0]                expected_resp;    // Expected write response (OKAY/EXOKAY/SLVERR/DECERR)
    logic [AXI_ID_WIDTH-1:0]   expected_id;      // Expected write response ID
    int                         phase;            // Test phase number
} write_resp_expected_t;

// Expected value storage arrays
read_data_expected_t read_data_expected[int];      // Read data verification array
write_resp_expected_t write_resp_expected[int];    // Write response verification array

// Test phase control and synchronization signals
logic [7:0] current_phase = 8'd0;                 // Current test phase counter
logic write_addr_phase_start = 1'b0;              // Write address phase start trigger
logic read_addr_phase_start = 1'b0;               // Read address phase start trigger
logic write_data_phase_start = 1'b0;              // Write data phase start trigger
logic write_resp_phase_start = 1'b0;              // Write response phase start trigger
logic read_data_phase_start = 1'b0;               // Read data phase start trigger
logic clear_phase_latches = 1'b0;                 // Clear signal for phase completion latches

// Phase completion status signals
logic write_addr_phase_done = 1'b0;               // Write address phase completion flag
logic read_addr_phase_done = 1'b0;                // Read address phase completion flag
logic write_data_phase_done = 1'b0;               // Write data phase completion flag
logic write_resp_phase_done = 1'b0;               // Write response phase completion flag
logic read_data_phase_done = 1'b0;                // Read data phase completion flag

// Phase completion signal latches for synchronization
logic write_addr_phase_done_latched = 1'b0;       // Latched write address phase completion
logic read_addr_phase_done_latched = 1'b0;        // Latched read address phase completion
logic write_data_phase_done_latched = 1'b0;       // Latched write data phase completion
logic write_resp_phase_done_latched = 1'b0;       // Latched write response phase completion
logic read_data_phase_done_latched = 1'b0;        // Latched read data phase completion

// Clock and Reset signals
reg clk;                    // System clock signal
reg rst_n;                  // Active-low reset signal

// Clock generation (100MHz based on CLK_PERIOD parameter)
initial begin
    clk = 0;                                    // Initialize clock to low
    forever #(CLK_PERIOD/2) clk = ~clk;        // Generate clock with specified period
end

// Reset generation and initialization
initial begin
    rst_n = 0;                                  // Assert reset (active low)
    repeat(RESET_CYCLES) @(posedge clk);       // Hold reset for specified number of cycles
    #1;                                         // Small delay for stability
    rst_n = 1;                                  // Deassert reset
end

// Test stimulus generation and data processing functions
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
    
    // Calculate total weight for weighted random selection
    total_weight = 0;
    foreach (burst_config_weights[i]) begin
        total_weight += burst_config_weights[i].weight;
    end
    
            write_log($sformatf("Total weight for burst config: %0d", total_weight), LOG_ENABLE);
    
    // Generate test payloads using weighted random burst configuration selection
    for (test_count = 0; test_count < TOTAL_TEST_COUNT; test_count++) begin
        // Select burst configuration using weighted random
        selected_config_index = generate_weighted_random_index_burst_config(
            burst_config_weights, 
            total_weight
        );
        
        burst_cfg = burst_config_weights[selected_config_index];
        
        // Generate random burst length within selected configuration range
        selected_length = $urandom_range(burst_cfg.length_min, burst_cfg.length_max);
        selected_type = burst_cfg.burst_type;
        
        // Generate random transfer size (0=1byte, 1=2bytes, 2=4bytes for 32-bit bus)
        selected_size = $urandom_range(0, $clog2(AXI_DATA_WIDTH / 8));
        
        // Calculate test phase for logging and organization
        phase = test_count / PHASE_TEST_COUNT;
        
        // Generate random address offset within allocated address space
        random_offset = $urandom_range(0, TEST_COUNT_ADDR_SIZE_BYTES / 4 - 1);
        
        // Calculate burst size in bytes based on length and transfer size
        burst_size_bytes = (selected_length + 1) * (2 ** selected_size);
        
        // Align address to proper boundary based on burst type and size
        aligned_offset = align_address_to_boundary(random_offset, burst_size_bytes, selected_type, selected_size);
        
        // Calculate final base address with phase offset to prevent overlap
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
            test_count, selected_config_index, burst_cfg.weight, selected_type, selected_length, selected_size, 2**selected_size), DEBUG_LOG_ENABLE);
    end
    
            write_log($sformatf("Generated %0d Write Address Payloads (TOTAL_TEST_COUNT=%0d)", test_count, TOTAL_TEST_COUNT), LOG_ENABLE);
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
                valid: 1'b0,
                phase: payload.phase
            };
            stall_index++;
        end
    end
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
                AXI_DATA_WIDTH,
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
endfunction

function automatic void generate_write_data_payloads_with_stall();
    int stall_index = 0;
    int i;
    int total_weight;
    int selected_index;
    int stall_cycles;
    
    foreach (write_data_payloads[i]) begin
        write_data_payload_t payload = write_data_payloads[i];
        
        // Copy original payload to stall array
        write_data_payloads_with_stall[stall_index] = payload;
        stall_index++;
        
        // Generate stall cycles using weighted random selection
        total_weight = calculate_total_weight_generic(write_data_bubble_weights, write_data_bubble_weights.size());
        selected_index = generate_weighted_random_index_generic(write_data_bubble_weights, total_weight);
        stall_cycles = write_data_bubble_weights[selected_index].cycles;
        
        // Insert stall cycles with cleared signals
        for (int stall = 0; stall < stall_cycles; stall++) begin
            write_data_payloads_with_stall[stall_index] = '{
                test_count: payload.test_count,
                data: '0,        // Clear data when valid=0
                strb: '0,        // Clear strobe when valid=0
                last: 1'b0,      // Clear last flag when valid=0
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
            expected_strobe: write_data_payloads[i].strb,  // Copy strobe pattern for verification
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

// Weight calculation and random selection helper functions (avoid packed arrays for tool compatibility)
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

// AXI4 protocol and utility helper functions
function automatic logic [1:0] get_burst_type_value(input string burst_type);
    case (burst_type)
        "FIXED": return 2'b00;
        "INCR":  return 2'b01;
        "WRAP":  return 2'b10;
        default: return 2'b01;
    endcase
endfunction

function automatic int size_to_bytes(input logic [2:0] size);
    return (1 << size);
endfunction

function automatic string size_to_string(input logic [2:0] size);
    return $sformatf("%0d(%0d bytes)", size, size_to_bytes(size));
endfunction

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
            int size_bytes = 2 ** size;  // Calculate bytes based on SIZE field
            aligned_addr = (address / size_bytes) * size_bytes;
        end
        default: begin
            int size_bytes = 2 ** size;  // Calculate bytes based on SIZE field
            aligned_addr = (address / size_bytes) * size_bytes;
        end
    endcase
    return aligned_addr;
endfunction

function automatic bit check_read_data(
    input logic [AXI_DATA_WIDTH-1:0] actual_data,
    input logic [AXI_DATA_WIDTH-1:0] expected_data,
    input logic [AXI_STRB_WIDTH-1:0] expected_strobe
);
    bit check_result = 1'b1;
    int byte_idx;
    
    // Check only bytes that are enabled by strobe
    for (byte_idx = 0; byte_idx < AXI_STRB_WIDTH; byte_idx++) begin
        if (expected_strobe[byte_idx]) begin
            // Compare data for this enabled byte
            if (actual_data[byte_idx*8 +: 8] !== expected_data[byte_idx*8 +: 8]) begin
                check_result = 1'b0;
                $error("Byte %0d mismatch: expected=0x%02h, actual=0x%02h", 
                       byte_idx, expected_data[byte_idx*8 +: 8], actual_data[byte_idx*8 +: 8]);
            end
        end
    end
    
    return check_result;
endfunction

function automatic string get_burst_type_string(input logic [1:0] burst);
    case (burst)
        2'b00: return "FIXED";
        2'b01: return "INCR";
        2'b10: return "WRAP";
        default: return "INCR";
    endcase
endfunction

function automatic logic [AXI_STRB_WIDTH-1:0] generate_strobe_pattern(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input int data_width,
    input string burst_type
);
    logic [AXI_STRB_WIDTH-1:0] strobe_pattern = 0;
    int bus_width_bytes = data_width / 8;
    int burst_size_bytes = size_to_bytes(size);
    
    if (burst_type == "FIXED") begin
        // FIXED: Start from address offset within bus width
        int addr_offset = address % bus_width_bytes;
        int strobe_start = addr_offset;
        int strobe_end = strobe_start + burst_size_bytes - 1;
        
        // Check address and size consistency for FIXED transfers
        if (strobe_end >= bus_width_bytes) begin
            $error("FIXED transfer error: Address 0x%h with size %0d exceeds bus width %0d bytes. strobe_end=%0d", 
                   address, burst_size_bytes, bus_width_bytes, strobe_end);
            $finish;
        end
        
        // Generate STROBE pattern for FIXED transfer (byte-wise)
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
            // Cross boundary: wrap around to start of bus width
            strobe_end = strobe_end % bus_width_bytes;
            
            // Set strobe from start to end (wrapped around)
            for (int byte_idx = 0; byte_idx <= strobe_end; byte_idx++) begin
                strobe_pattern[byte_idx] = 1'b1;
            end
            for (int byte_idx = strobe_start; byte_idx < bus_width_bytes; byte_idx++) begin
                strobe_pattern[byte_idx] = 1'b1;
            end
        end else begin
            // No cross boundary: simple range within bus width
            for (int byte_idx = strobe_start; byte_idx <= strobe_end; byte_idx++) begin
                strobe_pattern[byte_idx] = 1'b1;
            end
        end
    end
    
    return strobe_pattern;
endfunction

// Ready negate pulse array initialization function
function automatic void initialize_ready_negate_pulses();
    int i;
    int total_weight;
    int selected_index;
    int negate_cycles;
    
    for (i = 0; i < READY_NEGATE_ARRAY_LENGTH; i = i + 1) begin
        // Generate read data ready negate pulses using weighted random selection
        total_weight = calculate_total_weight_generic(axi_r_ready_negate_weights, axi_r_ready_negate_weights.size());
        selected_index = generate_weighted_random_index_generic(axi_r_ready_negate_weights, total_weight);
        negate_cycles = axi_r_ready_negate_weights[selected_index].cycles;
        axi_r_ready_negate_pulses[i] = (negate_cycles > 0) ? 1'b1 : 1'b0;
        
        // Generate write response ready negate pulses using weighted random selection
        total_weight = calculate_total_weight_generic(axi_b_ready_negate_weights, axi_b_ready_negate_weights.size());
        selected_index = generate_weighted_random_index_generic(axi_b_ready_negate_weights, total_weight);
        negate_cycles = axi_b_ready_negate_weights[selected_index].cycles;
        axi_b_ready_negate_pulses[i] = (negate_cycles > 0) ? 1'b1 : 1'b0;
    end
endfunction

// Test data display and verification functions
function automatic void display_write_addr_payloads();
            write_log("=== Write Address Payloads ===", LOG_ENABLE);
    foreach (write_addr_payloads[i]) begin
        write_addr_payload_t payload = write_addr_payloads[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.addr, payload.burst, size_to_string(payload.size), payload.id, payload.len, payload.valid, payload.phase), DEBUG_LOG_ENABLE);
    end
endfunction

function automatic void display_write_addr_payloads_with_stall();
            write_log("=== Write Address Payloads with Stall ===", LOG_ENABLE);
    foreach (write_addr_payloads_with_stall[i]) begin
        write_addr_payload_t payload = write_addr_payloads_with_stall[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.addr, payload.burst, size_to_string(payload.size), payload.id, payload.len, payload.valid, payload.phase), DEBUG_LOG_ENABLE);
    end
endfunction

function automatic void display_write_data_payloads();
            write_log("=== Write Data Payloads ===", LOG_ENABLE);
    foreach (write_data_payloads[i]) begin
        write_data_payload_t payload = write_data_payloads[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.data, payload.strb, payload.last, payload.valid, payload.phase), DEBUG_LOG_ENABLE);
    end
endfunction

function automatic void display_write_data_payloads_with_stall();
            write_log("=== Write Data Payloads with Stall ===", LOG_ENABLE);
    foreach (write_data_payloads_with_stall[i]) begin
        write_data_payload_t payload = write_data_payloads_with_stall[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.data, payload.strb, payload.last, payload.valid, payload.phase), DEBUG_LOG_ENABLE);
    end
endfunction

function automatic void display_read_addr_payloads();
            write_log("=== Read Address Payloads ===", LOG_ENABLE);
    foreach (read_addr_payloads[i]) begin
        read_addr_payload_t payload = read_addr_payloads[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.addr, payload.burst, size_to_string(payload.size), payload.id, payload.len, payload.valid, payload.phase), DEBUG_LOG_ENABLE);
    end
endfunction

function automatic void display_read_addr_payloads_with_stall();
            write_log("=== Read Address Payloads with Stall ===", LOG_ENABLE);
    foreach (read_addr_payloads_with_stall[i]) begin
        read_addr_payload_t payload = read_addr_payloads_with_stall[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.addr, payload.burst, size_to_string(payload.size), payload.id, payload.len, payload.valid, payload.phase), DEBUG_LOG_ENABLE);
    end
endfunction

function automatic void display_read_data_expected();
            write_log("=== Read Data Expected ===", LOG_ENABLE);
    foreach (read_data_expected[i]) begin
        read_data_expected_t expected = read_data_expected[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, expected_data=0x%h, expected_strobe=0x%h, phase=%0d",
            i, expected.test_count, expected.expected_data, expected.expected_strobe, expected.phase), DEBUG_LOG_ENABLE);
    end
endfunction

function automatic void display_write_resp_expected();
            write_log("=== Write Response Expected ===", LOG_ENABLE);
    foreach (write_resp_expected[i]) begin
        write_resp_expected_t expected = write_resp_expected[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, expected_resp=%0d, expected_id=%0d, phase=%0d",
            i, expected.test_count, expected.expected_resp, expected.expected_id, expected.phase), DEBUG_LOG_ENABLE);
    end
endfunction

function automatic void display_all_arrays();
            write_log("=== Displaying All Generated Test Arrays ===", LOG_ENABLE);
    display_write_addr_payloads();
    display_write_addr_payloads_with_stall();
    display_write_data_payloads();
    display_write_data_payloads_with_stall();
    display_read_addr_payloads();
    display_read_addr_payloads_with_stall();
    display_read_data_expected();
    display_write_resp_expected();
            write_log("=== All Test Arrays Displayed Successfully ===", LOG_ENABLE);
endfunction

// Device Under Test (DUT) instantiation - AXI4 Simple Dual Port RAM
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


// Time 0: Generate all test stimulus and expected values
initial begin
    // Generate write address channel payloads (basic and with stall cycles)
    generate_write_addr_payloads();
    generate_write_addr_payloads_with_stall();
    
    // Generate write data channel payloads (basic and with stall cycles)
    generate_write_data_payloads();
    generate_write_data_payloads_with_stall();
    
    // Generate read address channel payloads (basic and with stall cycles)
    generate_read_addr_payloads();
    generate_read_addr_payloads_with_stall();
    
    // Generate read data channel expected values for verification
    generate_read_data_expected();
    
    // Generate write response channel expected values for verification
    generate_write_resp_expected();
    
    // Initialize ready signal negate pulse arrays for backpressure testing
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
    
    // Display all generated test arrays for verification
    display_all_arrays();
    
    // Display array size verification and consistency checks
            write_log($sformatf("Array Size Verification:"), LOG_ENABLE);
        write_log($sformatf("  Write Address Payloads: %0d", write_addr_payloads.size()), LOG_ENABLE);
        write_log($sformatf("  Write Data Payloads: %0d (should match total burst transfers)", write_data_payloads.size()), LOG_ENABLE);
        write_log($sformatf("  Read Address Payloads: %0d", read_addr_payloads.size()), LOG_ENABLE);
        write_log($sformatf("  Read Data Expected: %0d (should match write data count)", read_data_expected.size()), LOG_ENABLE);
        write_log($sformatf("  Write Response Expected: %0d", write_resp_expected.size()), LOG_ENABLE);
    
    // Set completion flag to indicate stimulus generation is done
    #1;
    generate_stimulus_expected_done = 1'b1;
end

// Test scenario control and phase management
initial begin
    
    // Initialize phase control signals to default values
    current_phase = 8'd0;
    write_addr_phase_start = 1'b0;
    read_addr_phase_start = 1'b0;
    write_data_phase_start = 1'b0;
    read_data_phase_start = 1'b0;
    
    // Wait for stimulus generation completion before starting test execution
    wait(generate_stimulus_expected_done);
    $display("Phase %0d: Stimulus and Expected Values Generation Confirmed", current_phase);
    
    // Wait for reset deassertion to ensure stable system state
    wait(rst_n);
    $display("Phase %0d: Reset Deassertion Confirmed", current_phase);
    
    // Start first phase (write operations only - no read operations)
    repeat(2) @(posedge clk);
    #1;
    write_addr_phase_start = 1'b1;
    write_data_phase_start = 1'b1;
    write_resp_phase_start = 1'b1;
    
    @(posedge clk);
    #1;
    write_addr_phase_start = 1'b0;
    write_data_phase_start = 1'b0;
    write_resp_phase_start = 1'b0;
    
    // Wait for first phase completion (all write channels must complete)
    wait(write_addr_phase_done_latched && write_data_phase_done_latched && write_resp_phase_done_latched);
    
    $display("Phase %0d: All Write Channels Completed", current_phase);
    
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b1;  // Assert clear signal for phase completion
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b0;  // Deassert clear signal
        
    current_phase = current_phase + 8'd1;
    
    // Main phase control loop for mixed read/write operations
    for (int phase = 0; phase < (TOTAL_TEST_COUNT / PHASE_TEST_COUNT) - 1; phase++) begin
        @(posedge clk);
        #1;
        // Start all channels simultaneously for concurrent operation
        write_addr_phase_start = 1'b1;
        read_addr_phase_start = 1'b1;
        write_data_phase_start = 1'b1;
        write_resp_phase_start = 1'b1;
        read_data_phase_start = 1'b1;
        
        @(posedge clk);
        #1;
        // Deassert start signals after one clock cycle
        write_addr_phase_start = 1'b0;
        read_addr_phase_start = 1'b0;
        write_data_phase_start = 1'b0;
        write_resp_phase_start = 1'b0;
        read_data_phase_start = 1'b0;
        
        // Wait for all channels completion before proceeding to next phase
        wait(write_addr_phase_done_latched && read_addr_phase_done_latched && 
             write_data_phase_done_latched && write_resp_phase_done_latched && read_data_phase_done_latched);
        
        $display("Phase %0d: All Channels Completed", current_phase);
        
        @(posedge clk);
        #1;
        clear_phase_latches = 1'b1;  // Assert clear signal for phase completion
        @(posedge clk);
        #1;
        clear_phase_latches = 1'b0;  // Deassert clear signal
        
        current_phase = current_phase + 8'd1;
    end
    
    // Final phase (read operations only to verify written data)
    @(posedge clk);
    #1;
    read_addr_phase_start = 1'b1;
    read_data_phase_start = 1'b1;
    
    @(posedge clk);
    #1;
    read_addr_phase_start = 1'b0;
    read_data_phase_start = 1'b0;
    
    // Wait for final phase completion (read channels only)
    wait(read_addr_phase_done_latched && read_data_phase_done_latched);
    
    $display("Phase %0d: All Read Channels Completed", current_phase);
    
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b1;  // Assert clear signal for final phase
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b0;  // Deassert clear signal
        
    // All phases completed successfully
    $display("All Phases Completed. Test Scenario Finished Successfully.");
    test_execution_completed = 1'b1;  // Set test completion flag
    #1; // Wait for test completion log to be written
    $finish;
end

// Phase completion signal latches for synchronization and control
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
        write_resp_phase_done_latched <= 1'b0;
        read_data_phase_done_latched <= 1'b0;
    end else begin
        if (write_addr_phase_done) write_addr_phase_done_latched <= 1'b1;
        if (read_addr_phase_done) read_addr_phase_done_latched <= 1'b1;
        if (write_data_phase_done) write_data_phase_done_latched <= 1'b1;
        if (write_resp_phase_done) write_resp_phase_done_latched <= 1'b1;
        if (read_data_phase_done) read_data_phase_done_latched <= 1'b1;
    end
end

// Write Address Channel Control Circuit
typedef enum logic [1:0] {
    WRITE_ADDR_IDLE,        // Idle state waiting for phase start
    WRITE_ADDR_ACTIVE,      // Active state (includes stall handling)
    WRITE_ADDR_FINISH       // Finish processing state
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
                    write_addr_phase_done <= 1'b0;
                end
            end
            
            WRITE_ADDR_ACTIVE: begin
                // Priority: Check ready signal first
                if (axi_aw_ready) begin
                    // Check array bounds
                    if (write_addr_array_index < write_addr_payloads_with_stall.size()) begin
                        // Get payload from array
                        automatic write_addr_payload_t payload = write_addr_payloads_with_stall[write_addr_array_index];
                        
                      
                        // Check if address transmission is complete (when axi_aw_valid is asserted)
                        if (axi_aw_valid) begin
                            // Check phase completion using current counter value
                            if (write_addr_phase_counter < PHASE_TEST_COUNT - 1) begin
                                axi_aw_addr <= payload.addr;
                                axi_aw_burst <= payload.burst;
                                axi_aw_size <= payload.size;
                                axi_aw_id <= payload.id;
                                axi_aw_len <= payload.len;
                                axi_aw_valid <= payload.valid;

                                // Debug output for address transmission
                                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                    write_debug_log($sformatf("Write Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                        write_addr_array_index, payload.test_count, payload.addr, payload.burst, 
                                        payload.size, payload.id, payload.len, payload.valid), DEBUG_LOG_ENABLE);
                                end

                                // Update array index for next payload
                                write_addr_array_index <= write_addr_array_index + 1;

                                // Phase continues: increment counter
                                write_addr_phase_counter <= write_addr_phase_counter + 8'd1;
                                write_debug_log($sformatf("Write Addr Phase: Address sent, counter=%0d/%0d", 
                                    write_addr_phase_counter + 1, PHASE_TEST_COUNT), DEBUG_LOG_ENABLE);
                            end else begin
                                // Phase completed: clear all signals
                                axi_aw_addr <= '0;
                                axi_aw_burst <= '0;
                                axi_aw_size <= '0;
                                axi_aw_id <= '0;
                                axi_aw_len <= '0;
                                axi_aw_valid <= 1'b0;
                                
                                // State transition to finish
                                write_addr_state <= WRITE_ADDR_FINISH;
                                write_addr_phase_done <= 1'b1;
                                
                                write_debug_log("Write Addr Phase: Phase completed, all signals cleared", DEBUG_LOG_ENABLE);
                            end
                        end else begin
                            // Set address signals for transmission
                            axi_aw_addr <= payload.addr;
                            axi_aw_burst <= payload.burst;
                            axi_aw_size <= payload.size;
                            axi_aw_id <= payload.id;
                            axi_aw_len <= payload.len;
                            axi_aw_valid <= payload.valid;

                            // Debug output for signal setting
                            if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                write_debug_log($sformatf("Write Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                    write_addr_array_index, payload.test_count, payload.addr, payload.burst, 
                                    payload.size, payload.id, payload.len, payload.valid), DEBUG_LOG_ENABLE);
                            end

                            // Update array index for next payload
                            write_addr_array_index <= write_addr_array_index + 1;
                        end
                    end else begin
                        // Array end reached: clear all signals and complete phase
                        axi_aw_addr <= '0;
                        axi_aw_burst <= '0;
                        axi_aw_size <= '0;
                        axi_aw_id <= '0;
                        axi_aw_len <= '0;
                        axi_aw_valid <= 1'b0;
                        
                        write_addr_state <= WRITE_ADDR_FINISH;
                        write_addr_phase_done <= 1'b1;
                        
                        write_debug_log("Write Addr Phase: Array end reached, all signals cleared", DEBUG_LOG_ENABLE);
                    end
                end
                // When axi_aw_ready = 0, do nothing (maintain current signals)
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
    READ_ADDR_IDLE,        // Idle state waiting for phase start
    READ_ADDR_ACTIVE,      // Active state (includes stall handling)
    READ_ADDR_FINISH       // Finish processing state
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
                    read_addr_phase_done <= 1'b0;
                end
            end
            
            READ_ADDR_ACTIVE: begin
                // Priority: Check ready signal first
                if (axi_ar_ready) begin
                    // Check array bounds
                    if (read_addr_array_index < read_addr_payloads_with_stall.size()) begin
                        // Get payload from array
                        automatic read_addr_payload_t payload = read_addr_payloads_with_stall[read_addr_array_index];
                        
                        // Check if address transmission is complete (when axi_ar_valid is asserted)
                        if (axi_ar_valid) begin
                            // Check phase completion using current counter value
                            if (read_addr_phase_counter < PHASE_TEST_COUNT - 1) begin
                                axi_ar_addr <= payload.addr;
                                axi_ar_burst <= payload.burst;
                                axi_ar_size <= payload.size;
                                axi_ar_id <= payload.id;
                                axi_ar_len <= payload.len;
                                axi_ar_valid <= payload.valid;

                                // Debug output for address transmission
                                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                    write_debug_log($sformatf("Read Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                        read_addr_array_index, payload.test_count, payload.addr, payload.burst, 
                                        payload.size, payload.id, payload.len, payload.valid), DEBUG_LOG_ENABLE);
                                end

                                // Update array index for next payload
                                read_addr_array_index <= read_addr_array_index + 1;

                                // Phase continues: increment counter
                                read_addr_phase_counter <= read_addr_phase_counter + 8'd1;
                                write_debug_log($sformatf("Read Addr Phase: Address sent, counter=%0d/%0d", 
                                    read_addr_phase_counter + 1, PHASE_TEST_COUNT), DEBUG_LOG_ENABLE);
                            end else begin
                                // Phase completed: clear all signals
                                axi_ar_addr <= '0;
                                axi_ar_burst <= '0;
                                axi_ar_size <= '0;
                                axi_ar_id <= '0;
                                axi_ar_len <= '0;
                                axi_ar_valid <= 1'b0;
                                
                                // State transition to finish
                                read_addr_state <= READ_ADDR_FINISH;
                                read_addr_phase_done <= 1'b1;
                                
                                write_debug_log("Read Addr Phase: Phase completed, all signals cleared", DEBUG_LOG_ENABLE);
                            end
                        end else begin
                            // Set address signals for next payload
                            axi_ar_addr <= payload.addr;
                            axi_ar_burst <= payload.burst;
                            axi_ar_size <= payload.size;
                            axi_ar_id <= payload.id;
                            axi_ar_len <= payload.len;
                            axi_ar_valid <= payload.valid;

                            // Debug output for signal setting
                            if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                write_debug_log($sformatf("Read Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                    read_addr_array_index, payload.test_count, payload.addr, payload.burst, 
                                    payload.size, payload.id, payload.len, payload.valid), DEBUG_LOG_ENABLE);
                            end

                            // Update array index for next payload
                            read_addr_array_index <= read_addr_array_index + 1;
                        end
                    end else begin
                        // Array end reached: clear all signals and complete phase
                        axi_ar_addr <= '0;
                        axi_ar_burst <= '0;
                        axi_ar_size <= '0;
                        axi_ar_id <= '0;
                        axi_ar_len <= '0;
                        axi_ar_valid <= 1'b0;
                        
                        read_addr_state <= READ_ADDR_FINISH;
                        read_addr_phase_done <= 1'b1;
                        
                        write_debug_log("Read Addr Phase: Array end reached, all signals cleared", DEBUG_LOG_ENABLE);
                    end
                end
                // When axi_ar_ready = 0, do nothing (maintain current signals)
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
    WRITE_DATA_IDLE,        // Idle state waiting for phase start
    WRITE_DATA_ACTIVE,      // Active state (includes stall handling)
    WRITE_DATA_FINISH       // Finish processing state
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
                    write_data_phase_done <= 1'b0;
                end
            end
            
            WRITE_DATA_ACTIVE: begin
                // Priority: Check ready signal first
                if (axi_w_ready) begin
                    // Check array bounds
                    if (write_data_array_index < write_data_payloads_with_stall.size()) begin
                        // Get payload (before updating array index)
                        automatic write_data_payload_t payload = write_data_payloads_with_stall[write_data_array_index];
                        
                        // Check phase completion (when axi_w_last is asserted)
                        if (axi_w_last) begin
                            // Check phase completion using current counter value
                            if (write_data_phase_counter < PHASE_TEST_COUNT - 1) begin
                                axi_w_data <= payload.data;
                                axi_w_strb <= payload.strb;
                                axi_w_last <= payload.last;
                                axi_w_valid <= payload.valid;
                                write_data_array_index <= write_data_array_index + 1;

                                // Debug output for data transmission
                                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                    write_debug_log($sformatf("Write Data[%0d]: test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d", 
                                        write_data_array_index, payload.test_count, payload.data, payload.strb, 
                                        payload.last, payload.valid), DEBUG_LOG_ENABLE);
                                end

                                write_data_phase_counter <= write_data_phase_counter + 8'd1;
                                write_debug_log($sformatf("Write Data Phase: Burst completed, counter=%0d/%0d", 
                                    write_data_phase_counter + 1, PHASE_TEST_COUNT), DEBUG_LOG_ENABLE);
                            end else begin
                                // Phase completed: clear all signals
                                axi_w_data <= '0;
                                axi_w_strb <= '0;
                                axi_w_last <= 1'b0;
                                axi_w_valid <= 1'b0;
                                
                                // State transition to finish
                                write_data_state <= WRITE_DATA_FINISH;
                                write_data_phase_done <= 1'b1;
                                
                                write_debug_log("Write Data Phase: Phase completed, all signals cleared", DEBUG_LOG_ENABLE);
                            end
                        end else begin
                            // Set data signals for next payload
                            axi_w_data <= payload.data;
                            axi_w_strb <= payload.strb;
                            axi_w_last <= payload.last;
                            axi_w_valid <= payload.valid;

                            // Debug output for signal setting
                            if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                write_debug_log($sformatf("Write Data[%0d]: test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d", 
                                    write_data_array_index, payload.test_count, payload.data, payload.strb, 
                                    payload.last, payload.valid), DEBUG_LOG_ENABLE);
                            end

                            write_data_array_index <= write_data_array_index + 1;
                        end
                    end else begin
                        // Array end reached: clear all signals and complete phase
                        axi_w_data <= '0;
                        axi_w_strb <= '0;
                        axi_w_last <= 1'b0;
                        axi_w_valid <= 1'b0;
                        
                        write_data_state <= WRITE_DATA_FINISH;
                        write_data_phase_done <= 1'b1;
                        
                        write_debug_log("Write Data Phase: Array end reached, all signals cleared", DEBUG_LOG_ENABLE);
                    end
                end
                // When axi_w_ready = 0, do nothing (maintain current signals)
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
    READ_DATA_IDLE,        // Idle state waiting for phase start
    READ_DATA_ACTIVE,      // Active state (includes expected value verification)
    READ_DATA_FINISH       // Finish processing state
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
    end else begin
        case (read_data_state)
            READ_DATA_IDLE: begin
                if (read_data_phase_start) begin
                    read_data_state <= READ_DATA_ACTIVE;
                    read_data_phase_busy <= 1'b1;
                    read_data_phase_counter <= 8'd0;
                    read_data_phase_done <= 1'b0;
                end
            end
            
            READ_DATA_ACTIVE: begin
                // Priority: Check valid signal first
                if (axi_r_valid && axi_r_ready) begin
                    // Check array bounds
                    if (read_data_array_index < read_data_expected.size()) begin
                        // Get expected value from array
                        automatic read_data_expected_t expected = read_data_expected[read_data_array_index];
                        
                        // Check burst completion (when last=1)
                        if (axi_r_last) begin
                            // Check phase completion using current counter value
                            if (read_data_phase_counter < PHASE_TEST_COUNT - 1) begin
                                // Data verification (only bytes enabled by strobe)
                                if (!check_read_data(axi_r_data, expected.expected_data, expected.expected_strobe)) begin
                                    $error("Read Data Mismatch at index %0d: Expected 0x%h, Got 0x%h", 
                                        read_data_array_index, expected.expected_data, axi_r_data);
                                    $finish;
                                end
                        
                                // Debug output for data verification
                                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                    write_debug_log($sformatf("Read Data[%0d]: test_count=%0d, data=0x%h, expected=0x%h, expected_strobe=0x%h, last=%0d", 
                                        read_data_array_index, expected.test_count, axi_r_data, expected.expected_data, expected.expected_strobe, axi_r_last), DEBUG_LOG_ENABLE);
                                end

                                // Update array index for next expected value
                                read_data_array_index <= read_data_array_index + 1;

                                // Phase continues: increment counter
                                read_data_phase_counter <= read_data_phase_counter + 8'd1;
                                write_debug_log($sformatf("Read Data Phase: Burst completed, counter=%0d/%0d", 
                                    read_data_phase_counter + 1, PHASE_TEST_COUNT), DEBUG_LOG_ENABLE);
                            end else begin
                                // Phase completed: clear all signals

                                // Update array index for next expected value
                                read_data_array_index <= read_data_array_index + 1;

                                // State transition to finish
                                read_data_state <= READ_DATA_FINISH;
                                read_data_phase_done <= 1'b1;
                                
                                write_debug_log("Read Data Phase: Phase completed, all signals cleared", DEBUG_LOG_ENABLE);
                            end
                        end else begin
                            // Data verification (only bytes enabled by strobe)
                            if (!check_read_data(axi_r_data, expected.expected_data, expected.expected_strobe)) begin
                                $error("Read Data Mismatch at index %0d: Expected 0x%h, Got 0x%h", 
                                       read_data_array_index, expected.expected_data, axi_r_data);
                                $finish;
                            end
                        
                            // Debug output for data verification
                            if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                write_debug_log($sformatf("Read Data[%0d]: test_count=%0d, data=0x%h, expected=0x%h, expected_strobe=0x%h, last=%0d", 
                                    read_data_array_index, expected.test_count, axi_r_data, expected.expected_data, expected.expected_strobe, axi_r_last), DEBUG_LOG_ENABLE);
                            end

                            // Update array index for next expected value
                            read_data_array_index <= read_data_array_index + 1;
                        end
                    end else begin
                        // Array end reached: clear all signals and complete phase
                        
                        read_data_state <= READ_DATA_FINISH;
                        read_data_phase_done <= 1'b1;
                        
                        write_debug_log("Read Data Phase: Array end reached, all signals cleared", DEBUG_LOG_ENABLE);
                    end
                end
                // When axi_r_valid = 0 or axi_r_ready = 0, do nothing (maintain current signals)
            end
            
            READ_DATA_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                read_data_phase_done <= 1'b0;
                read_data_phase_busy <= 1'b0;
                read_data_state <= READ_DATA_IDLE;
            end
        endcase
    end
end

// Protocol Verification System for AXI4 compliance checking
// 1-clock delayed signals for payload hold verification
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

// 1-clock delay circuit for signal comparison
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
            // Check if payload changed while Ready was negated
            if (axi_aw_addr !== axi_aw_addr_delayed) begin
                $error("Write Address Channel: Address changed while Ready was negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_aw_addr, axi_aw_addr_delayed);
                $finish;
            end
            if (axi_aw_burst !== axi_aw_burst_delayed) begin
                $error("Write Address Channel: Burst changed while Ready was negated. Current: %0d, Delayed: %0d", 
                       axi_aw_burst, axi_aw_burst_delayed);
                $finish;
            end
            if (axi_aw_size !== axi_aw_size_delayed) begin
                $error("Write Address Channel: Size changed while Ready was negated. Current: %0d, Delayed: %0d", 
                       axi_aw_size, axi_aw_size_delayed);
                $finish;
            end
            if (axi_aw_id !== axi_aw_id_delayed) begin
                $error("Write Address Channel: ID changed while Ready was negated. Current: %0d, Delayed: %0d", 
                       axi_aw_id, axi_aw_id_delayed);
                $finish;
            end
            if (axi_aw_len !== axi_aw_len_delayed) begin
                $error("Write Address Channel: Length changed while Ready was negated. Current: %0d, Delayed: %0d", 
                       axi_aw_len, axi_aw_len_delayed);
                $finish;
            end
            if (axi_aw_valid !== axi_aw_valid_delayed) begin
                $error("Write Address Channel: Valid changed while Ready was negated. Current: %0d, Delayed: %0d", 
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
                $error("Write Data Channel: Data changed while Ready was negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_w_data, axi_w_data_delayed);
                $finish;
            end
            if (axi_w_strb !== axi_w_strb_delayed) begin
                $error("Write Data Channel: Strobe changed while Ready was negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_w_strb, axi_w_strb_delayed);
                $finish;
            end
            if (axi_w_last !== axi_w_last_delayed) begin
                $error("Write Data Channel: Last changed while Ready was negated. Current: %0d, Delayed: %0d", 
                       axi_w_last, axi_w_last_delayed);
                $finish;
            end
            if (axi_w_valid !== axi_w_valid_delayed) begin
                $error("Write Data Channel: Valid changed while Ready was negated. Current: %0d, Delayed: %0d", 
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
                $error("Read Address Channel: Address changed while Ready was negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_ar_addr, axi_ar_addr_delayed);
                $finish;
            end
            if (axi_ar_burst !== axi_ar_burst_delayed) begin
                $error("Read Address Channel: Burst changed while Ready was negated. Current: %0d, Delayed: %0d", 
                       axi_ar_burst, axi_ar_burst_delayed);
                $finish;
            end
            if (axi_ar_size !== axi_ar_size_delayed) begin
                $error("Read Address Channel: Size changed while Ready was negated. Current: %0d, Delayed: %0d", 
                       axi_ar_size, axi_ar_size_delayed);
                $finish;
            end
            if (axi_ar_id !== axi_ar_id_delayed) begin
                $error("Read Address Channel: ID changed while Ready was negated. Current: %0d, Delayed: %0d", 
                       axi_ar_id, axi_ar_id_delayed);
                $finish;
            end
            if (axi_ar_len !== axi_ar_len_delayed) begin
                $error("Read Address Channel: Length changed while Ready was negated. Current: %0d, Delayed: %0d", 
                       axi_ar_len, axi_ar_len_delayed);
                $finish;
            end
            if (axi_ar_valid !== axi_ar_valid_delayed) begin
                $error("Read Address Channel: Valid changed while Ready was negated. Current: %0d, Delayed: %0d", 
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
                $error("Read Data Channel: Data changed while Ready was negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_r_data, axi_r_data_delayed);
                $finish;
            end
            if (axi_r_id !== axi_r_id_delayed) begin
                $error("Read Data Channel: ID changed while Ready was negated. Current: %0d, Delayed: %0d", 
                       axi_r_id, axi_r_id_delayed);
                $finish;
            end
            if (axi_r_resp !== axi_r_resp_delayed) begin
                $error("Read Data Channel: Response changed while Ready was negated. Current: %0d, Delayed: %0d", 
                       axi_r_resp, axi_r_resp_delayed);
                $finish;
            end
            if (axi_r_last !== axi_r_last_delayed) begin
                $error("Read Data Channel: Last changed while Ready was negated. Current: %0d, Delayed: %0d", 
                       axi_r_last, axi_r_last_delayed);
                $finish;
            end
            if (axi_r_valid !== axi_r_valid_delayed) begin
                $error("Read Data Channel: Valid changed while Ready was negated. Current: %0d, Delayed: %0d", 
                       axi_r_valid, axi_r_valid_delayed);
                $finish;
            end
        end
    end
end

// Test completion monitoring
initial begin
        // Wait for stimulus generation completion
        wait(generate_stimulus_expected_done);
        
        // Wait for test execution completion
        wait(test_execution_completed);
end

// Ready negate control logic
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ready_negate_index <= 0;
        // axi_aw_ready and axi_w_ready are controlled by DUT (wire signals)
        axi_r_ready <= 1'b1;
        axi_b_ready <= 1'b1;
    end else begin
        // Update ready negate index for cycling through pulse arrays
        if (ready_negate_index >= READY_NEGATE_ARRAY_LENGTH - 1) begin
            ready_negate_index <= 0;  // Reset to 0 when reaching maximum array length
        end else begin
            ready_negate_index <= ready_negate_index + 1;
        end
        
        // Control ready signals based on pulse arrays for backpressure testing
        // Note: axi_aw_ready and axi_w_ready are controlled by DUT (wire signals)
        //       axi_r_ready and axi_b_ready are controlled by TB for testing purposes
        axi_r_ready <= !axi_r_ready_negate_pulses[ready_negate_index];
        axi_b_ready <= !axi_b_ready_negate_pulses[ready_negate_index];
    end
end

// Write Response Channel Control Circuit
typedef enum logic [1:0] {
    WRITE_RESP_IDLE,        // Idle state waiting for phase start
    WRITE_RESP_ACTIVE,      // Active state (includes response verification)
    WRITE_RESP_FINISH       // Finish processing state
} write_resp_state_t;

write_resp_state_t write_resp_state = WRITE_RESP_IDLE;
logic [7:0] write_resp_phase_counter = 8'd0;
logic write_resp_phase_busy = 1'b0;
int write_resp_array_index = 0;

// Write Response Channel Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_resp_state <= WRITE_RESP_IDLE;
        write_resp_phase_counter <= 8'd0;
        write_resp_phase_busy <= 1'b0;
        write_resp_phase_done <= 1'b0;
        write_resp_array_index <= 0;
        
        // AXI4 signals
    end else begin
        case (write_resp_state)
            WRITE_RESP_IDLE: begin
                if (write_resp_phase_start) begin
                    write_resp_state <= WRITE_RESP_ACTIVE;
                    write_resp_phase_busy <= 1'b1;
                    write_resp_phase_counter <= 8'd0;
                    write_resp_array_index <= 0;
                    write_resp_phase_done <= 1'b0;
                    
                    // Debug output
                    write_log("Phase 0: Write Response Channel started", LOG_ENABLE);
                end
            end
            
            WRITE_RESP_ACTIVE: begin
                // Debug output for state transition
                if (LOG_ENABLE && DEBUG_LOG_ENABLE && !write_resp_phase_busy) begin
                    $display("[%0t] [DEBUG] Write Resp Phase: State transition to ACTIVE", $time);
                    write_resp_phase_busy <= 1'b1;
                end
                
                // Priority: Check valid signal first
                if (axi_b_valid && axi_b_ready) begin
                    // Search for expected value based on ID
                    automatic int found_index = -1;
                    automatic int i;
                    foreach (write_resp_expected[i]) begin
                        if (write_resp_expected[i].expected_id === axi_b_id) begin
                            found_index = i;
                            break;
                        end
                    end
                    
                    if (found_index >= 0) begin
                        // Get expected value from array
                        automatic write_resp_expected_t expected = write_resp_expected[found_index];
                        
                        // Verify response value
                        if (axi_b_resp !== expected.expected_resp) begin
                            $error("Write Response Mismatch: Expected %0d, Got %0d for ID %0d", 
                                   expected.expected_resp, axi_b_resp, axi_b_id);
                            $finish;
                        end
                        
                        // Debug output for response verification
                        if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                            $display("[%0t] [DEBUG] Write Response: ID=%0d, Resp=%0d, Expected=%0d", 
                                $time, axi_b_id, axi_b_resp, expected.expected_resp);
                        end
                        
                        // Check phase completion using current counter value
                        if (write_resp_phase_counter < PHASE_TEST_COUNT - 1) begin
                            // Phase continues: increment counter
                            write_resp_phase_counter <= write_resp_phase_counter + 8'd1;
                            $display("[%0t] [DEBUG] Write Resp Phase: Response received, counter=%0d/%0d", 
                                $time, write_resp_phase_counter + 1, PHASE_TEST_COUNT);
                        end else begin
                            // Phase completed: clear all signals
                            
                            // State transition to finish
                            write_resp_state <= WRITE_RESP_FINISH;
                            write_resp_phase_done <= 1'b1;
                            
                            $display("[%0t] [DEBUG] Write Resp Phase: Phase completed, all signals cleared", $time);
                        end
                    end else begin
                        $error("Write Response: No expected value found for ID %0d", axi_b_id);
                        $finish;
                    end
                end
                // When axi_b_valid = 0 or axi_b_ready = 0, do nothing (maintain current signals)
            end
            
            WRITE_RESP_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                write_resp_phase_done <= 1'b0;
                write_resp_phase_busy <= 1'b0;
                write_resp_state <= WRITE_RESP_IDLE;
                
                // Debug output
                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                    $display("[%0t] [DEBUG] Write Resp Phase: State transition to FINISH", $time);
                end
            end
        endcase
    end
end

// AXI4 Logger module instantiation
axi_logger logger_inst();

endmodule
