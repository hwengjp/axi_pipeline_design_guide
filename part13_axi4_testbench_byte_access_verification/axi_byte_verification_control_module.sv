// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// AXI4 Byte Verification Control Module

`timescale 1ns/1ps

module axi_byte_verification_control_module (
    // No ports - direct access to TOP hierarchy signals
);

// Include common definitions for parameters
`include "axi_common_defs.svh"

// Byte Verification phase completion signal latches
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        `TOP_TB.byte_verification_phase_done_latched <= 1'b0;
    end else if (`TOP_TB.clear_phase_latches) begin
        // Clear byte verification latched signal when clear signal is asserted
        `TOP_TB.byte_verification_phase_done_latched <= 1'b0;
    end else begin
        if (`TOP_TB.byte_verification_phase_done) `TOP_TB.byte_verification_phase_done_latched <= 1'b1;
    end
end

// Byte Verification Control Circuit
// Use local variables for state management
byte_verification_state_t byte_verification_state = BYTE_VERIFICATION_IDLE;
logic [7:0] byte_verification_phase_counter = 8'd0;
logic byte_verification_phase_busy = 1'b0;
int byte_verification_array_index = 0;

// Byte Verification Control
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        byte_verification_state <= BYTE_VERIFICATION_IDLE;
        byte_verification_phase_counter <= 8'd0;
        byte_verification_phase_busy <= 1'b0;
        `TOP_TB.byte_verification_phase_done <= 1'b0;
        byte_verification_array_index <= 0;
    end else begin
        case (byte_verification_state)
            2'b00: begin  // IDLE
                if (`TOP_TB.byte_verification_phase_start) begin
                    byte_verification_state <= BYTE_VERIFICATION_ACTIVE;
                    byte_verification_phase_busy <= 1'b1;
                    byte_verification_phase_counter <= 8'd0;
                    byte_verification_array_index <= 0;
                    `TOP_TB.byte_verification_phase_done <= 1'b0;
                end
            end
            
            2'b01: begin  // ACTIVE
                // Check if we have more byte verification entries to process
                if (byte_verification_array_index < `TOP_TB.byte_verification_read_addr_payloads.size()) begin
                    // Process current byte verification entry
                    if (`TOP_TB.byte_verification_read_addr_payloads[byte_verification_array_index].valid) begin
                        // Simulate byte verification (in real implementation, this would perform actual memory reads)
                        automatic logic [AXI_ADDR_WIDTH-1:0] addr = `TOP_TB.byte_verification_read_addr_payloads[byte_verification_array_index].addr;
                        automatic logic [7:0] expected_byte = `TOP_TB.byte_verification_expected[byte_verification_array_index].expected_byte;
                        
                        // Log verification attempt
                        $display("Byte verification %0d: addr=0x%x, expected=0x%02x", 
                                byte_verification_array_index, addr, expected_byte);
                        
                        // Move to next entry
                        byte_verification_array_index <= byte_verification_array_index + 1;
                        byte_verification_phase_counter <= byte_verification_phase_counter + 1;
                    end else begin
                        // Skip invalid entries
                        byte_verification_array_index <= byte_verification_array_index + 1;
                    end
                end else begin
                    // All entries processed, mark phase as complete
                    byte_verification_state <= BYTE_VERIFICATION_FINISH;
                    `TOP_TB.byte_verification_phase_done <= 1'b1;
                    byte_verification_phase_busy <= 1'b0;
                end
            end
            
            2'b10: begin  // FINISH
                // Phase is complete, stay in this state until reset
                `TOP_TB.byte_verification_phase_done <= 1'b1;
            end
            
            default: begin
                byte_verification_state <= BYTE_VERIFICATION_IDLE;
                byte_verification_phase_counter <= 8'd0;
                byte_verification_phase_busy <= 1'b0;
                `TOP_TB.byte_verification_phase_done <= 1'b0;
                byte_verification_array_index <= 0;
            end
        endcase
    end
end

endmodule
