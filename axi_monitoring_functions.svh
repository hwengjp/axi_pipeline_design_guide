// axi_monitoring_functions.svh
// Auto-generated from axi_simple_dual_port_ram_tb.sv
// DO NOT MODIFY - This file is auto-generated

`ifndef AXI_MONITORING_FUNCTIONS_SVH
`define AXI_MONITORING_FUNCTIONS_SVH

// Include common definitions
`include "axi_common_defs.svh"

// Function: write_log
// Extracted from original testbench

function automatic void write_log(input string message);
    if (LOG_ENABLE) begin
        $display("[%0t] %s", $time, message);
    end
endfunction

// Function: write_debug_log
// Extracted from original testbench

function automatic void write_debug_log(input string message);
    if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
        $display("[%0t] [DEBUG] %s", $time, message);
    end
endfunction

// Function: display_write_addr_payloads
// Extracted from original testbench

function automatic void display_write_addr_payloads();
    write_debug_log("=== Write Address Payloads ===");
    foreach (write_addr_payloads[i]) begin
        write_addr_payload_t payload = write_addr_payloads[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.addr, payload.burst, size_to_string(payload.size), payload.id, payload.len, payload.valid, payload.phase));
    end
endfunction

// Function: display_write_addr_payloads_with_stall
// Extracted from original testbench

function automatic void display_write_addr_payloads_with_stall();
    write_debug_log("=== Write Address Payloads with Stall ===");
    foreach (write_addr_payloads_with_stall[i]) begin
        write_addr_payload_t payload = write_addr_payloads_with_stall[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.addr, payload.burst, size_to_string(payload.size), payload.id, payload.len, payload.valid, payload.phase));
    end
endfunction

// Function: display_write_data_payloads
// Extracted from original testbench

function automatic void display_write_data_payloads();
    write_debug_log("=== Write Data Payloads ===");
    foreach (write_data_payloads[i]) begin
        write_data_payload_t payload = write_data_payloads[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.data, payload.strb, payload.last, payload.valid, payload.phase));
    end
endfunction

// Function: display_write_data_payloads_with_stall
// Extracted from original testbench

function automatic void display_write_data_payloads_with_stall();
    write_debug_log("=== Write Data Payloads with Stall ===");
    foreach (write_data_payloads_with_stall[i]) begin
        write_data_payload_t payload = write_data_payloads_with_stall[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.data, payload.strb, payload.last, payload.valid, payload.phase));
    end
endfunction

// Function: display_read_addr_payloads
// Extracted from original testbench

function automatic void display_read_addr_payloads();
    write_debug_log("=== Read Address Payloads ===");
    foreach (read_addr_payloads[i]) begin
        read_addr_payload_t payload = read_addr_payloads[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.addr, payload.burst, size_to_string(payload.size), payload.id, payload.len, payload.valid, payload.phase));
    end
endfunction

// Function: display_read_addr_payloads_with_stall
// Extracted from original testbench

function automatic void display_read_addr_payloads_with_stall();
    write_debug_log("=== Read Address Payloads with Stall ===");
    foreach (read_addr_payloads_with_stall[i]) begin
        read_addr_payload_t payload = read_addr_payloads_with_stall[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.addr, payload.burst, size_to_string(payload.size), payload.id, payload.len, payload.valid, payload.phase));
    end
endfunction

// Function: display_read_data_expected
// Extracted from original testbench

function automatic void display_read_data_expected();
    write_debug_log("=== Read Data Expected ===");
    foreach (read_data_expected[i]) begin
        read_data_expected_t expected = read_data_expected[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, expected_data=0x%h, expected_strobe=0x%h, phase=%0d",
            i, expected.test_count, expected.expected_data, expected.expected_strobe, expected.phase));
    end
endfunction

// Function: display_write_resp_expected
// Extracted from original testbench

function automatic void display_write_resp_expected();
    write_debug_log("=== Write Response Expected ===");
    foreach (write_resp_expected[i]) begin
        write_resp_expected_t expected = write_resp_expected[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, expected_resp=%0d, expected_id=%0d, phase=%0d",
            i, expected.test_count, expected.expected_resp, expected.expected_id, expected.phase));
    end
endfunction

// Function: display_all_arrays
// Extracted from original testbench

function automatic void display_all_arrays();
    write_debug_log("=== Displaying All Generated Arrays ===");
    display_write_addr_payloads();
    display_write_addr_payloads_with_stall();
    display_write_data_payloads();
    display_write_data_payloads_with_stall();
    display_read_addr_payloads();
    display_read_addr_payloads_with_stall();
    display_read_data_expected();
    display_write_resp_expected();
    write_debug_log("=== All Arrays Displayed ===");
endfunction

`endif // AXI_MONITORING_FUNCTIONS_SVH
