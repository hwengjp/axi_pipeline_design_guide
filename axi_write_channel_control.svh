// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// axi_write_channel_control.svh
// Write Channel Control Logic
// DO NOT MODIFY - This file is auto-generated

`ifndef AXI_WRITE_CHANNEL_CONTROL_SVH
`define AXI_WRITE_CHANNEL_CONTROL_SVH

// Include common definitions
`include "axi_common_defs.svh"

// Write Address Channel Control Circuit
typedef enum logic [1:0] {
    WRITE_ADDR_IDLE,        // Idle state
    WRITE_ADDR_ACTIVE,      // Active state (including stall processing)
    WRITE_ADDR_FINISH       // Finish processing state
} write_addr_state_t;

write_addr_state_t write_addr_state = WRITE_ADDR_IDLE;
logic [7:0] write_addr_phase_counter = 8'd0;
logic write_addr_phase_busy = 1'b0;
int write_addr_array_index = 0;

// Write Address Channel Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_addr_state <= WRITE_ADDR_IDLE;
        write_addr_phase_counter <= 8'd0;
        write_addr_phase_busy <= 1'b0;
        write_addr_phase_done <= 1'b0;
        write_addr_array_index <= 0;
        
        // AXI4 signals
        axi_aw_addr <= '0;
        axi_aw_burst <= '0;
        axi_aw_size <= '0;
        axi_aw_id <= '0;
        axi_aw_len <= '0;
        axi_aw_valid <= 1'b0;
    end else begin
        case (write_addr_state)
            WRITE_ADDR_IDLE: begin
                if (write_addr_phase_start) begin
                    write_addr_state <= WRITE_ADDR_ACTIVE;
                    write_addr_phase_busy <= 1'b1;
                    write_addr_phase_counter <= 8'd0;
                    write_addr_phase_done <= 1'b0;
                end
            end
            
            WRITE_ADDR_ACTIVE: begin
                // Highest priority: Ready signal check
                if (axi_aw_ready) begin
                    // Array range check
                    if (write_addr_array_index < write_addr_payloads.size()) begin
                        // Get payload
                        automatic write_addr_payload_t payload = write_addr_payloads[write_addr_array_index];
                        
                        // Burst completion check (when len=0)
                        if (payload.len == 0) begin
                            // Phase completion check based on current counter value
                            if (write_addr_phase_counter < PHASE_TEST_COUNT - 1) begin
                                // Output next payload
                                axi_aw_addr <= payload.addr;
                                axi_aw_burst <= payload.burst;
                                axi_aw_size <= payload.size;
                                axi_aw_id <= payload.id;
                                axi_aw_len <= payload.len;
                                axi_aw_valid <= payload.valid;

                                // Debug output
                                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                    write_debug_log($sformatf("Write Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                        write_addr_array_index, payload.test_count, payload.addr, payload.burst, 
                                        payload.size, payload.id, payload.len, payload.valid));
                                end

                                // Update array index
                                write_addr_array_index <= write_addr_array_index + 1;

                                // Phase continue: Increment counter
                                write_addr_phase_counter <= write_addr_phase_counter + 8'd1;
                                write_debug_log($sformatf("Write Addr Phase: Address sent, counter=%0d/%0d", 
                                    write_addr_phase_counter + 1, PHASE_TEST_COUNT));
                            end else begin
                                // Phase complete: Clear all signals
                                axi_aw_addr <= '0;
                                axi_aw_burst <= '0;
                                axi_aw_size <= '0;
                                axi_aw_id <= '0;
                                axi_aw_len <= '0;
                                axi_aw_valid <= 1'b0;
                                
                                // State transition
                                write_addr_state <= WRITE_ADDR_FINISH;
                                write_addr_phase_done <= 1'b1;
                                
                                write_debug_log("Write Addr Phase: Phase completed, all signals cleared");
                            end
                        end else begin
                            // Output next payload
                            axi_aw_addr <= payload.addr;
                            axi_aw_burst <= payload.burst;
                            axi_aw_size <= payload.size;
                            axi_aw_id <= payload.id;
                            axi_aw_len <= payload.len;
                            axi_aw_valid <= payload.valid;

                            // Debug output
                            if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                write_debug_log($sformatf("Write Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                    write_addr_array_index, payload.test_count, payload.addr, payload.burst, 
                                    payload.size, payload.id, payload.len, payload.valid));
                            end

                            write_addr_array_index <= write_addr_array_index + 1;
                        end
                    end else begin
                        // Array end: Clear all signals and complete phase
                        axi_aw_addr <= '0;
                        axi_aw_burst <= '0';
                        axi_aw_size <= '0';
                        axi_aw_id <= '0';
                        axi_aw_len <= '0';
                        axi_aw_valid <= 1'b0;
                        
                        write_addr_state <= WRITE_ADDR_FINISH;
                        write_addr_phase_done <= 1'b1;
                        
                        write_debug_log("Write Addr Phase: Array end reached, all signals cleared");
                    end
                end
                // When axi_aw_ready = 0, do nothing (keep current signals)
            end
            
            WRITE_ADDR_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                write_addr_phase_done <= 1'b0;
                write_addr_phase_busy <= 1'b0;
                write_addr_state <= WRITE_ADDR_IDLE;
            end
        endcase
    end
end

// Write Data Channel Control Circuit
typedef enum logic [1:0] {
    WRITE_DATA_IDLE,        // Idle state
    WRITE_DATA_ACTIVE,      // Active state (including stall processing)
    WRITE_DATA_FINISH       // Finish processing state
} write_data_state_t;

write_data_state_t write_data_state = WRITE_DATA_IDLE;
logic [7:0] write_data_phase_counter = 8'd0;
logic write_data_phase_busy = 1'b0;
int write_data_array_index = 0;

// Write Data Channel Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_data_state <= WRITE_DATA_IDLE;
        write_data_phase_counter <= 8'd0;
        write_data_phase_busy <= 1'b0;
        write_data_phase_done <= 1'b0;
        write_data_array_index <= 0;
        
        // AXI4 signals
        axi_w_data <= '0;
        axi_w_strb <= '0;
        axi_w_last <= 1'b0;
        axi_w_valid <= 1'b0;
    end else begin
        case (write_data_state)
            WRITE_DATA_IDLE: begin
                if (write_data_phase_start) begin
                    write_data_state <= WRITE_DATA_ACTIVE;
                    write_data_phase_busy <= 1'b1;
                    write_data_phase_counter <= 8'd0;
                    write_data_phase_done <= 1'b0;
                end
            end
            
            WRITE_DATA_ACTIVE: begin
                // Highest priority: Ready signal check
                if (axi_w_ready) begin
                    // Array range check
                    if (write_data_array_index < write_data_payloads.size()) begin
                        // Get payload
                        automatic write_data_payload_t payload = write_data_payloads[write_data_array_index];
                        
                        // Burst completion check (when last=1)
                        if (payload.last) begin
                            // Phase completion check based on current counter value
                            if (write_data_phase_counter < PHASE_TEST_COUNT - 1) begin
                                // Output next payload
                                axi_w_data <= payload.data;
                                axi_w_strb <= payload.strb;
                                axi_w_last <= payload.last;
                                axi_w_valid <= payload.valid;

                                // Debug output
                                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                    write_debug_log($sformatf("Write Data[%0d]: test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d", 
                                        write_data_array_index, payload.test_count, payload.data, payload.strb, 
                                        payload.last, payload.valid));
                                end

                                write_data_phase_counter <= write_data_phase_counter + 8'd1;
                                write_debug_log($sformatf("Write Data Phase: Burst completed, counter=%0d/%0d", 
                                    write_data_phase_counter + 1, PHASE_TEST_COUNT));
                            end else begin
                                // Phase complete: Clear all signals
                                axi_w_data <= '0;
                                axi_w_strb <= '0';
                                axi_w_last <= 1'b0;
                                axi_w_valid <= 1'b0;
                                
                                // State transition
                                write_data_state <= WRITE_DATA_FINISH;
                                write_data_phase_done <= 1'b1;
                                
                                write_debug_log("Write Data Phase: Phase completed, all signals cleared");
                            end
                        end else begin
                            // Output next payload
                            axi_w_data <= payload.data;
                            axi_w_strb <= payload.strb;
                            axi_w_last <= payload.last;
                            axi_w_valid <= payload.valid;

                            // Debug output
                            if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                write_debug_log($sformatf("Write Data[%0d]: test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d", 
                                    write_data_array_index, payload.test_count, payload.data, payload.strb, 
                                    payload.last, payload.valid));
                            end

                            write_data_array_index <= write_data_array_index + 1;
                        end
                    end else begin
                        // Array end: Clear all signals and complete phase
                        axi_w_data <= '0;
                        axi_w_strb <= '0';
                        axi_w_last <= 1'b0;
                        axi_w_valid <= 1'b0;
                        
                        write_data_state <= WRITE_DATA_FINISH;
                        write_data_phase_done <= 1'b1;
                        
                        write_debug_log("Write Data Phase: Array end reached, all signals cleared");
                    end
                end
                // When axi_w_ready = 0, do nothing (keep current signals)
            end
            
            WRITE_DATA_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                write_data_phase_done <= 1'b0;
                write_data_phase_busy <= 1'b0;
                write_data_state <= WRITE_DATA_IDLE;
            end
        endcase
    end
end

// Write Response Channel Control Circuit
typedef enum logic [1:0] {
    WRITE_RESP_IDLE,        // Idle state
    WRITE_RESP_ACTIVE,      // Active state (including expected value verification)
    WRITE_RESP_FINISH       // Finish processing state
} write_resp_state_t;

write_resp_state_t write_resp_state = WRITE_RESP_IDLE;
logic [7:0] write_resp_phase_counter = 8'd0;
logic write_resp_phase_busy = 1'b0;
int write_resp_array_index = 0;

// Write Response Channel Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_resp_state <= WRITE_RESP_IDLE;
        write_resp_phase_counter <= 8'd0;
        write_resp_phase_busy <= 1'b0;
        write_resp_phase_done <= 1'b0;
        write_resp_array_index <= 0;
    end else begin
        case (write_resp_state)
            WRITE_RESP_IDLE: begin
                if (write_resp_phase_start) begin
                    write_resp_state <= WRITE_RESP_ACTIVE;
                    write_resp_phase_busy <= 1'b1;
                    write_resp_phase_counter <= 8'd0;
                    write_resp_array_index <= 0;
                    write_resp_phase_done <= 1'b0;
                    
                    // Debug output
                    if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                        write_debug_log("Write Resp Phase: State transition to ACTIVE");
                    end
                end
            end
            
            WRITE_RESP_ACTIVE: begin
                // Debug output for state transition
                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                    write_debug_log("Write Resp Phase: State transition to ACTIVE");
                end

                // Highest priority: Valid signal check
                if (axi_b_valid && axi_b_ready) begin
                    // Array range check
                    if (write_resp_array_index < write_resp_expected.size()) begin
                        // Get expected value
                        automatic write_resp_expected_t expected = write_resp_expected[write_resp_array_index];
                        
                        // Response verification
                        if (axi_b_resp !== expected.expected_resp) begin
                            $error("Write Response Mismatch: Expected %0d, Got %0d for ID %0d", 
                                   expected.expected_resp, axi_b_resp, axi_b_id);
                            $finish;
                        end
                        
                        // Debug output
                        if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                            write_debug_log($sformatf("Write Resp[%0d]: test_count=%0d, resp=%0d, id=%0d, valid=%0d", 
                                write_resp_array_index, expected.test_count, axi_b_resp, axi_b_id, axi_b_valid));
                        end

                        write_resp_array_index <= write_resp_array_index + 1;
                        write_resp_phase_counter <= write_resp_phase_counter + 8'd1;
                        write_debug_log($sformatf("Write Resp Phase: Response received, counter=%0d/%0d", 
                            write_resp_phase_counter + 1, PHASE_TEST_COUNT));
                    end else begin
                        // Phase complete
                        // State transition
                        write_resp_state <= WRITE_RESP_FINISH;
                        write_resp_phase_done <= 1'b1;
                        
                        write_debug_log("Write Resp Phase: Phase completed, all signals cleared");
                    end
                end
                // When axi_b_valid = 0 or axi_b_ready = 0, do nothing (keep current signals)
            end
            
            WRITE_RESP_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                write_resp_phase_done <= 1'b0;
                write_resp_phase_busy <= 1'b0;
                write_resp_state <= WRITE_RESP_IDLE;
                
                // Debug output
                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                    write_debug_log("Write Resp Phase: State transition to IDLE");
                end
            end
        endcase
    end
end

`endif // AXI_WRITE_CHANNEL_CONTROL_SVH
