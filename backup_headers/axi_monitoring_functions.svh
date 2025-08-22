// AXI4 Monitoring, Logging and Display Functions Header File
// This file contains functions for monitoring, logging and displaying test information

`ifndef AXI_MONITORING_FUNCTIONS_SVH
`define AXI_MONITORING_FUNCTIONS_SVH

// Include common definitions and functions
`include "axi_common_defs.svh"
`include "axi_utility_functions.svh"

// Logging and monitoring functions
function automatic void write_log(input string message);
    if (LOG_ENABLE) begin
        $display("[LOG] %s", message);
    end
endfunction

function automatic void write_debug_log(input string message);
    if (DEBUG_LOG_ENABLE) begin
        $display("[DEBUG] %s", message);
    end
endfunction

// Display functions for verification
function automatic void display_write_addr_payloads();
    $display("=== Write Address Payloads ===");
    foreach (write_addr_payloads[i]) begin
        $display("[%0d] test_count=%0d, addr=0x%08X, burst=%s, size=%0d(%s), id=0x%02X, len=%0d, valid=%b, phase=%0d",
            i, write_addr_payloads[i].test_count, write_addr_payloads[i].addr,
            get_burst_type_string(write_addr_payloads[i].burst),
            write_addr_payloads[i].size, size_to_string(write_addr_payloads[i].size),
            write_addr_payloads[i].id, write_addr_payloads[i].len,
            write_addr_payloads[i].valid, write_addr_payloads[i].phase);
    end
endfunction

function automatic void display_write_addr_payloads_with_stall();
    $display("=== Write Address Payloads with Stall ===");
    foreach (write_addr_payloads_with_stall[i]) begin
        $display("[%0d] test_count=%0d, addr=0x%08X, burst=%s, size=%0d(%s), id=0x%02X, len=%0d, valid=%b, phase=%0d",
            i, write_addr_payloads_with_stall[i].test_count, write_addr_payloads_with_stall[i].addr,
            get_burst_type_string(write_addr_payloads_with_stall[i].burst),
            write_addr_payloads_with_stall[i].size, size_to_string(write_addr_payloads_with_stall[i].size),
            write_addr_payloads_with_stall[i].id, write_addr_payloads_with_stall[i].len,
            write_addr_payloads_with_stall[i].valid, write_addr_payloads_with_stall[i].phase);
    end
endfunction

function automatic void display_write_data_payloads();
    $display("=== Write Data Payloads ===");
    foreach (write_data_payloads[i]) begin
        $display("[%0d] test_count=%0d, data=0x%08X, strb=0x%01X, last=%b, valid=%b, phase=%0d",
            i, write_data_payloads[i].test_count, write_data_payloads[i].data,
            write_data_payloads[i].strb, write_data_payloads[i].last,
            write_data_payloads[i].valid, write_data_payloads[i].phase);
    end
endfunction

function automatic void display_write_data_payloads_with_stall();
    $display("=== Write Data Payloads with Stall ===");
    foreach (write_data_payloads_with_stall[i]) begin
        $display("[%0d] test_count=%0d, data=0x%08X, strb=0x%01X, last=%b, valid=%b, phase=%0d",
            i, write_data_payloads_with_stall[i].test_count, write_data_payloads_with_stall[i].data,
            write_data_payloads_with_stall[i].strb, write_data_payloads_with_stall[i].last,
            write_data_payloads_with_stall[i].valid, write_data_payloads_with_stall[i].phase);
    end
endfunction

function automatic void display_read_addr_payloads();
    $display("=== Read Address Payloads ===");
    foreach (read_addr_payloads[i]) begin
        $display("[%0d] test_count=%0d, addr=0x%08X, burst=%s, size=%0d(%s), id=0x%02X, len=%0d, valid=%b, phase=%0d",
            i, read_addr_payloads[i].test_count, read_addr_payloads[i].addr,
            get_burst_type_string(read_addr_payloads[i].burst),
            read_addr_payloads[i].size, size_to_string(read_addr_payloads[i].size),
            read_addr_payloads[i].id, read_addr_payloads[i].len,
            read_addr_payloads[i].valid, read_addr_payloads[i].phase);
    end
endfunction

function automatic void display_read_addr_payloads_with_stall();
    $display("=== Read Address Payloads with Stall ===");
    foreach (read_addr_payloads_with_stall[i]) begin
        $display("[%0d] test_count=%0d, addr=0x%08X, burst=%s, size=%0d(%s), id=0x%02X, len=%0d, valid=%b, phase=%0d",
            i, read_addr_payloads_with_stall[i].test_count, read_addr_payloads_with_stall[i].addr,
            get_burst_type_string(read_addr_payloads_with_stall[i].burst),
            read_addr_payloads_with_stall[i].size, size_to_string(read_addr_payloads_with_stall[i].size),
            read_addr_payloads_with_stall[i].id, read_addr_payloads_with_stall[i].len,
            read_addr_payloads_with_stall[i].valid, read_addr_payloads_with_stall[i].phase);
    end
endfunction

function automatic void display_read_data_expected();
    $display("=== Read Data Expected Values ===");
    foreach (read_data_expected[i]) begin
        $display("[%0d] test_count=%0d, expected_data=0x%08X, expected_strobe=0x%01X, phase=%0d",
            i, read_data_expected[i].test_count, read_data_expected[i].expected_data,
            read_data_expected[i].expected_strobe, read_data_expected[i].phase);
    end
endfunction

function automatic void display_write_resp_expected();
    $display("=== Write Response Expected Values ===");
    foreach (write_resp_expected[i]) begin
        $display("[%0d] test_count=%0d, expected_resp=0x%02X, expected_id=0x%02X, phase=%0d",
            i, write_resp_expected[i].test_count, write_resp_expected[i].expected_resp,
            write_resp_expected[i].expected_id, write_resp_expected[i].phase);
    end
endfunction

function automatic void display_all_arrays();
    display_write_addr_payloads();
    display_write_addr_payloads_with_stall();
    display_write_data_payloads();
    display_write_data_payloads_with_stall();
    display_read_addr_payloads();
    display_read_addr_payloads_with_stall();
    display_read_data_expected();
    display_write_resp_expected();
endfunction

`endif // AXI_MONITORING_FUNCTIONS_SVH
