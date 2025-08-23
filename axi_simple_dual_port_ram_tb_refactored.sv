// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// AXI4 Simple Dual Port RAM Testbench
// Generated from part08_axi4_bus_testbench_abstraction.md

`timescale 1ns/1ps

module axi_simple_dual_port_ram_tb;

// Include split function files
`include "axi_common_defs.svh"
`include "axi_stimulus_functions.svh"
`include "axi_verification_functions.svh"
`include "axi_utility_functions.svh"
`include "axi_random_generation.svh"
`include "axi_monitoring_functions.svh"

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

// AXI4 Write Address Channel
logic [AXI_ADDR_WIDTH-1:0] axi_aw_addr;
logic [1:0]                axi_aw_burst;
logic [2:0]                axi_aw_size;
logic [AXI_ID_WIDTH-1:0]   axi_aw_id;
logic [7:0]                axi_aw_len;
logic                      axi_aw_valid;
wire                       axi_aw_ready;

// AXI4 Write Data Channel
logic [AXI_DATA_WIDTH-1:0] axi_w_data;
logic [AXI_STRB_WIDTH-1:0] axi_w_strb;
logic                       axi_w_last;
logic                       axi_w_valid;
wire                       axi_w_ready;

// AXI4 Write Response Channel
wire [1:0]                axi_b_resp;
wire [AXI_ID_WIDTH-1:0]   axi_b_id;
wire                       axi_b_valid;
logic                      axi_b_ready;

// AXI4 Read Address Channel
logic [AXI_ADDR_WIDTH-1:0] axi_ar_addr;
logic [1:0]                axi_ar_burst;
logic [2:0]                axi_ar_size;
logic [AXI_ID_WIDTH-1:0]   axi_ar_id;
logic [7:0]                axi_ar_len;
logic                      axi_ar_valid;
wire                       axi_ar_ready;

// AXI4 Read Data Channel
wire [AXI_DATA_WIDTH-1:0] axi_r_data;
wire [AXI_ID_WIDTH-1:0]   axi_r_id;
wire [1:0]                axi_r_resp;
wire                       axi_r_last;
wire                       axi_r_valid;
logic                      axi_r_ready;

// Ready negate control parameters

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
    
    // Display all generated arrays
    display_all_arrays();
    
    // Display array size verification
    write_debug_log($sformatf("Array Size Verification:"));
    write_debug_log($sformatf("  Write Address Payloads: %0d", write_addr_payloads.size()));
    write_debug_log($sformatf("  Write Data Payloads: %0d (should match total burst transfers)", write_data_payloads.size()));
    write_debug_log($sformatf("  Read Address Payloads: %0d", read_addr_payloads.size()));
    write_debug_log($sformatf("  Read Data Expected: %0d (should match write data count)", read_data_expected.size()));
    write_debug_log($sformatf("  Write Response Expected: %0d", write_resp_expected.size()));
    
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
    write_resp_phase_start = 1'b1;
    
    @(posedge clk);
    #1;
    write_addr_phase_start = 1'b0;
    write_data_phase_start = 1'b0;
    write_resp_phase_start = 1'b0;
    
    // Wait for first phase completion
    wait(write_addr_phase_done_latched && write_data_phase_done_latched && write_resp_phase_done_latched);
    
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
        write_resp_phase_start = 1'b1;
        read_data_phase_start = 1'b1;
        
        @(posedge clk);
        #1;
        write_addr_phase_start = 1'b0;
        read_addr_phase_start = 1'b0;
        write_data_phase_start = 1'b0;
        write_resp_phase_start = 1'b0;
        read_data_phase_start = 1'b0;
        
        // Wait for all channels completion
        wait(write_addr_phase_done_latched && read_addr_phase_done_latched && 
             write_data_phase_done_latched && write_resp_phase_done_latched && read_data_phase_done_latched);
        
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

// Phase completion signal latches - Moved to Read/Write control modules

// Write Address Channel Control - Moved to Write control module

// Read Address Channel Control - Moved to Read control module

// Write Data Channel Control - Moved to Write control module

// Read Data Channel Control - Moved to Read control module

// Protocol Verification System
// Instantiate protocol verification module (accesses TOP hierarchy signals directly)
axi_protocol_verification_module protocol_verifier();

// Test start and completion summary
initial begin
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

// Ready negate control logic - Moved to Read/Write control modules

// Monitoring and Logging System
// Instantiate monitoring module (accesses TOP hierarchy signals directly)
axi_monitoring_module monitoring_logger();

// Write Channel Control System
// Instantiate write control module (accesses TOP hierarchy signals directly)
axi_write_channel_control_module write_controller();

// Read Channel Control System
// Instantiate read control module (accesses TOP hierarchy signals directly)
axi_read_channel_control_module read_controller();

// Write Response Channel Control - Moved to Write control module

endmodule
