// AXI4 Common Definitions Header File
// This file contains all common parameters and type definitions for the testbench

`ifndef AXI_COMMON_DEFS_SVH
`define AXI_COMMON_DEFS_SVH

// Testbench parameters
parameter MEMORY_SIZE_BYTES = 33554432;     // 32MB
parameter AXI_DATA_WIDTH = 32;              // 32bit
parameter AXI_ID_WIDTH = 8;                 // 8bit ID
parameter TOTAL_TEST_COUNT = 800;          // Total test count
parameter PHASE_TEST_COUNT = 8;           // Tests per phase
//parameter TOTAL_TEST_COUNT = 20;          // Total test count
//parameter PHASE_TEST_COUNT = 4;           // Tests per phase
parameter TEST_COUNT_ADDR_SIZE_BYTES = 4096; // Address size per test count
parameter CLK_PERIOD = 10;                  // 10ns period
parameter CLK_HALF_PERIOD = 5;             // 5ns half period
parameter RESET_CYCLES = 4;                // Reset cycles

// Derived parameters
parameter AXI_ADDR_WIDTH = $clog2(MEMORY_SIZE_BYTES);
parameter AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;

// Ready negate control parameters
parameter READY_NEGATE_ARRAY_LENGTH = 1000;  // Length of ready negate pulse array

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
    '{weight: 4, length_min: 1, length_max: 3, burst_type: "INCR"},
    '{weight: 3, length_min: 4, length_max: 7, burst_type: "INCR"},
    '{weight: 2, length_min: 8, length_max: 15, burst_type: "INCR"},
    '{weight: 1, length_min: 15, length_max: 31, burst_type: "WRAP"},
    '{weight: 1, length_min: 0, length_max: 0, burst_type: "FIXED"}
};

bubble_param_t write_addr_bubble_weights[] = '{
    '{weight: 70, cycles: 0},
    '{weight: 20, cycles: 1},
    '{weight: 10, cycles: 2},
    '{weight: 4, cycles: 7}
};

bubble_param_t write_data_bubble_weights[] = '{
    '{weight: 80, cycles: 0},
    '{weight: 15, cycles: 1},
    '{weight: 5, cycles: 2},
    '{weight: 4, cycles: 7}
};

bubble_param_t read_addr_bubble_weights[] = '{
    '{weight: 75, cycles: 0},
    '{weight: 20, cycles: 1},
    '{weight: 5, cycles: 2},
    '{weight: 4, cycles: 7}
};

// Ready negate weights for TB controlled channels
bubble_param_t axi_r_ready_negate_weights[] = '{
    '{weight: 80, cycles: 0},  // 80% probability: no negate
    '{weight: 5, cycles: 1},  // 15% probability: negate for 1 cycle
    '{weight: 5, cycles: 2},    // 5% probability: negate for 2 cycles
    '{weight: 4, cycles: 7}
};

bubble_param_t axi_b_ready_negate_weights[] = '{
    '{weight: 80, cycles: 0},  // 80% probability: no negate
    '{weight: 5, cycles: 1},  // 15% probability: negate for 1 cycle
    '{weight: 5, cycles: 2},    // 5% probability: negate for 2 cycles
    '{weight: 4, cycles: 7}
};

// Ready negate weights for DUT controlled channels
bubble_param_t axi_aw_ready_negate_weights[] = '{
    '{weight: 80, cycles: 0},  // 80% probability: no negate
    '{weight: 5, cycles: 1},  // 15% probability: negate for 1 cycle
    '{weight: 5, cycles: 2},    // 5% probability: negate for 2 cycles
    '{weight: 4, cycles: 7}
};

bubble_param_t axi_w_ready_negate_weights[] = '{
    '{weight: 80, cycles: 0},  // 80% probability: no negate
    '{weight: 5, cycles: 1},  // 15% probability: negate for 1 cycle
    '{weight: 5, cycles: 2},    // 5% probability: negate for 2 cycles
    '{weight: 4, cycles: 7}
};

bubble_param_t axi_ar_ready_negate_weights[] = '{
    '{weight: 80, cycles: 0},  // 80% probability: no negate
    '{weight: 5, cycles: 1},  // 15% probability: negate for 1 cycle
    '{weight: 5, cycles: 2},    // 5% probability: negate for 2 cycles
    '{weight: 4, cycles: 7}
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

// Expected value structures
typedef struct {
    int                         test_count;
    logic [AXI_DATA_WIDTH-1:0] expected_data;
    logic [AXI_STRB_WIDTH-1:0] expected_strobe;
    int                         phase;
} read_data_expected_t;

typedef struct {
    int                         test_count;
    logic [1:0]                expected_resp;
    logic [AXI_ID_WIDTH-1:0]   expected_id;
    int                         phase;
} write_resp_expected_t;

// Payload arrays
write_addr_payload_t write_addr_payloads[int];
write_addr_payload_t write_addr_payloads_with_stall[int];
write_data_payload_t write_data_payloads[int];
write_data_payload_t write_data_payloads_with_stall[int];
read_addr_payload_t read_addr_payloads[int];
read_addr_payload_t read_addr_payloads_with_stall[int];

// Expected value arrays
read_data_expected_t read_data_expected[int];
write_resp_expected_t write_resp_expected[int];

// Ready negate pulse arrays for TB controlled channels
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_r_ready_negate_pulses;
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_b_ready_negate_pulses;

// Ready negate pulse arrays for DUT controlled channels
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_aw_ready_negate_pulses;
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_w_ready_negate_pulses;
logic [READY_NEGATE_ARRAY_LENGTH-1:0] axi_ar_ready_negate_pulses;

// Ready negate array index counter
logic [$clog2(READY_NEGATE_ARRAY_LENGTH):0] ready_negate_index = 0;

// Test data generation completion flag
logic generate_stimulus_expected_done = 1'b0;

// Test execution completion flag
logic test_execution_completed = 1'b0;

// Phase control signals
logic [7:0] current_phase = 8'd0;
logic write_addr_phase_start = 1'b0;
logic read_addr_phase_start = 1'b0;
logic write_data_phase_start = 1'b0;
logic write_resp_phase_start = 1'b0;
logic read_data_phase_start = 1'b0;
logic clear_phase_latches = 1'b0;  // Clear signal for phase completion latches

// Phase completion signals
logic write_addr_phase_done = 1'b0;
logic read_addr_phase_done = 1'b0;
logic write_data_phase_done = 1'b0;
logic write_resp_phase_done = 1'b0;
logic read_data_phase_done = 1'b0;

// Phase completion signal latches
logic write_addr_phase_done_latched = 1'b0;
logic read_addr_phase_done_latched = 1'b0;
logic write_data_phase_done_latched = 1'b0;
logic write_resp_phase_done_latched = 1'b0;
logic read_data_phase_done_latched = 1'b0;

// Log control parameters
parameter LOG_ENABLE = 1'b1;
parameter DEBUG_LOG_ENABLE = 1'b1;

`endif // AXI_COMMON_DEFS_SVH
