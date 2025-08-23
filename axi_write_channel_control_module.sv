// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// axi_write_channel_control_module.sv
// AXI4 Write Channel Control Module
// Auto-generated from axi_simple_dual_port_ram_tb_refactored.sv

`timescale 1ns/1ps

module axi_write_channel_control_module (
    // No ports - direct access to TOP hierarchy signals
);

// Include common definitions for parameters
`include "axi_common_defs.svh"

// Write Channel phase completion signal latches
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        `TOP_TB.write_addr_phase_done_latched <= 1'b0;
        `TOP_TB.write_data_phase_done_latched <= 1'b0;
        `TOP_TB.write_resp_phase_done_latched <= 1'b0;
    end else if (`TOP_TB.clear_phase_latches) begin
        // Clear write channel latched signals when clear signal is asserted
        `TOP_TB.write_addr_phase_done_latched <= 1'b0;
        `TOP_TB.write_data_phase_done_latched <= 1'b0;
        `TOP_TB.write_resp_phase_done_latched <= 1'b0;
    end else begin
        if (`TOP_TB.write_addr_phase_done) `TOP_TB.write_addr_phase_done_latched <= 1'b1;
        if (`TOP_TB.write_data_phase_done) `TOP_TB.write_data_phase_done_latched <= 1'b1;
        if (`TOP_TB.write_resp_phase_done) `TOP_TB.write_resp_phase_done_latched <= 1'b1;
    end
end

// Write Response Channel ready control (axi_b_ready)
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        `TOP_TB.write_ready_negate_index <= 0;
        `TOP_TB.axi_b_ready <= 1'b1;
    end else begin
        // Update write ready negate index
        if (`TOP_TB.write_ready_negate_index >= READY_NEGATE_ARRAY_LENGTH - 1) begin
            `TOP_TB.write_ready_negate_index <= 0;
        end else begin
            `TOP_TB.write_ready_negate_index <= `TOP_TB.write_ready_negate_index + 1;
        end
        
        // Control write response ready signal based on pulse array
        // Note: axi_b_ready is controlled by TB for testing purposes
        //       axi_aw_ready and axi_w_ready are controlled by DUT (wire signals)
        `TOP_TB.axi_b_ready <= !`TOP_TB.axi_b_ready_negate_pulses[`TOP_TB.write_ready_negate_index];
    end
end

// Write Address Channel Control Circuit
// Use local variables for state management
write_addr_state_t write_addr_state = WRITE_ADDR_IDLE;
logic [7:0] write_addr_phase_counter = 8'd0;
logic write_addr_phase_busy = 1'b0;
int write_addr_array_index = 0;

// Write Address Channel Control
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        write_addr_state <= WRITE_ADDR_IDLE;
        write_addr_phase_counter <= 8'd0;
        write_addr_phase_busy <= 1'b0;
        `TOP_TB.write_addr_phase_done <= 1'b0;
        write_addr_array_index <= 0;
        
        // AXI4 signals
        `TOP_TB.axi_aw_addr <= '0;
        `TOP_TB.axi_aw_burst <= '0;
        `TOP_TB.axi_aw_size <= '0;
        `TOP_TB.axi_aw_id <= '0;
        `TOP_TB.axi_aw_len <= '0;
        `TOP_TB.axi_aw_valid <= 1'b0;
    end else begin
        case (write_addr_state)
            2'b00: begin  // IDLE
                if (`TOP_TB.write_addr_phase_start) begin
                    write_addr_state <= WRITE_ADDR_ACTIVE;
                    write_addr_phase_busy <= 1'b1;
                    write_addr_phase_counter <= 8'd0;
                    // write_addr_array_index <= 0;  // Removed: Don't clear
                    `TOP_TB.write_addr_phase_done <= 1'b0;
                end
            end
            
            2'b01: begin  // ACTIVE
                // Highest priority: Ready signal check
                if (`TOP_TB.axi_aw_ready) begin
                    // Array range check
                    if (write_addr_array_index < `TOP_TB.write_addr_payloads_with_stall.size()) begin
                        // Address transmission completion check (when axi_aw_valid)
                        if (`TOP_TB.axi_aw_valid) begin
                            // Phase completion check based on current counter value
                            if (write_addr_phase_counter < PHASE_TEST_COUNT - 1) begin
                                `TOP_TB.axi_aw_addr <= `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].addr;
                                `TOP_TB.axi_aw_burst <= `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].burst;
                                `TOP_TB.axi_aw_size <= `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].size;
                                `TOP_TB.axi_aw_id <= `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].id;
                                `TOP_TB.axi_aw_len <= `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].len;
                                `TOP_TB.axi_aw_valid <= `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].valid;

                                // Debug output
                                write_debug_log($sformatf("Write Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                    write_addr_array_index, `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].test_count, 
                                    `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].addr, `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].burst, 
                                    `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].size, `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].id, 
                                    `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].len, `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].valid));

                                // Update array index
                                write_addr_array_index <= write_addr_array_index + 1;

                                // Phase continue: Increment counter
                                write_addr_phase_counter <= write_addr_phase_counter + 8'd1;
                                write_debug_log($sformatf("Write Addr Phase: Address sent, counter=%0d/%0d", 
                                    write_addr_phase_counter + 1, PHASE_TEST_COUNT));
                            end else begin
                                // Phase complete: Clear all signals
                                `TOP_TB.axi_aw_addr <= '0;
                                `TOP_TB.axi_aw_burst <= '0;
                                `TOP_TB.axi_aw_size <= '0;
                                `TOP_TB.axi_aw_id <= '0;
                                `TOP_TB.axi_aw_len <= '0;
                                `TOP_TB.axi_aw_valid <= 1'b0;
                                
                                // State transition
                                write_addr_state <= WRITE_ADDR_FINISH;
                                `TOP_TB.write_addr_phase_done <= 1'b1;
                                
                                write_debug_log("Write Addr Phase: Phase completed, all signals cleared");
                            end
                        end else begin
                            `TOP_TB.axi_aw_addr <= `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].addr;
                            `TOP_TB.axi_aw_burst <= `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].burst;
                            `TOP_TB.axi_aw_size <= `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].size;
                            `TOP_TB.axi_aw_id <= `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].id;
                            `TOP_TB.axi_aw_len <= `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].len;
                            `TOP_TB.axi_aw_valid <= `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].valid;

                            // Debug output
                            write_debug_log($sformatf("Write Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                write_addr_array_index, `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].test_count, 
                                `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].addr, `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].burst, 
                                `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].size, `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].id, 
                                `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].len, `TOP_TB.write_addr_payloads_with_stall[write_addr_array_index].valid));

                            // Update array index
                            write_addr_array_index <= write_addr_array_index + 1;
                        end
                    end else begin
                        // Array end: Clear all signals and complete phase
                        `TOP_TB.axi_aw_addr <= '0;
                        `TOP_TB.axi_aw_burst <= '0;
                        `TOP_TB.axi_aw_size <= '0;
                        `TOP_TB.axi_aw_id <= '0;
                        `TOP_TB.axi_aw_len <= '0;
                        `TOP_TB.axi_aw_valid <= 1'b0;
                        
                        write_addr_state <= WRITE_ADDR_FINISH;
                        `TOP_TB.write_addr_phase_done <= 1'b1;
                        
                        write_debug_log("Write Addr Phase: Array end reached, all signals cleared");
                    end
                end
                // When axi_aw_ready = 0, do nothing (keep current signals)
            end
            
            2'b10: begin  // FINISH
                // Finish processing: negate phase_done and return to IDLE
                `TOP_TB.write_addr_phase_done <= 1'b0;
                write_addr_phase_busy <= 1'b0;
                write_addr_state <= WRITE_ADDR_IDLE;
            end
        endcase
    end
end

// Write Data Channel Control Circuit
// Use local variables for state management
write_data_state_t write_data_state = WRITE_DATA_IDLE;
logic [7:0] write_data_phase_counter = 8'd0;
logic write_data_phase_busy = 1'b0;
int write_data_array_index = 0;

// Write Data Channel Control
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        write_data_state <= WRITE_DATA_IDLE;
        write_data_phase_counter <= 8'd0;
        write_data_phase_busy <= 1'b0;
        `TOP_TB.write_data_phase_done <= 1'b0;
        write_data_array_index <= 0;
        
        // AXI4 signals
        `TOP_TB.axi_w_data <= '0;
        `TOP_TB.axi_w_strb <= '0;
        `TOP_TB.axi_w_last <= 1'b0;
        `TOP_TB.axi_w_valid <= 1'b0;
    end else begin
        case (write_data_state)
            2'b00: begin  // IDLE
                if (`TOP_TB.write_data_phase_start) begin
                    write_data_state <= WRITE_DATA_ACTIVE;
                    write_data_phase_busy <= 1'b1;
                    write_data_phase_counter <= 8'd0;
                    `TOP_TB.write_data_phase_done <= 1'b0;
                end
            end
            
            2'b01: begin  // ACTIVE
                // Highest priority: Ready signal check
                if (`TOP_TB.axi_w_ready) begin
                    // Array range check
                    if (write_data_array_index < `TOP_TB.write_data_payloads_with_stall.size()) begin
                        // Phase completion check (when axi_w_last)
                        if (`TOP_TB.axi_w_last) begin
                            // Phase completion check based on current counter value
                            if (write_data_phase_counter < PHASE_TEST_COUNT - 1) begin
                                `TOP_TB.axi_w_data <= `TOP_TB.write_data_payloads_with_stall[write_data_array_index].data;
                                `TOP_TB.axi_w_strb <= `TOP_TB.write_data_payloads_with_stall[write_data_array_index].strb;
                                `TOP_TB.axi_w_last <= `TOP_TB.write_data_payloads_with_stall[write_data_array_index].last;
                                `TOP_TB.axi_w_valid <= `TOP_TB.write_data_payloads_with_stall[write_data_array_index].valid;
                                write_data_array_index <= write_data_array_index + 1;

                                // Debug output
                                write_debug_log($sformatf("Write Data[%0d]: test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d", 
                                    write_data_array_index, `TOP_TB.write_data_payloads_with_stall[write_data_array_index].test_count, 
                                    `TOP_TB.write_data_payloads_with_stall[write_data_array_index].data, `TOP_TB.write_data_payloads_with_stall[write_data_array_index].strb, 
                                    `TOP_TB.write_data_payloads_with_stall[write_data_array_index].last, `TOP_TB.write_data_payloads_with_stall[write_data_array_index].valid));

                                write_data_phase_counter <= write_data_phase_counter + 8'd1;
                                write_debug_log($sformatf("Write Data Phase: Burst completed, counter=%0d/%0d", 
                                    write_data_phase_counter + 1, PHASE_TEST_COUNT));
                            end else begin
                                // Phase complete: Clear all signals
                                `TOP_TB.axi_w_data <= '0;
                                `TOP_TB.axi_w_strb <= '0;
                                `TOP_TB.axi_w_last <= 1'b0;
                                `TOP_TB.axi_w_valid <= 1'b0;
                                
                                // State transition
                                write_data_state <= WRITE_DATA_FINISH;
                                `TOP_TB.write_data_phase_done <= 1'b1;
                                
                                write_debug_log("Write Data Phase: Phase completed, all signals cleared");
                            end
                        end else begin
                            // Output next payload
                            `TOP_TB.axi_w_data <= `TOP_TB.write_data_payloads_with_stall[write_data_array_index].data;
                            `TOP_TB.axi_w_strb <= `TOP_TB.write_data_payloads_with_stall[write_data_array_index].strb;
                            `TOP_TB.axi_w_last <= `TOP_TB.write_data_payloads_with_stall[write_data_array_index].last;
                            `TOP_TB.axi_w_valid <= `TOP_TB.write_data_payloads_with_stall[write_data_array_index].valid;

                            // Debug output
                            write_debug_log($sformatf("Write Data[%0d]: test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d", 
                                write_data_array_index, `TOP_TB.write_data_payloads_with_stall[write_data_array_index].test_count, 
                                `TOP_TB.write_data_payloads_with_stall[write_data_array_index].data, `TOP_TB.write_data_payloads_with_stall[write_data_array_index].strb, 
                                `TOP_TB.write_data_payloads_with_stall[write_data_array_index].last, `TOP_TB.write_data_payloads_with_stall[write_data_array_index].valid));

                            write_data_array_index <= write_data_array_index + 1;
                        end
                    end else begin
                        // Array end: Clear all signals and complete phase
                        `TOP_TB.axi_w_data <= '0;
                        `TOP_TB.axi_w_strb <= '0;
                        `TOP_TB.axi_w_last <= 1'b0;
                        `TOP_TB.axi_w_valid <= 1'b0;
                        
                        write_data_state <= WRITE_DATA_FINISH;
                        `TOP_TB.write_data_phase_done <= 1'b1;
                        
                        write_debug_log("Write Data Phase: Array end reached, all signals cleared");
                    end
                end
                // When axi_w_ready = 0, do nothing (keep current signals)
            end
            
            2'b10: begin  // FINISH
                // Finish processing: negate phase_done and return to IDLE
                `TOP_TB.write_data_phase_done <= 1'b0;
                write_data_phase_busy <= 1'b0;
                write_data_state <= WRITE_DATA_IDLE;
            end
        endcase
    end
end

// Write Response Channel Control Circuit
// Use local variables for state management
write_resp_state_t write_resp_state = WRITE_RESP_IDLE;
logic [7:0] write_resp_phase_counter = 8'd0;
logic write_resp_phase_busy = 1'b0;
int write_resp_array_index = 0;

// Write Response Channel Control
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        write_resp_state <= WRITE_RESP_IDLE;
        write_resp_phase_counter <= 8'd0;
        write_resp_phase_busy <= 1'b0;
        `TOP_TB.write_resp_phase_done <= 1'b0;
        write_resp_array_index <= 0;
    end else begin
        case (write_resp_state)
            2'b00: begin  // IDLE
                if (`TOP_TB.write_resp_phase_start) begin
                    write_resp_state <= WRITE_RESP_ACTIVE;
                    write_resp_phase_busy <= 1'b1;
                    write_resp_phase_counter <= 8'd0;
                    write_resp_array_index <= 0;
                    `TOP_TB.write_resp_phase_done <= 1'b0;
                    
                    // Debug output
                    write_debug_log("Phase 0: Write Response Channel started");
                end
            end
            
            2'b01: begin  // ACTIVE
                // Debug output for state transition
                write_debug_log("Write Resp Phase: State transition to ACTIVE");

                // Highest priority: Valid signal check
                if (`TOP_TB.axi_b_valid && `TOP_TB.axi_b_ready) begin
                    // Search for expected value (ID-based)
                    int found_index;
                    int i;
                    found_index = -1;
                    foreach (`TOP_TB.write_resp_expected[i]) begin
                        if (`TOP_TB.write_resp_expected[i].expected_id === `TOP_TB.axi_b_id) begin
                            found_index = i;
                            break;
                        end
                    end
                    
                    if (found_index >= 0) begin
                        // Response verification
                        if (`TOP_TB.axi_b_resp !== `TOP_TB.write_resp_expected[found_index].expected_resp) begin
                            $error("Write Response Mismatch: Expected %0d, Got %0d for ID %0d", 
                                   `TOP_TB.write_resp_expected[found_index].expected_resp, `TOP_TB.axi_b_resp, `TOP_TB.axi_b_id);
                            $finish;
                        end
                        
                        // Debug output
                        write_debug_log($sformatf("Write Response: ID=%0d, Resp=%0d, Expected=%0d", 
                            `TOP_TB.axi_b_id, `TOP_TB.axi_b_resp, `TOP_TB.write_resp_expected[found_index].expected_resp));
                        
                        // Phase completion check based on current counter value
                        if (write_resp_phase_counter < PHASE_TEST_COUNT - 1) begin
                            // Phase continue: Increment counter
                            write_resp_phase_counter <= write_resp_phase_counter + 8'd1;
                            write_debug_log($sformatf("Write Resp Phase: Response received, counter=%0d/%0d", 
                                write_resp_phase_counter + 1, PHASE_TEST_COUNT));
                        end else begin
                            // Phase complete
                            // State transition
                            write_resp_state <= WRITE_RESP_FINISH;
                            `TOP_TB.write_resp_phase_done <= 1'b1;
                            
                            write_debug_log("Write Resp Phase: Phase completed, all signals cleared");
                        end
                    end else begin
                        $error("Write Response: No expected value found for ID %0d", `TOP_TB.axi_b_id);
                        $finish;
                    end
                end
                // When axi_b_valid = 0 or axi_b_ready = 0, do nothing (keep current signals)
            end
            
            2'b10: begin  // FINISH
                // Finish processing: negate phase_done and return to IDLE
                `TOP_TB.write_resp_phase_done <= 1'b0;
                write_resp_phase_busy <= 1'b0;
                write_resp_state <= WRITE_RESP_IDLE;
                
                // Debug output
                write_debug_log("Write Resp Phase: State transition to FINISH");
            end
        endcase
    end
end

endmodule
