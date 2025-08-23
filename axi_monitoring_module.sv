// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// axi_monitoring_module.sv
// AXI4 Monitoring and Logging Module
// Auto-generated from axi_simple_dual_port_ram_tb_refactored.sv

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

endmodule
