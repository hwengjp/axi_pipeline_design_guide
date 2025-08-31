// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// AXI4 Monitoring and Logging Functions

`ifndef AXI_MONITORING_FUNCTIONS_SVH
`define AXI_MONITORING_FUNCTIONS_SVH

// Include common definitions
`include "axi_common_defs.svh"

// Function: write_log
function automatic void write_log(input string message);
    if (LOG_ENABLE) begin
        $display("[%0t] [LOG] %s", $time, message);
    end
endfunction

// Function: write_debug_log
function automatic void write_debug_log(input string message);
    if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
        $display("[%0t] [DEBUG] %s", $time, message);
    end
endfunction

// Function: display_write_addr_payloads
function automatic void display_write_addr_payloads();
    write_debug_log("=== Write Address Payloads ===");
    foreach (write_addr_payloads[i]) begin
        write_addr_payload_t payload = write_addr_payloads[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d, valid=%0d, phase=%0d, size_strategy=%s",
            i, payload.test_count, payload.addr, payload.burst, size_to_string(payload.size), payload.id, payload.len, payload.valid, payload.phase, payload.size_strategy));
    end
endfunction

// Function: display_write_addr_payloads_with_stall
function automatic void display_write_addr_payloads_with_stall();
    write_debug_log("=== Write Address Payloads with Stall ===");
    foreach (write_addr_payloads_with_stall[i]) begin
        write_addr_payload_t payload = write_addr_payloads_with_stall[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d, valid=%0d, phase=%0d, size_strategy=%s",
            i, payload.test_count, payload.addr, payload.burst, size_to_string(payload.size), payload.id, payload.len, payload.valid, payload.phase, payload.size_strategy));
    end
endfunction

// Function: display_write_data_payloads
function automatic void display_write_data_payloads();
    write_debug_log("=== Write Data Payloads ===");
    foreach (write_data_payloads[i]) begin
        write_data_payload_t payload = write_data_payloads[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.data, payload.strb, payload.last, payload.valid, payload.phase));
    end
endfunction

// Function: display_write_data_payloads_with_stall
function automatic void display_write_data_payloads_with_stall();
    write_debug_log("=== Write Data Payloads with Stall ===");
    foreach (write_data_payloads_with_stall[i]) begin
        write_data_payload_t payload = write_data_payloads_with_stall[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d, phase=%0d",
            i, payload.test_count, payload.data, payload.strb, payload.last, payload.valid, payload.phase));
    end
endfunction

// Function: display_read_addr_payloads
function automatic void display_read_addr_payloads();
    write_debug_log("=== Read Address Payloads ===");
    foreach (read_addr_payloads[i]) begin
        read_addr_payload_t payload = read_addr_payloads[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d, valid=%0d, phase=%0d, size_strategy=%s",
            i, payload.test_count, payload.addr, payload.burst, size_to_string(payload.size), payload.id, payload.len, payload.valid, payload.phase, payload.size_strategy));
    end
endfunction

// Function: display_read_addr_payloads_with_stall
function automatic void display_read_addr_payloads_with_stall();
    write_debug_log("=== Read Address Payloads with Stall ===");
    foreach (read_addr_payloads_with_stall[i]) begin
        read_addr_payload_t payload = read_addr_payloads_with_stall[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d, valid=%0d, phase=%0d, size_strategy=%s",
            i, payload.test_count, payload.addr, payload.burst, size_to_string(payload.size), payload.id, payload.len, payload.valid, payload.phase, payload.size_strategy));
    end
endfunction

// Function: display_read_data_expected
function automatic void display_read_data_expected();
    write_debug_log("=== Read Data Expected ===");
    foreach (read_data_expected[i]) begin
        read_data_expected_t expected = read_data_expected[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, expected_data=0x%h, expected_strobe=0x%h, phase=%0d",
            i, expected.test_count, expected.expected_data, expected.expected_strobe, expected.phase));
    end
endfunction

// Function: display_write_resp_expected
function automatic void display_write_resp_expected();
    write_debug_log("=== Write Response Expected ===");
    foreach (write_resp_expected[i]) begin
        write_resp_expected_t expected = write_resp_expected[i];
        write_debug_log($sformatf("[%0d] test_count=%0d, expected_resp=%0d, expected_id=%0d, phase=%0d",
            i, expected.test_count, expected.expected_resp, expected.expected_id, expected.phase));
    end
endfunction

// Function: display_byte_verification_read_addr_payloads
function automatic void display_byte_verification_read_addr_payloads();
    if (BYTE_VERIFICATION_ENABLE) begin
        write_debug_log("=== Byte Verification Read Address Payloads ===");
        foreach (byte_verification_read_addr_payloads[i]) begin
            byte_verification_read_addr_payload_t payload = byte_verification_read_addr_payloads[i];
            write_debug_log($sformatf("[%0d] test_count=%0d, addr=0x%h, size=%0d, id=%0d, len=%0d, valid=%0d, phase=%0d",
                i, payload.test_count, payload.addr, payload.size, payload.id, payload.len, payload.valid, payload.phase));
        end
    end else begin
        write_debug_log("=== Byte Verification Read Address Payloads (Disabled) ===");
    end
endfunction

// Function: display_byte_verification_expected
function automatic void display_byte_verification_expected();
    if (BYTE_VERIFICATION_ENABLE) begin
        write_debug_log("=== Byte Verification Expected Values ===");
        foreach (byte_verification_expected[i]) begin
            byte_verification_expected_t expected = byte_verification_expected[i];
            write_debug_log($sformatf("[%0d] test_count=%0d, expected_byte=0x%02x, byte_addr=0x%h, phase=%0d",
                i, expected.test_count, expected.expected_byte, expected.byte_addr, expected.phase));
        end
    end else begin
        write_debug_log("=== Byte Verification Expected Values (Disabled) ===");
    end
endfunction

// Function: display_all_arrays
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
    
    // Display byte verification arrays if enabled
    display_byte_verification_read_addr_payloads();
    display_byte_verification_expected();
    
    write_debug_log("=== All Arrays Displayed ===");
endfunction

`endif // AXI_MONITORING_FUNCTIONS_SVH
