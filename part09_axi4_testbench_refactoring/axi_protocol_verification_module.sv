// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// AXI4 Protocol Verification Module

`timescale 1ns/1ps

module axi_protocol_verification_module (
    // No ports - direct access to TOP hierarchy signals
);

// Include common definitions for parameters
`include "axi_common_defs.svh"

// 1-clock delayed signals for payload hold check
logic [AXI_ADDR_WIDTH-1:0] axi_aw_addr_delayed;
logic [1:0]                axi_aw_burst_delayed;
logic [2:0]                axi_aw_size_delayed;
logic [AXI_ID_WIDTH-1:0]   axi_aw_id_delayed;
logic [7:0]                axi_aw_len_delayed;
logic                      axi_aw_valid_delayed;
logic                      axi_aw_ready_delayed;

logic [AXI_DATA_WIDTH-1:0] axi_w_data_delayed;
logic [AXI_STRB_WIDTH-1:0] axi_w_strb_delayed;
logic                       axi_w_last_delayed;
logic                       axi_w_valid_delayed;
logic                       axi_w_ready_delayed;

logic [AXI_ADDR_WIDTH-1:0] axi_ar_addr_delayed;
logic [1:0]                axi_ar_burst_delayed;
logic [2:0]                axi_ar_size_delayed;
logic [AXI_ID_WIDTH-1:0]   axi_ar_id_delayed;
logic [7:0]                axi_ar_len_delayed;
logic                      axi_ar_valid_delayed;
logic                      axi_ar_ready_delayed;

logic [AXI_DATA_WIDTH-1:0] axi_r_data_delayed;
logic [AXI_ID_WIDTH-1:0]   axi_r_id_delayed;
logic [1:0]                axi_r_resp_delayed;
logic                       axi_r_last_delayed;
logic                       axi_r_valid_delayed;
logic                       axi_r_ready_delayed;

// 1-clock delay circuit
always_ff @(posedge `TOP_TB.clk) begin
    // Write Address Channel
    axi_aw_addr_delayed <= `TOP_TB.axi_aw_addr;
    axi_aw_burst_delayed <= `TOP_TB.axi_aw_burst;
    axi_aw_size_delayed <= `TOP_TB.axi_aw_size;
    axi_aw_id_delayed <= `TOP_TB.axi_aw_id;
    axi_aw_len_delayed <= `TOP_TB.axi_aw_len;
    axi_aw_valid_delayed <= `TOP_TB.axi_aw_valid;
    axi_aw_ready_delayed <= `TOP_TB.axi_aw_ready;
    
    // Write Data Channel
    axi_w_data_delayed <= `TOP_TB.axi_w_data;
    axi_w_strb_delayed <= `TOP_TB.axi_w_strb;
    axi_w_last_delayed <= `TOP_TB.axi_w_last;
    axi_w_valid_delayed <= `TOP_TB.axi_w_valid;
    axi_w_ready_delayed <= `TOP_TB.axi_w_ready;
    
    // Read Address Channel
    axi_ar_addr_delayed <= `TOP_TB.axi_ar_addr;
    axi_ar_burst_delayed <= `TOP_TB.axi_ar_burst;
    axi_ar_size_delayed <= `TOP_TB.axi_ar_size;
    axi_ar_id_delayed <= `TOP_TB.axi_ar_id;
    axi_ar_len_delayed <= `TOP_TB.axi_ar_len;
    axi_ar_valid_delayed <= `TOP_TB.axi_ar_valid;
    axi_ar_ready_delayed <= `TOP_TB.axi_ar_ready;
    
    // Read Data Channel
    axi_r_data_delayed <= `TOP_TB.axi_r_data;
    axi_r_id_delayed <= `TOP_TB.axi_r_id;
    axi_r_resp_delayed <= `TOP_TB.axi_r_resp;
    axi_r_last_delayed <= `TOP_TB.axi_r_last;
    axi_r_valid_delayed <= `TOP_TB.axi_r_valid;
    axi_r_ready_delayed <= `TOP_TB.axi_r_ready;
end

// Write Address Channel payload hold check (start monitoring after reset deassertion)
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        // Don't monitor during reset
    end else begin
        if (!axi_aw_ready_delayed) begin
            // Check if payload changed during Ready negated
            if (`TOP_TB.axi_aw_addr !== axi_aw_addr_delayed) begin
                $error("Write Address Channel: Address changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       `TOP_TB.axi_aw_addr, axi_aw_addr_delayed);
                $finish;
            end
            if (`TOP_TB.axi_aw_burst !== axi_aw_burst_delayed) begin
                $error("Write Address Channel: Burst changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_aw_burst, axi_aw_burst_delayed);
                $finish;
            end
            if (`TOP_TB.axi_aw_size !== axi_aw_size_delayed) begin
                $error("Write Address Channel: Size changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_aw_size, axi_aw_size_delayed);
                $finish;
            end
            if (`TOP_TB.axi_aw_id !== axi_aw_id_delayed) begin
                $error("Write Address Channel: ID changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_aw_id, axi_aw_id_delayed);
                $finish;
            end
            if (`TOP_TB.axi_aw_len !== axi_aw_len_delayed) begin
                $error("Write Address Channel: Length changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_aw_len, axi_aw_len_delayed);
                $finish;
            end
            if (`TOP_TB.axi_aw_valid !== axi_aw_valid_delayed) begin
                $error("Write Address Channel: Valid changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_aw_valid, axi_aw_valid_delayed);
                $finish;
            end
        end
    end
end

// Write Data Channel payload hold check
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        // Don't monitor during reset
    end else begin
        if (!axi_w_ready_delayed) begin
            if (`TOP_TB.axi_w_data !== axi_w_data_delayed) begin
                $error("Write Data Channel: Data changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       `TOP_TB.axi_w_data, axi_w_data_delayed);
                $finish;
            end
            if (`TOP_TB.axi_w_strb !== axi_w_strb_delayed) begin
                $error("Write Data Channel: Strobe changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       `TOP_TB.axi_w_strb, axi_w_strb_delayed);
                $finish;
            end
            if (`TOP_TB.axi_w_last !== axi_w_last_delayed) begin
                $error("Write Data Channel: Last changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_w_last, axi_w_last_delayed);
                $finish;
            end
            if (`TOP_TB.axi_w_valid !== axi_w_valid_delayed) begin
                $error("Write Data Channel: Valid changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_w_valid, axi_w_valid_delayed);
                $finish;
            end
        end
    end
end

// Read Address Channel payload hold check
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        // Don't monitor during reset
    end else begin
        if (!axi_ar_ready_delayed) begin
            if (`TOP_TB.axi_ar_addr !== axi_ar_addr_delayed) begin
                $error("Read Address Channel: Address changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       `TOP_TB.axi_ar_addr, axi_ar_addr_delayed);
                $finish;
            end
            if (`TOP_TB.axi_ar_burst !== axi_ar_burst_delayed) begin
                $error("Read Address Channel: Burst changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_ar_burst, axi_ar_burst_delayed);
                $finish;
            end
            if (`TOP_TB.axi_ar_size !== axi_ar_size_delayed) begin
                $error("Read Address Channel: Size changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_ar_size, axi_ar_size_delayed);
                $finish;
            end
            if (`TOP_TB.axi_ar_id !== axi_ar_id_delayed) begin
                $error("Read Address Channel: ID changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_ar_id, axi_ar_id_delayed);
                $finish;
            end
            if (`TOP_TB.axi_ar_len !== axi_ar_len_delayed) begin
                $error("Read Address Channel: Length changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_ar_len, axi_ar_len_delayed);
                $finish;
            end
            if (`TOP_TB.axi_ar_valid !== axi_ar_valid_delayed) begin
                $error("Read Address Channel: Valid changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_ar_valid, axi_ar_valid_delayed);
                $finish;
            end
        end
    end
end

// Read Data Channel payload hold check
always_ff @(posedge `TOP_TB.clk or negedge `TOP_TB.rst_n) begin
    if (!`TOP_TB.rst_n) begin
        // Don't monitor during reset
    end else begin
        if (!axi_r_ready_delayed) begin
            if (`TOP_TB.axi_r_data !== axi_r_data_delayed) begin
                $error("Read Data Channel: Data changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       `TOP_TB.axi_r_data, axi_r_data_delayed);
                $finish;
            end
            if (`TOP_TB.axi_r_id !== axi_r_id_delayed) begin
                $error("Read Data Channel: ID changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_r_id, axi_r_id_delayed);
                $finish;
            end
            if (`TOP_TB.axi_r_resp !== axi_r_resp_delayed) begin
                $error("Read Data Channel: Response changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_r_resp, axi_r_resp_delayed);
                $finish;
            end
            if (`TOP_TB.axi_r_last !== axi_r_last_delayed) begin
                $error("Read Data Channel: Last changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_r_last, axi_r_last_delayed);
                $finish;
            end
            if (`TOP_TB.axi_r_valid !== axi_r_valid_delayed) begin
                $error("Read Data Channel: Valid changed during Ready negated. Current: %0d, Delayed: %0d", 
                       `TOP_TB.axi_r_valid, axi_r_valid_delayed);
                $finish;
            end
        end
    end
end

endmodule
