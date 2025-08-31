// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// AXI4 Simple Single Port RAM Testbench - Part13 Version with Enhanced Strobe Control
// This testbench has been refactored to use modular architecture with separate modules for:
// - Protocol verification
// - Monitoring and logging
// - Write channel control
// - Read channel control
// Enhanced strobe control parameters for comprehensive testing
// Original functionality has been preserved while improving maintainability and readability

`timescale 1ns/1ps

module top_tb;

// =============================================================================
// Header Files and Function Libraries
// =============================================================================
// Common definitions and parameters
`include "axi_common_defs.svh"
// Test stimulus generation functions
`include "axi_stimulus_functions.svh"
// Verification and checking functions
`include "axi_verification_functions.svh"
// Utility and helper functions
`include "axi_utility_functions.svh"
// Random data generation functions
`include "axi_random_generation.svh"
// Monitoring and logging functions
`include "axi_monitoring_functions.svh"

// =============================================================================
// Clock and Reset Generation
// =============================================================================
reg clk;      // System clock signal
reg rst_n;    // Active-low reset signal

// Clock generation: 100MHz (10ns period)
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 50% duty cycle
end

// Reset generation: Assert reset for 10 clock cycles after simulation start
initial begin
    rst_n = 0;                           // Assert reset
    repeat(10) @(posedge clk);           // Wait 10 clock cycles
    #1;                                  // Small delay for signal stability
    rst_n = 1;                           // Deassert reset
end

// =============================================================================
// AXI4 Interface Signals
// =============================================================================
// Write Address Channel (AW)
logic [AXI_ADDR_WIDTH-1:0] axi_aw_addr;   // Write address
logic [1:0]                axi_aw_burst;  // Burst type (FIXED/INCR/WRAP)
logic [2:0]                axi_aw_size;   // Transfer size (bytes per transfer)
logic [AXI_ID_WIDTH-1:0]   axi_aw_id;     // Write transaction ID
logic [7:0]                axi_aw_len;    // Burst length (number of transfers)
logic                      axi_aw_valid;  // Write address valid
wire                       axi_aw_ready;  // Write address ready (from slave)

// Write Data Channel (W)
logic [AXI_DATA_WIDTH-1:0] axi_w_data;    // Write data
logic [AXI_STRB_WIDTH-1:0] axi_w_strb;    // Write strobes (byte enables)
logic                       axi_w_last;    // Last transfer in burst
logic                       axi_w_valid;   // Write data valid
wire                       axi_w_ready;   // Write data ready (from slave)

// Write Response Channel (B)
wire [1:0]                axi_b_resp;    // Write response (OKAY/SLVERR/DECERR)
wire [AXI_ID_WIDTH-1:0]   axi_b_id;      // Write response ID
wire                       axi_b_valid;   // Write response valid (from slave)
logic                      axi_b_ready;   // Write response ready

// Read Address Channel (AR)
logic [AXI_ADDR_WIDTH-1:0] axi_ar_addr;   // Read address
logic [1:0]                axi_ar_burst;  // Burst type (FIXED/INCR/WRAP)
logic [2:0]                axi_ar_size;   // Transfer size (bytes per transfer)
logic [AXI_ID_WIDTH-1:0]   axi_ar_id;     // Read transaction ID
logic [7:0]                axi_ar_len;    // Burst length (number of transfers)
logic                      axi_ar_valid;  // Read address valid
wire                       axi_ar_ready;  // Read address ready (from slave)

// Read Data Channel (R)
wire [AXI_DATA_WIDTH-1:0] axi_r_data;    // Read data
wire [AXI_ID_WIDTH-1:0]   axi_r_id;      // Read data ID
wire [1:0]                axi_r_resp;    // Read response (OKAY/SLVERR/DECERR)
wire                       axi_r_last;    // Last transfer in burst
wire                       axi_r_valid;   // Read data valid (from slave)
logic                      axi_r_ready;   // Read data ready

// =============================================================================
// Device Under Test (DUT) Instantiation
// =============================================================================
// Instantiate the AXI4 Simple Single Port RAM module with parameterized configuration
axi_simple_single_port_ram #(
    .MEMORY_SIZE_BYTES(MEMORY_SIZE_BYTES),  // Total memory size in bytes
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),        // AXI4 data bus width
    .AXI_ID_WIDTH(AXI_ID_WIDTH)            // AXI4 transaction ID width
) dut (
    // Clock and Reset
    .axi_clk(clk),                          // AXI4 clock input
    .axi_resetn(rst_n),                     // AXI4 active-low reset input
    
    // Write Address Channel (AW)
    .axi_aw_addr(axi_aw_addr),              // Write address
    .axi_aw_burst(axi_aw_burst),            // Burst type
    .axi_aw_size(axi_aw_size),              // Transfer size
    .axi_aw_id(axi_aw_id),                  // Write transaction ID
    .axi_aw_len(axi_aw_len),                // Burst length
    .axi_aw_valid(axi_aw_valid),            // Write address valid
    .axi_aw_ready(axi_aw_ready),            // Write address ready
    
    // Write Data Channel (W)
    .axi_w_data(axi_w_data),                // Write data
    .axi_w_last(axi_w_last),                // Last transfer flag
    .axi_w_strb(axi_w_strb),                // Write strobes
    .axi_w_valid(axi_w_valid),              // Write data valid
    .axi_w_ready(axi_w_ready),              // Write data ready
    
    // Write Response Channel (B)
    .axi_b_resp(axi_b_resp),                // Write response
    .axi_b_id(axi_b_id),                    // Write response ID
    .axi_b_valid(axi_b_valid),              // Write response valid
    .axi_b_ready(axi_b_ready),              // Write response ready
    
    // Read Address Channel (AR)
    .axi_ar_addr(axi_ar_addr),              // Read address
    .axi_ar_burst(axi_ar_burst),            // Burst type
    .axi_ar_size(axi_ar_size),              // Transfer size
    .axi_ar_id(axi_ar_id),                  // Read transaction ID
    .axi_ar_len(axi_ar_len),                // Burst length
    .axi_ar_valid(axi_ar_valid),            // Read address valid
    .axi_ar_ready(axi_ar_ready),            // Read address ready
    
    // Read Data Channel (R)
    .axi_r_data(axi_r_data),                // Read data
    .axi_r_id(axi_r_id),                    // Read data ID
    .axi_r_resp(axi_r_resp),                // Read response
    .axi_r_last(axi_r_last),                // Last transfer flag
    .axi_r_valid(axi_r_valid),              // Read data valid
    .axi_r_ready(axi_r_ready)               // Read data ready
);


// =============================================================================
// Test Stimulus Generation and Initialization
// =============================================================================
// This initial block runs at simulation time 0 to generate all test data
initial begin
    // Generate Write Address Channel test payloads
    generate_write_addr_payloads();                    // Basic write address sequences
    generate_write_addr_payloads_with_stall();         // Write address sequences with stall scenarios
    
    // Generate Write Data Channel test payloads
    generate_write_data_payloads();                    // Basic write data sequences
    generate_write_data_payloads_with_stall();         // Write data sequences with stall scenarios
    
    // Generate Read Address Channel test payloads
    generate_read_addr_payloads();                     // Basic read address sequences
    generate_read_addr_payloads_with_stall();          // Read address sequences with stall scenarios
    
    // Generate expected values for verification
    generate_read_data_expected();                     // Expected read data values
    generate_write_resp_expected();                    // Expected write response values
    
    // Generate byte verification arrays if enabled
    if (BYTE_VERIFICATION_ENABLE) begin
        generate_byte_verification_arrays();           // Byte verification arrays
    end
    
    // Initialize ready signal negation patterns for stall testing
    initialize_ready_negate_pulses();
    
    // Small delay for signal stability
    #1;
    // Signal that stimulus generation is complete
    generate_stimulus_expected_done = 1'b1;
end

// =============================================================================
// Test Scenario Control and Phase Management
// =============================================================================
// This initial block controls the overall test execution flow and phase progression
initial begin
    
    // Initialize phase control signals
    current_phase = 8'd0;                    // Start with phase 0
    write_addr_phase_start = 1'b0;          // Write address phase control
    read_addr_phase_start = 1'b0;           // Read address phase control
    write_data_phase_start = 1'b0;          // Write data phase control
    read_data_phase_start = 1'b0;           // Read data phase control
    
    // Wait for stimulus generation to complete before starting tests
    wait(generate_stimulus_expected_done);
    
    // Wait for reset to be deasserted before proceeding
    wait(rst_n);
    
    // =============================================================================
    // Phase 0: Initial Write-Only Phase
    // =============================================================================
    // Start with write operations only (no read operations in first phase)
    repeat(2) @(posedge clk);               // Wait 2 clock cycles for stability
    #1;
    write_addr_phase_start = 1'b1;          // Start write address phase
    write_data_phase_start = 1'b1;          // Start write data phase
    write_resp_phase_start = 1'b1;          // Start write response phase
    
    @(posedge clk);                         // Wait one clock cycle
    #1;
    write_addr_phase_start = 1'b0;          // Stop write address phase
    write_data_phase_start = 1'b0;          // Stop write data phase
    write_resp_phase_start = 1'b0;          // Stop write response phase
    
    // Wait for all write channels to complete their operations
    wait(write_addr_phase_done_latched && write_data_phase_done_latched && write_resp_phase_done_latched);
    
    $display("Phase %0d: All Write Channels Completed", current_phase);
    
    // Clear phase completion latches and prepare for next phase
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b1;             // Assert clear signal to reset latches
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b0;             // Deassert clear signal
    current_phase = current_phase + 8'd1;   // Increment to next phase
    
    // =============================================================================
    // Phase 1 to N-1: Full Read/Write Operations
    // =============================================================================
    // Main test loop: execute multiple phases with full read/write operations
    for (int phase = 0; phase < (TOTAL_TEST_COUNT / PHASE_TEST_COUNT) - 1; phase++) begin
        @(posedge clk);
        #1;
        // Start all channels simultaneously for comprehensive testing
        write_addr_phase_start = 1'b1;      // Start write address phase
        read_addr_phase_start = 1'b1;       // Start read address phase
        write_data_phase_start = 1'b1;      // Start write data phase
        write_resp_phase_start = 1'b1;      // Start write response phase
        read_data_phase_start = 1'b1;       // Start read data phase
        
        @(posedge clk);                     // Wait one clock cycle
        #1;
        // Stop all phase start signals after one cycle
        write_addr_phase_start = 1'b0;      // Stop write address phase
        read_addr_phase_start = 1'b0;       // Stop read address phase
        write_data_phase_start = 1'b0;      // Stop write data phase
        write_resp_phase_start = 1'b0;      // Stop write response phase
        read_data_phase_start = 1'b0;       // Stop read data phase
        
        // Wait for all channels to complete their operations
        wait(write_addr_phase_done_latched && read_addr_phase_done_latched && 
             write_data_phase_done_latched && write_resp_phase_done_latched && read_data_phase_done_latched);
        
        $display("Phase %0d: All Channels Completed", current_phase);
        
        // Clear phase completion latches and prepare for next phase
        @(posedge clk);
        #1;
        clear_phase_latches = 1'b1;         // Assert clear signal to reset latches
        @(posedge clk);
        #1;
        clear_phase_latches = 1'b0;         // Deassert clear signal
        current_phase = current_phase + 8'd1; // Increment to next phase
    end
    
    // =============================================================================
    // Final Phase: Read-Only Operations
    // =============================================================================
    // Final phase focuses on read operations to verify written data
    @(posedge clk);
    #1;
    read_addr_phase_start = 1'b1;           // Start read address phase
    read_data_phase_start = 1'b1;           // Start read data phase
    
    @(posedge clk);                         // Wait one clock cycle
    #1;
    read_addr_phase_start = 1'b0;           // Stop read address phase
    read_data_phase_start = 1'b0;           // Stop read data phase
    
    // Wait for read operations to complete
    wait(read_addr_phase_done_latched && read_data_phase_done_latched);
    
    $display("Phase %0d: Final Read Operations Completed", current_phase);
    
    // Clear final phase latches
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b1;             // Assert clear signal
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b0;             // Deassert clear signal
        
    // =============================================================================
    // Byte Verification Phase
    // =============================================================================
    // After all normal test phases are completed, perform byte-level verification
    if (BYTE_VERIFICATION_ENABLE) begin
        $display("Starting Byte Verification Phase...");
        
        // Start byte verification phase
        @(posedge clk);
        #1;
        byte_verification_phase_start = 1'b1;  // Start byte verification phase
        
        @(posedge clk);                         // Wait one clock cycle
        #1;
        byte_verification_phase_start = 1'b0;   // Stop byte verification phase
        
        // Wait for byte verification phase to complete
        wait(byte_verification_phase_done_latched);
        
        $display("Phase %0d: Byte Verification Phase Completed", current_phase);
        
        // Clear byte verification phase latches
        @(posedge clk);
        #1;
        clear_phase_latches = 1'b1;             // Assert clear signal
        @(posedge clk);
        #1;
        clear_phase_latches = 1'b0;             // Deassert clear signal
    end
    
    // =============================================================================
    // Test Completion
    // =============================================================================
    // All test phases have been completed successfully
    $display("All Phases Completed. Test Scenario Finished Successfully.");
    test_execution_completed = 1'b1;        // Set test completion flag for monitoring
    #1;                                     // Wait for test completion log to be written
    $finish;                                // End simulation
end

// =============================================================================
// Modular Testbench Architecture - Part13 Enhanced Version
// =============================================================================
// The testbench has been refactored into modular components for better maintainability
// Each module handles specific functionality while accessing TOP-level signals directly
// Enhanced with strobe control parameters for comprehensive testing

// Protocol Verification System
// Monitors AXI4 protocol compliance and performs payload hold checks
axi_protocol_verification_module protocol_verifier();

// Monitoring and Logging System
// Handles test execution logging, configuration display, and results summary
axi_monitoring_module monitoring_logger();

// Write Channel Control System
// Manages all write-related operations: address, data, and response channels
axi_write_channel_control_module write_controller();

// Read Channel Control System
// Manages all read-related operations: address and data channels
axi_read_channel_control_module read_controller();

// Byte Verification Control System
// Manages byte-level verification operations
axi_byte_verification_control_module byte_verification_controller();

// =============================================================================
// Byte Verification Functions
// =============================================================================
// Byte verification is now handled by the axi_byte_verification_control_module
// which processes the verification arrays and manages the phase completion signals

endmodule
