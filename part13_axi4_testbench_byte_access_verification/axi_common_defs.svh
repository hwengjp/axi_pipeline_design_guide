// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// AXI4 Common Definitions Header File
// This file contains all common parameters and type definitions for the testbench

`ifndef AXI_COMMON_DEFS_SVH
`define AXI_COMMON_DEFS_SVH

// =============================================================================
// TOP hierarchy access definition for sub-modules
// =============================================================================
`define TOP_TB top_tb

// =============================================================================
// Log control parameters
// =============================================================================
parameter LOG_ENABLE = 1'b1;                  // Enable general logging
//parameter DEBUG_LOG_ENABLE = 1'b1;            // Enable debug logging
parameter DEBUG_LOG_ENABLE = 1'b0;            // Enable debug logging
parameter BYTE_VERIFICATION_ENABLE = 1'b1;     // Byte verification mode enable

// =============================================================================
// Testbench parameters
// =============================================================================
parameter TOTAL_TEST_COUNT = 800;              // Total test count
parameter PHASE_TEST_COUNT = 8;                // Tests per phase
//parameter TOTAL_TEST_COUNT = 20;             // Total test count (commented)
//parameter PHASE_TEST_COUNT = 4;              // Tests per phase (commented)

parameter MEMORY_SIZE_BYTES = 33554432;        // 32MB
parameter AXI_DATA_WIDTH = 32;                 // 32bit
parameter AXI_ID_WIDTH = 8;                    // 8bit ID
parameter TEST_COUNT_ADDR_SIZE_BYTES = 4096;   // Address size per test count
parameter VERIFICATION_TIMEOUT_CYCLES = 1000000; // Verification timeout cycles for entire testbench
parameter CLK_PERIOD = 10;                     // 10ns period
parameter RESET_CYCLES = 4;                    // Reset cycles

// =============================================================================
// Derived parameters
// =============================================================================
parameter AXI_ADDR_WIDTH = $clog2(MEMORY_SIZE_BYTES); // Calculated address width
parameter AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;        // Strobe width (1 bit per byte)

// =============================================================================
// Ready negate control parameters
// =============================================================================
parameter READY_NEGATE_ARRAY_LENGTH = 1000;    // Length of ready negate pulse array

// =============================================================================
// Weighted random generation structures
// =============================================================================
typedef struct {
    int weight;                                // Weight for random selection
    int length_min;                            // Minimum burst length
    int length_max;                            // Maximum burst length
    string burst_type;                         // Burst type (INCR, WRAP, FIXED)
    string size_strategy;                      // Size strategy: "FULL" or "RANDOM"
} burst_config_t;

typedef struct {
    int weight;                                // Weight for random selection
    int cycles;                                // Number of cycles to wait
} bubble_param_t;

// =============================================================================
// Weighted random generation arrays
// =============================================================================
burst_config_t burst_config_weights[] = '{     // Burst configuration weights array (total_weight=18)
    '{weight: 4, length_min: 1, length_max: 5, burst_type: "INCR", size_strategy: "FULL"},   // probability: 4/18 = 22.2%
    '{weight: 3, length_min: 4, length_max: 7, burst_type: "INCR", size_strategy: "RANDOM"}, // probability: 3/18 = 16.7%
    '{weight: 2, length_min: 8, length_max: 15, burst_type: "INCR", size_strategy: "RANDOM"}, // probability: 2/18 = 11.1%
    '{weight: 1, length_min: 1, length_max: 1, burst_type: "WRAP", size_strategy: "FULL"},     // LEN=0 (2 transfers) - AXI4 compliant
    '{weight: 1, length_min: 3, length_max: 3, burst_type: "WRAP", size_strategy: "FULL"},     // LEN=2 (4 transfers) - AXI4 compliant
    '{weight: 1, length_min: 7, length_max: 7, burst_type: "WRAP", size_strategy: "FULL"},     // LEN=6 (8 transfers) - AXI4 compliant
    '{weight: 1, length_min: 15, length_max: 15, burst_type: "WRAP", size_strategy: "FULL"},     // LEN=14 (16 transfers) - AXI4 compliant
    '{weight: 1, length_min: 1, length_max: 1, burst_type: "WRAP", size_strategy: "RANDOM"},     // LEN=0 (2 transfers) - AXI4 compliant
    '{weight: 1, length_min: 3, length_max: 3, burst_type: "WRAP", size_strategy: "RANDOM"},     // LEN=2 (4 transfers) - AXI4 compliant
    '{weight: 1, length_min: 7, length_max: 7, burst_type: "WRAP", size_strategy: "RANDOM"},     // LEN=6 (8 transfers) - AXI4 compliant
    '{weight: 1, length_min: 15, length_max: 15, burst_type: "WRAP", size_strategy: "RANDOM"},     // LEN=14 (16 transfers) - AXI4 compliant
    '{weight: 1, length_min: 0, length_max: 0, burst_type: "FIXED", size_strategy: "RANDOM"}   // probability: 1/18 = 5.6%
};

bubble_param_t write_addr_bubble_weights[] = '{ // Write address bubble weights array (total_weight=104)
    '{weight: 70, cycles: 0},                  // probability: 70/104 = 67.3%
    '{weight: 20, cycles: 1},                  // probability: 20/104 = 19.2%
    '{weight: 10, cycles: 2},                  // probability: 10/104 = 9.6%
    '{weight: 4, cycles: 7}                    // probability: 4/104 = 3.8%
};

bubble_param_t write_data_bubble_weights[] = '{ // Write data bubble weights array (total_weight=104)
    '{weight: 80, cycles: 0},                  // probability: 80/104 = 76.9%
    '{weight: 15, cycles: 1},                  // probability: 15/104 = 14.4%
    '{weight: 5, cycles: 2},                   // probability: 5/104 = 4.8%
    '{weight: 4, cycles: 7}                    // probability: 4/104 = 3.8%
};

bubble_param_t read_addr_bubble_weights[] = '{  // Read address bubble weights array (total_weight=104)
    '{weight: 75, cycles: 0},                  // probability: 75/104 = 72.1%
    '{weight: 20, cycles: 1},                  // probability: 20/104 = 19.2%
    '{weight: 5, cycles: 2},                   // probability: 5/104 = 4.8%
    '{weight: 4, cycles: 7}                    // probability: 4/104 = 3.8%
};

// =============================================================================
// Ready negate weights for TB controlled channels
// =============================================================================
bubble_param_t axi_r_ready_negate_weights[] = '{ // Read data ready negate weights (total_weight=104)
    '{weight: 80, cycles: 0},                   // probability: 80/104 = 76.9%
    '{weight: 5, cycles: 1},                    // probability: 5/104 = 4.8%
    '{weight: 5, cycles: 2},                    // probability: 5/104 = 4.8%
    '{weight: 4, cycles: 7}                     // probability: 4/104 = 3.8%
};

bubble_param_t axi_b_ready_negate_weights[] = '{ // Write response ready negate weights (total_weight=104)
    '{weight: 80, cycles: 0},                   // probability: 80/104 = 76.9%
    '{weight: 5, cycles: 1},                    // probability: 5/104 = 4.8%
    '{weight: 5, cycles: 2},                    // probability: 5/104 = 4.8%
    '{weight: 4, cycles: 7}                     // probability: 4/104 = 3.8%
};

// =============================================================================
// Ready negate weights for DUT controlled channels
// =============================================================================
bubble_param_t axi_aw_ready_negate_weights[] = '{ // Write address ready negate weights (total_weight=104)
    '{weight: 80, cycles: 0},                   // probability: 80/104 = 76.9%
    '{weight: 5, cycles: 1},                    // probability: 5/104 = 4.8%
    '{weight: 5, cycles: 2},                    // probability: 5/104 = 4.8%
    '{weight: 4, cycles: 7}                     // probability: 4/104 = 3.8%
};

bubble_param_t axi_w_ready_negate_weights[] = '{  // Write data ready negate weights (total_weight=104)
    '{weight: 80, cycles: 0},                    // probability: 80/104 = 76.9%
    '{weight: 5, cycles: 1},                     // probability: 5/104 = 4.8%
    '{weight: 5, cycles: 2},                     // probability: 5/104 = 4.8%
    '{weight: 4, cycles: 7}                      // probability: 4/104 = 3.8%
};

bubble_param_t axi_ar_ready_negate_weights[] = '{ // Read address ready negate weights (total_weight=104)
    '{weight: 80, cycles: 0},                   // probability: 80/104 = 76.9%
    '{weight: 5, cycles: 1},                    // probability: 5/104 = 4.8%
    '{weight: 5, cycles: 2},                    // probability: 5/104 = 4.8%
    '{weight: 4, cycles: 7}                     // probability: 4/104 = 3.8%
};

// =============================================================================
// Payload structures
// =============================================================================
typedef struct {
    int                         test_count;    // Test sequence number
    logic [AXI_ADDR_WIDTH-1:0] addr;          // AXI address
    logic [1:0]                burst;         // Burst type
    logic [2:0]                size;          // Transfer size
    logic [AXI_ID_WIDTH-1:0]   id;            // AXI ID
    logic [7:0]                len;           // Burst length
    logic                      valid;         // Valid signal
    int                         phase;         // Test phase number
    string                     size_strategy;  // Size strategy: "FULL" or "RANDOM"
} write_addr_payload_t;

typedef struct {
    int                         test_count;    // Test sequence number
    logic [AXI_DATA_WIDTH-1:0] data;          // Write data
    logic [AXI_STRB_WIDTH-1:0] strb;          // Strobe signals
    logic                       last;          // Last transfer flag
    logic                       valid;         // Valid signal
    int                         phase;         // Test phase number
} write_data_payload_t;

typedef struct {
    int                         test_count;    // Test sequence number
    logic [AXI_ADDR_WIDTH-1:0] addr;          // AXI address
    logic [1:0]                burst;         // Burst type
    logic [2:0]                size;          // Transfer size
    logic [AXI_ID_WIDTH-1:0]   id;            // AXI ID
    logic [7:0]                len;           // Burst length
    logic                      valid;         // Valid signal
    int                         phase;         // Test phase number
    string                     size_strategy;  // Size strategy: "FULL" or "RANDOM"
} read_addr_payload_t;

// =============================================================================
// Expected value structures
// =============================================================================
typedef struct {
    int                         test_count;    // Test sequence number
    logic [AXI_DATA_WIDTH-1:0] expected_data; // Expected read data
    logic [AXI_STRB_WIDTH-1:0] expected_strobe; // Expected strobe values
    int                         phase;         // Test phase number
} read_data_expected_t;

typedef struct {
    int                         test_count;    // Test sequence number
    logic [1:0]                expected_resp; // Expected response
    logic [AXI_ID_WIDTH-1:0]   expected_id;   // Expected AXI ID
    int                         phase;         // Test phase number
} write_resp_expected_t;

// =============================================================================
// Byte verification structures
// =============================================================================
typedef struct {
    int                         test_count;    // Test sequence number
    logic [AXI_ADDR_WIDTH-1:0] addr;          // AXI address (byte unit)
    logic [2:0]                size;          // Transfer size (always 0 = 1 byte)
    logic [AXI_ID_WIDTH-1:0]   id;            // AXI ID
    logic [7:0]                len;           // Burst length (always 0 = 1 transfer)
    logic                      valid;         // Valid signal
    int                         phase;         // Test phase number
} byte_verification_read_addr_payload_t;

typedef struct {
    int                         test_count;    // Test sequence number
    logic [7:0]                expected_byte; // Expected byte value (8-bit fixed)
    logic [AXI_ADDR_WIDTH-1:0] byte_addr;     // Byte address
    int                         phase;         // Test phase number
} byte_verification_expected_t;

// =============================================================================
// Payload arrays
// =============================================================================
write_addr_payload_t write_addr_payloads[int];                    // Write address payloads
write_addr_payload_t write_addr_payloads_with_stall[int];         // Write address payloads with stall
write_data_payload_t write_data_payloads[int];                    // Write data payloads
write_data_payload_t write_data_payloads_with_stall[int];         // Write data payloads with stall
read_addr_payload_t read_addr_payloads[int];                      // Read address payloads
read_addr_payload_t read_addr_payloads_with_stall[int];           // Read address payloads with stall

// =============================================================================
// Expected value arrays
// =============================================================================
read_data_expected_t read_data_expected[int];                     // Expected read data values
write_resp_expected_t write_resp_expected[int];                   // Expected write response values

// =============================================================================
// Byte verification arrays
// =============================================================================
byte_verification_read_addr_payload_t byte_verification_read_addr_payloads[int]; // Byte verification read address payloads
byte_verification_expected_t byte_verification_expected[int];                    // Byte verification expected values

// Test start indices for byte verification
int test_start_indices[int];                                                     // Starting indices for each test_count in write_data_payloads

// =============================================================================
// Ready negate pulse arrays for TB controlled channels
// =============================================================================
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_r_ready_negate_pulses; // Read data ready negate pulses
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_b_ready_negate_pulses; // Write response ready negate pulses

// =============================================================================
// Ready negate pulse arrays for DUT controlled channels
// =============================================================================
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_aw_ready_negate_pulses; // Write address ready negate pulses
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_w_ready_negate_pulses;  // Write data ready negate pulses
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_ar_ready_negate_pulses; // Read address ready negate pulses

// =============================================================================
// Ready negate array index counter
// =============================================================================
// Ready negate control indices - separated for Read and Write channels
logic [$clog2(READY_NEGATE_ARRAY_LENGTH):0] read_ready_negate_index = 0;   // Read channel pulse array index
logic [$clog2(READY_NEGATE_ARRAY_LENGTH):0] write_ready_negate_index = 0;  // Write channel pulse array index

// =============================================================================
// Test data generation completion flag
// =============================================================================
logic generate_stimulus_expected_done = 1'b0; // Stimulus generation completion flag

// =============================================================================
// Test execution completion flag
// =============================================================================
logic test_execution_completed = 1'b0;        // Test execution completion flag

// =============================================================================
// Phase control signals
// =============================================================================
logic [7:0] current_phase = 8'd0;             // Current test phase number
logic write_addr_phase_start = 1'b0;          // Write address phase start signal
logic read_addr_phase_start = 1'b0;           // Read address phase start signal
logic write_data_phase_start = 1'b0;          // Write data phase start signal
logic write_resp_phase_start = 1'b0;          // Write response phase start signal
logic read_data_phase_start = 1'b0;           // Read data phase start signal
logic byte_verification_phase_start = 1'b0;   // Byte verification phase start signal
logic clear_phase_latches = 1'b0;             // Clear signal for phase completion latches

// =============================================================================
// Phase completion signals
// =============================================================================
logic write_addr_phase_done = 1'b0;           // Write address phase completion signal
logic read_addr_phase_done = 1'b0;            // Read address phase completion signal
logic write_data_phase_done = 1'b0;           // Write data phase completion signal
logic write_resp_phase_done = 1'b0;           // Write response phase completion signal
logic read_data_phase_done = 1'b0;            // Read data phase completion signal
logic byte_verification_phase_done = 1'b0;    // Byte verification phase completion signal

// =============================================================================
// Phase completion signal latches
// =============================================================================
logic write_addr_phase_done_latched = 1'b0;   // Latched write address phase completion
logic read_addr_phase_done_latched = 1'b0;    // Latched read address phase completion
logic write_data_phase_done_latched = 1'b0;   // Latched write data phase completion
logic write_resp_phase_done_latched = 1'b0;   // Latched write response phase completion
logic read_data_phase_done_latched = 1'b0;    // Latched read data phase completion
logic byte_verification_phase_done_latched = 1'b0; // Latched byte verification phase completion

// =============================================================================
// Byte verification mode control signals
// =============================================================================
logic byte_verification_enable = 1'b1;         // Byte verification mode enable
logic byte_verification_start = 1'b0;          // Byte verification phase start signal
logic byte_verification_done = 1'b0;           // Byte verification phase completion signal
logic byte_verification_active = 1'b0;         // Byte verification active state

// =============================================================================
// State machine type definitions for Write channels
// =============================================================================
typedef enum logic [1:0] {
    WRITE_ADDR_IDLE,        // Idle state waiting for phase start
    WRITE_ADDR_ACTIVE,      // Active state (includes stall handling)
    WRITE_ADDR_FINISH       // Finish processing state
} write_addr_state_t;

typedef enum logic [1:0] {
    WRITE_DATA_IDLE,        // Idle state waiting for phase start
    WRITE_DATA_ACTIVE,      // Active state (includes stall handling)
    WRITE_DATA_FINISH       // Finish processing state
} write_data_state_t;

typedef enum logic [1:0] {
    WRITE_RESP_IDLE,        // Idle state waiting for phase start
    WRITE_RESP_ACTIVE,      // Active state (includes stall handling)
    WRITE_RESP_FINISH       // Finish processing state
} write_resp_state_t;

// =============================================================================
// State machine type definitions for Read channels
// =============================================================================
typedef enum logic [1:0] {
    READ_ADDR_IDLE,         // Idle state waiting for phase start
    READ_ADDR_ACTIVE,       // Active state (includes stall handling)
    READ_ADDR_FINISH        // Finish processing state
} read_addr_state_t;

typedef enum logic [1:0] {
    READ_DATA_IDLE,         // Idle state waiting for phase start
    READ_DATA_ACTIVE,       // Active state (includes stall handling)
    READ_DATA_FINISH        // Finish processing state
} read_data_state_t;

// =============================================================================
// State machine type definitions for Byte verification
// =============================================================================
typedef enum logic [1:0] {
    BYTE_VERIFICATION_IDLE,     // Idle state waiting for verification start
    BYTE_VERIFICATION_ACTIVE,   // Active state (byte verification in progress)
    BYTE_VERIFICATION_FINISH    // Finish processing state
} byte_verification_state_t;

`endif // AXI_COMMON_DEFS_SVH
