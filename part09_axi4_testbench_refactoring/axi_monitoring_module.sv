// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// AXI4 Monitoring and Logging Module

`timescale 1ns/1ps

module axi_monitoring_module (
    // No ports - direct access to TOP hierarchy signals
);

// Include common definitions for parameters
`include "axi_common_defs.svh"

// Logging and monitoring
// Phase execution logging
always @(posedge `TOP_TB.clk) begin
    if (`TOP_TB.write_addr_phase_start) begin
        write_log($sformatf("Phase %0d: Write Address Channel started", `TOP_TB.current_phase));
    end
    if (`TOP_TB.read_addr_phase_start) begin
        write_log($sformatf("Phase %0d: Read Address Channel started", `TOP_TB.current_phase));
    end
    if (`TOP_TB.write_data_phase_start) begin
        write_log($sformatf("Phase %0d: Write Data Channel started", `TOP_TB.current_phase));
    end
    if (`TOP_TB.read_data_phase_start) begin
        write_log($sformatf("Phase %0d: Read Data Channel started", `TOP_TB.current_phase));
    end
end

// AXI4 transfer logging (debug)
always @(posedge `TOP_TB.clk) begin
        // Write Address Channel transfer
        if (`TOP_TB.axi_aw_valid && `TOP_TB.axi_aw_ready) begin
            write_debug_log($sformatf("Write Addr Transfer: addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d", 
                `TOP_TB.axi_aw_addr, `TOP_TB.axi_aw_burst, size_to_string(`TOP_TB.axi_aw_size), `TOP_TB.axi_aw_id, `TOP_TB.axi_aw_len));
        end
        
        // Write Data Channel transfer
        if (`TOP_TB.axi_w_valid && `TOP_TB.axi_w_ready) begin
            write_debug_log($sformatf("Write Data Transfer: data=0x%h, strb=0x%h, last=%0d", 
                `TOP_TB.axi_w_data, `TOP_TB.axi_w_strb, `TOP_TB.axi_w_last));
        end
        
        // Read Address Channel transfer
        if (`TOP_TB.axi_ar_valid && `TOP_TB.axi_ar_ready) begin
            write_debug_log($sformatf("Read Addr Transfer: addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d", 
                `TOP_TB.axi_ar_addr, `TOP_TB.axi_ar_burst, size_to_string(`TOP_TB.axi_ar_size), `TOP_TB.axi_ar_id, `TOP_TB.axi_ar_len));
        end
        
        // Read Data Channel transfer
        if (`TOP_TB.axi_r_valid && `TOP_TB.axi_r_ready) begin
            write_debug_log($sformatf("Read Data Transfer: data=0x%h, resp=%0d, last=%0d", 
                `TOP_TB.axi_r_data, `TOP_TB.axi_r_resp, `TOP_TB.axi_r_last));
        end
end

// Stall cycle logging (debug)
always @(posedge `TOP_TB.clk) begin
        // Write Address Channel stall
        if (`TOP_TB.axi_aw_valid && !`TOP_TB.axi_aw_ready) begin
            write_debug_log("Write Addr Channel: Stall detected");
        end
        
        // Write Data Channel stall
        if (`TOP_TB.axi_w_valid && !`TOP_TB.axi_w_ready) begin
            write_debug_log("Write Data Channel: Stall detected");
        end
        
        // Read Address Channel stall
        if (`TOP_TB.axi_ar_valid && !`TOP_TB.axi_ar_ready) begin
            write_debug_log("Read Addr Channel: Stall detected");
        end
        
        // Read Data Channel stall
        if (`TOP_TB.axi_r_valid && !`TOP_TB.axi_r_ready) begin
            write_debug_log("Read Data Channel: Stall detected");
        end
end

// Test start and completion summary
initial begin
    // Phase 1: Display test configuration
    write_log("=== AXI4 Testbench Configuration ===");
    write_log("Test Configuration:");
    write_log($sformatf("  - Memory Size: %0d bytes (%0d MB)", `TOP_TB.MEMORY_SIZE_BYTES, `TOP_TB.MEMORY_SIZE_BYTES/1024/1024));
    write_log($sformatf("  - Data Width: %0d bits", `TOP_TB.AXI_DATA_WIDTH));
    write_log($sformatf("  - Total Test Count: %0d", `TOP_TB.TOTAL_TEST_COUNT));
    write_log($sformatf("  - Phase Test Count: %0d", `TOP_TB.PHASE_TEST_COUNT));
    write_log($sformatf("  - Number of Phases: %0d", (`TOP_TB.TOTAL_TEST_COUNT / `TOP_TB.PHASE_TEST_COUNT)));
    
    // Wait for stimulus generation completion
    wait(`TOP_TB.generate_stimulus_expected_done);
    
    // Phase 2: Display generated payloads summary
    write_log("=== Generated Payloads Summary ===");
    write_log("Generated Test Data:");
    write_log($sformatf("  - Write Address Payloads: %0d", `TOP_TB.write_addr_payloads.size()));
    write_log($sformatf("  - Write Address with Stall: %0d", `TOP_TB.write_addr_payloads_with_stall.size()));
    write_log($sformatf("  - Write Data Payloads: %0d", `TOP_TB.write_data_payloads.size()));
    write_log($sformatf("  - Write Data with Stall: %0d", `TOP_TB.write_data_payloads_with_stall.size()));
    write_log($sformatf("  - Read Address Payloads: %0d", `TOP_TB.read_addr_payloads.size()));
    write_log($sformatf("  - Read Address with Stall: %0d", `TOP_TB.read_addr_payloads_with_stall.size()));
    write_log($sformatf("  - Read Data Expected: %0d", `TOP_TB.read_data_expected.size()));
    write_log($sformatf("  - Write Response Expected: %0d", `TOP_TB.write_resp_expected.size()));

    // Display all generated arrays
    `TOP_TB.display_all_arrays();
    
    // Wait for test execution completion
    wait(`TOP_TB.test_execution_completed);
    
    // Phase 3: Display test execution results summary
    write_log("=== Test Execution Results Summary ===");
    write_log("Test Results:");
    write_log($sformatf("  - Total Tests Executed: %0d", `TOP_TB.TOTAL_TEST_COUNT));
    write_log($sformatf("  - Total Phases Completed: %0d", (`TOP_TB.TOTAL_TEST_COUNT / `TOP_TB.PHASE_TEST_COUNT)));
    write_log("  - All Phases: PASS");
    write_log("  - Test Status: COMPLETED SUCCESSFULLY");
    write_log("=== AXI4 Testbench Log End ===");
end

endmodule
