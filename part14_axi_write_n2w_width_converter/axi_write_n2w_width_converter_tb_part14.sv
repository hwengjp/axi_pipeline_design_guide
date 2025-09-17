// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// AXI4 Write N2W Width Converter Testbench - Part14 Version
// This testbench has been refactored to use modular architecture with separate modules for:
// - Protocol verification
// - Monitoring and logging
// - Write channel control
// - Read channel control
// Enhanced with strobe control parameters for comprehensive testing
// Original functionality has been preserved while improving maintainability and readability

`timescale 1ns/1ps

module top_tb;

// =============================================================================
// Header Files and Function Libraries
// =============================================================================
// Common definitions and parameters
`include "axi_common_defs.svh"

// =============================================================================
// Test Parameters
// =============================================================================
// Data width parameters for width converter
localparam int unsigned WRITE_SOURCE_WIDTH = 64;    // Write source data width (narrow)
localparam int unsigned WRITE_TARGET_WIDTH = 128;   // Write target data width (wide)
localparam int unsigned READ_SOURCE_WIDTH = 64;     // Read source data width (narrow)
localparam int unsigned READ_TARGET_WIDTH = 64;     // Read target data width (same as source)


// Test stimulus generation functions
`include "../part13_axi4_testbench_byte_access_verification/axi_stimulus_functions.svh"
// Verification and checking functions
`include "../part13_axi4_testbench_byte_access_verification/axi_verification_functions.svh"
// Utility and helper functions
`include "../part13_axi4_testbench_byte_access_verification/axi_utility_functions.svh"
// Random data generation functions
`include "../part13_axi4_testbench_byte_access_verification/axi_random_generation.svh"
// Monitoring and logging functions
`include "../part13_axi4_testbench_byte_access_verification/axi_monitoring_functions.svh"

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

// Write Data Channel (W) - Source width (narrow)
logic [WRITE_SOURCE_WIDTH-1:0] axi_w_data;    // Write data
logic [WRITE_SOURCE_WIDTH/8-1:0] axi_w_strb;    // Write strobes (byte enables)
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

// Read Data Channel (R) - Source width (narrow)
wire [READ_SOURCE_WIDTH-1:0] axi_r_data;    // Read data
wire [AXI_ID_WIDTH-1:0]   axi_r_id;      // Read data ID
wire [1:0]                axi_r_resp;    // Read response (OKAY/SLVERR/DECERR)
wire                       axi_r_last;    // Last transfer in burst
wire                       axi_r_valid;   // Read data valid (from slave)
logic                      axi_r_ready;   // Read data ready

// =============================================================================
// Device Under Test (DUT) Instantiation
// =============================================================================
// Instantiate the AXI4 Write N2W Width Converter DUT with parameterized configuration
axi_write_n2w_width_converter_dut #(
    .WRITE_SOURCE_WIDTH(WRITE_SOURCE_WIDTH),  // Write source data width
    .WRITE_TARGET_WIDTH(WRITE_TARGET_WIDTH),  // Write target data width
    .READ_SOURCE_WIDTH(READ_SOURCE_WIDTH),    // Read source data width
    .READ_TARGET_WIDTH(READ_TARGET_WIDTH),    // Read target data width
    .ADDR_WIDTH(AXI_ADDR_WIDTH),              // Address width
    .MEMORY_SIZE_BYTES(MEMORY_SIZE_BYTES)     // Memory size in bytes
) dut (
    // Clock and Reset
    .aclk(clk),                               // AXI4 clock input
    .aresetn(rst_n),                          // AXI4 active-low reset input
    
    // Write Address Channel (AW)
    .s_axi_awaddr(axi_aw_addr),               // Write address
    .s_axi_awburst(axi_aw_burst),             // Burst type
    .s_axi_awsize(axi_aw_size),               // Transfer size
    .s_axi_awid(axi_aw_id),                   // Write transaction ID
    .s_axi_awlen(axi_aw_len),                 // Burst length
    .s_axi_awvalid(axi_aw_valid),             // Write address valid
    .s_axi_awready(axi_aw_ready),             // Write address ready
    
    // Write Data Channel (W)
    .s_axi_wdata(axi_w_data),                 // Write data
    .s_axi_wlast(axi_w_last),                 // Last transfer flag
    .s_axi_wstrb(axi_w_strb),                 // Write strobes
    .s_axi_wvalid(axi_w_valid),               // Write data valid
    .s_axi_wready(axi_w_ready),               // Write data ready
    
    // Write Response Channel (B)
    .s_axi_bresp(axi_b_resp),                 // Write response
    .s_axi_bid(axi_b_id),                     // Write response ID
    .s_axi_bvalid(axi_b_valid),               // Write response valid
    .s_axi_bready(axi_b_ready),               // Write response ready
    
    // Read Address Channel (AR)
    .s_axi_araddr(axi_ar_addr),               // Read address
    .s_axi_arburst(axi_ar_burst),             // Burst type
    .s_axi_arsize(axi_ar_size),               // Transfer size
    .s_axi_arid(axi_ar_id),                   // Read transaction ID
    .s_axi_arlen(axi_ar_len),                 // Burst length
    .s_axi_arvalid(axi_ar_valid),             // Read address valid
    .s_axi_arready(axi_ar_ready),             // Read address ready
    
    // Read Data Channel (R)
    .s_axi_rdata(axi_r_data),                 // Read data
    .s_axi_rid(axi_r_id),                     // Read data ID
    .s_axi_rresp(axi_r_resp),                 // Read response
    .s_axi_rlast(axi_r_last),                 // Last transfer flag
    .s_axi_rvalid(axi_r_valid),               // Read data valid
    .s_axi_rready(axi_r_ready)                // Read data ready
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
    
    // Generate byte verification arrays (if enabled)
    if (BYTE_VERIFICATION_ENABLE) begin
        generate_byte_verification_arrays();
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
    write_log($sformatf("Phase %0d: Stimulus and Expected Values Generation Confirmed", current_phase));
    
    // Wait for reset to be deasserted before proceeding
    wait(rst_n);
    write_log($sformatf("Phase %0d: Reset Deassertion Confirmed", current_phase));
    
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
    
    write_log($sformatf("Phase %0d: All Write Channels Completed", current_phase));
    
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
        
        write_log($sformatf("Phase %0d: All Channels Completed", current_phase));
        
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
    
    write_log($sformatf("Phase %0d: Final Read Operations Completed", current_phase));
    
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
        write_log("Starting Byte Verification Phase...");
        
        // Start byte verification phase
        @(posedge clk); #1;
        byte_verification_phase_start = 1'b1;
        @(posedge clk); #1;
        byte_verification_phase_start = 1'b0;
        
        // Wait for byte verification phase to complete
        wait(byte_verification_phase_done_latched);
        
        write_log($sformatf("Phase %0d: Byte Verification Phase Completed", current_phase));
        
        // Clear byte verification phase latches
        @(posedge clk); #1;
        clear_phase_latches = 1'b1;
        @(posedge clk); #1;
        clear_phase_latches = 1'b0;
    end
        
    // =============================================================================
    // Test Completion
    // =============================================================================
    // All test phases have been completed successfully
    write_log("All Phases Completed. Test Scenario Finished Successfully.");
    test_execution_completed = 1'b1;        // Set test completion flag for monitoring
    #1;                                     // Wait for test completion log to be written
    $finish;                                // End simulation
end

// =============================================================================
// Modular Testbench Architecture - Part13 Enhanced Version
// =============================================================================
// The testbench has been refactored into modular components for better maintainability
// Each module handles specific functionality while accessing TOP-level signals directly

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

endmodule
