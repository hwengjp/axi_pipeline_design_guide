// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// AXI4 Read Channel Control Module

`timescale 1ns/1ps

module axi_read_channel_control_module (
    // No ports - direct access to TOP hierarchy signals
);

// Include common definitions for parameters
`include "axi_common_defs.svh"

// Read Channel phase completion signal latches
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        `TOP_TB.read_addr_phase_done_latched <= 1'b0;
        `TOP_TB.read_data_phase_done_latched <= 1'b0;
    end else if (`TOP_TB.clear_phase_latches) begin
        // Clear read channel latched signals when clear signal is asserted
        `TOP_TB.read_addr_phase_done_latched <= 1'b0;
        `TOP_TB.read_data_phase_done_latched <= 1'b0;
    end else begin
        if (`TOP_TB.read_addr_phase_done) `TOP_TB.read_addr_phase_done_latched <= 1'b1;
        if (`TOP_TB.read_data_phase_done) `TOP_TB.read_data_phase_done_latched <= 1'b1;
    end
end

// Read Channel ready control (axi_r_ready)
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        `TOP_TB.read_ready_negate_index <= 0;
        `TOP_TB.axi_r_ready <= 1'b1;
    end else begin
        // Update read ready negate index
        if (`TOP_TB.read_ready_negate_index >= READY_NEGATE_ARRAY_LENGTH - 1) begin
            `TOP_TB.read_ready_negate_index <= 0;
        end else begin
            `TOP_TB.read_ready_negate_index <= `TOP_TB.read_ready_negate_index + 1;
        end
        
        // Control read ready signal based on pulse array
        // Note: axi_r_ready is controlled by TB for testing purposes
        `TOP_TB.axi_r_ready <= !`TOP_TB.axi_r_ready_negate_pulses[`TOP_TB.read_ready_negate_index];
    end
end

// Read Address Channel Control Circuit
// Use local variables for state management
read_addr_state_t read_addr_state = READ_ADDR_IDLE;
logic [7:0] read_addr_phase_counter = 8'd0;
logic read_addr_phase_busy = 1'b0;
int read_addr_array_index = 0;

// Read Address Channel Control
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        read_addr_state <= READ_ADDR_IDLE;
        read_addr_phase_counter <= 8'd0;
        read_addr_phase_busy <= 1'b0;
        `TOP_TB.read_addr_phase_done <= 1'b0;
        read_addr_array_index <= 0;
        
        // AXI4 signals
        `TOP_TB.axi_ar_addr <= '0;
        `TOP_TB.axi_ar_burst <= '0;
        `TOP_TB.axi_ar_size <= '0;
        `TOP_TB.axi_ar_id <= '0;
        `TOP_TB.axi_ar_len <= '0;
        `TOP_TB.axi_ar_valid <= 1'b0;
    end else begin
        case (read_addr_state)
            2'b00: begin  // IDLE
                if (`TOP_TB.read_addr_phase_start) begin
                    read_addr_state <= READ_ADDR_ACTIVE;
                    read_addr_phase_busy <= 1'b1;
                    read_addr_phase_counter <= 8'd0;
                    `TOP_TB.read_addr_phase_done <= 1'b0;
                end
            end
            
            2'b01: begin  // ACTIVE
                // Highest priority: Ready signal check
                if (`TOP_TB.axi_ar_ready) begin
                    // Array range check
                    if (read_addr_array_index < `TOP_TB.read_addr_payloads_with_stall.size()) begin
                        // Address transmission completion check (when axi_ar_valid)
                        if (`TOP_TB.axi_ar_valid) begin
                            // Phase completion check based on current counter value
                            if (read_addr_phase_counter < PHASE_TEST_COUNT - 1) begin
                                `TOP_TB.axi_ar_addr <= `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].addr;
                                `TOP_TB.axi_ar_burst <= `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].burst;
                                `TOP_TB.axi_ar_size <= `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].size;
                                `TOP_TB.axi_ar_id <= `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].id;
                                `TOP_TB.axi_ar_len <= `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].len;
                                `TOP_TB.axi_ar_valid <= `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].valid;

                                // Debug output
                                write_debug_log($sformatf("Read Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                    read_addr_array_index, `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].test_count, 
                                    `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].addr, `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].burst, 
                                    `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].size, `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].id, 
                                    `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].len, `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].valid));

                                // Update array index
                                read_addr_array_index <= read_addr_array_index + 1;

                                // Phase continue: Increment counter
                                read_addr_phase_counter <= read_addr_phase_counter + 8'd1;
                                write_debug_log($sformatf("Read Addr Phase: Address sent, counter=%0d/%0d", 
                                    read_addr_phase_counter + 1, PHASE_TEST_COUNT));
                            end else begin
                                // Phase complete: Clear all signals
                                `TOP_TB.axi_ar_addr <= '0;
                                `TOP_TB.axi_ar_burst <= '0;
                                `TOP_TB.axi_ar_size <= '0;
                                `TOP_TB.axi_ar_id <= '0;
                                `TOP_TB.axi_ar_len <= '0;
                                `TOP_TB.axi_ar_valid <= 1'b0;
                                
                                // State transition
                                read_addr_state <= READ_ADDR_FINISH;
                                `TOP_TB.read_addr_phase_done <= 1'b1;
                                
                                write_debug_log("Read Addr Phase: Phase completed, all signals cleared");
                            end
                        end else begin
                            // Output next payload
                            `TOP_TB.axi_ar_addr <= `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].addr;
                            `TOP_TB.axi_ar_burst <= `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].burst;
                            `TOP_TB.axi_ar_size <= `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].size;
                            `TOP_TB.axi_ar_id <= `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].id;
                            `TOP_TB.axi_ar_len <= `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].len;
                            `TOP_TB.axi_ar_valid <= `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].valid;

                            // Debug output
                            write_debug_log($sformatf("Read Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                read_addr_array_index, `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].test_count, 
                                `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].addr, `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].burst, 
                                `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].size, `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].id, 
                                `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].len, `TOP_TB.read_addr_payloads_with_stall[read_addr_array_index].valid));

                            // Update array index
                            read_addr_array_index <= read_addr_array_index + 1;
                        end
                    end else begin
                        // Array end: Clear all signals and complete phase
                        `TOP_TB.axi_ar_addr <= '0;
                        `TOP_TB.axi_ar_burst <= '0;
                        `TOP_TB.axi_ar_size <= '0;
                        `TOP_TB.axi_ar_id <= '0;
                        `TOP_TB.axi_ar_len <= '0;
                        `TOP_TB.axi_ar_valid <= 1'b0;
                        
                        read_addr_state <= READ_ADDR_FINISH;
                        `TOP_TB.read_addr_phase_done <= 1'b1;
                        
                        write_debug_log("Read Addr Phase: Array end reached, all signals cleared");
                    end
                end
                // When axi_ar_ready = 0, do nothing (keep current signals)
            end
            
            2'b10: begin  // FINISH
                // Finish processing: negate phase_done and return to IDLE
                `TOP_TB.read_addr_phase_done <= 1'b0;
                read_addr_phase_busy <= 1'b0;
                read_addr_state <= READ_ADDR_IDLE;
            end
        endcase
    end
end

// Read Data Channel Control Circuit
// Use local variables for state management
read_data_state_t read_data_state = READ_DATA_IDLE;
logic [7:0] read_data_phase_counter = 8'd0;
logic read_data_phase_busy = 1'b0;
int read_data_array_index = 0;

// Read Data Channel Control
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        read_data_state <= READ_DATA_IDLE;
        read_data_phase_counter <= 8'd0;
        read_data_phase_busy <= 1'b0;
        `TOP_TB.read_data_phase_done <= 1'b0;
        read_data_array_index <= 0;
    end else begin
        case (read_data_state)
            2'b00: begin  // IDLE
                if (`TOP_TB.read_data_phase_start) begin
                    read_data_state <= READ_DATA_ACTIVE;
                    read_data_phase_busy <= 1'b1;
                    read_data_phase_counter <= 8'd0;
                    `TOP_TB.read_data_phase_done <= 1'b0;
                end
            end
            
            2'b01: begin  // ACTIVE
                // Highest priority: Valid signal check
                if (`TOP_TB.axi_r_valid && `TOP_TB.axi_r_ready) begin
                    // Array range check
                    if (read_data_array_index < `TOP_TB.read_data_expected.size()) begin
                        // Burst completion check (when last=1)
                        if (`TOP_TB.axi_r_last) begin
                            // Phase completion check based on current counter value
                            if (read_data_phase_counter < PHASE_TEST_COUNT - 1) begin
                                // Data verification (only for valid strobe bytes)
                                if (!check_read_data(`TOP_TB.axi_r_data, `TOP_TB.read_data_expected[read_data_array_index].expected_data, `TOP_TB.read_data_expected[read_data_array_index].expected_strobe)) begin
                                    $error("Read Data Mismatch at index %0d: Expected 0x%h, Got 0x%h", 
                                        read_data_array_index, `TOP_TB.read_data_expected[read_data_array_index].expected_data, `TOP_TB.axi_r_data);
                                    $finish;
                                end
                        
                                // Debug output
                                write_debug_log($sformatf("Read Data[%0d]: test_count=%0d, data=0x%h, expected=0x%h, expected_strobe=0x%h, last=%0d", 
                                    read_data_array_index, `TOP_TB.read_data_expected[read_data_array_index].test_count, `TOP_TB.axi_r_data, 
                                    `TOP_TB.read_data_expected[read_data_array_index].expected_data, `TOP_TB.read_data_expected[read_data_array_index].expected_strobe, `TOP_TB.axi_r_last));

                                // Update array index
                                read_data_array_index <= read_data_array_index + 1;

                                // Phase continue: Increment counter
                                read_data_phase_counter <= read_data_phase_counter + 8'd1;
                                write_debug_log($sformatf("Read Data Phase: Burst completed, counter=%0d/%0d", 
                                    read_data_phase_counter + 1, PHASE_TEST_COUNT));
                            end else begin
                                // Phase complete
                                // Update array index
                                read_data_array_index <= read_data_array_index + 1;

                                // State transition
                                read_data_state <= READ_DATA_FINISH;
                                `TOP_TB.read_data_phase_done <= 1'b1;
                                
                                write_debug_log("Read Data Phase: Phase completed, all signals cleared");
                            end
                        end else begin
                            // Data verification (only for bytes with valid strobe)
                            if (!check_read_data(`TOP_TB.axi_r_data, `TOP_TB.read_data_expected[read_data_array_index].expected_data, `TOP_TB.read_data_expected[read_data_array_index].expected_strobe)) begin
                                $error("Read Data Mismatch at index %0d: Expected 0x%h, Got 0x%h", 
                                       read_data_array_index, `TOP_TB.read_data_expected[read_data_array_index].expected_data, `TOP_TB.axi_r_data);
                                $finish;
                            end
                        
                            // Debug output
                            write_debug_log($sformatf("Read Data[%0d]: test_count=%0d, data=0x%h, expected=0x%h, expected_strobe=0x%h, last=%0d", 
                                read_data_array_index, `TOP_TB.read_data_expected[read_data_array_index].test_count, `TOP_TB.axi_r_data, 
                                `TOP_TB.read_data_expected[read_data_array_index].expected_data, `TOP_TB.read_data_expected[read_data_array_index].expected_strobe, `TOP_TB.axi_r_last));

                            // Update array index
                            read_data_array_index <= read_data_array_index + 1;
                        end
                    end else begin
                        read_data_state <= READ_DATA_FINISH;
                        `TOP_TB.read_data_phase_done <= 1'b1;
                        
                        write_debug_log("Read Data Phase: Array end reached, all signals cleared");
                    end
                end
                // When axi_r_valid = 0 or axi_r_ready = 0, do nothing (keep current signals)
            end
            
            2'b10: begin  // FINISH
                // Finish processing: negate phase_done and return to IDLE
                `TOP_TB.read_data_phase_done <= 1'b0;
                read_data_phase_busy <= 1'b0;
                read_data_state <= READ_DATA_IDLE;
            end
        endcase
    end
end

endmodule
