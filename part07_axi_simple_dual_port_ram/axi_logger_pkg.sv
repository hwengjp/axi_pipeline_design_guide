// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
// AXI4 Logger Package
// Common logging functions for AXI4 testbenches
package axi_logger_pkg;

    // Simple logging function for regular messages (controlled by LOG_ENABLE parameter)
    function automatic void write_log(input string message, input bit log_enable);
        if (log_enable) begin
            $display("[%0t] %s", $time, message);
        end
    endfunction

    // Simple logging function for debug messages (controlled by DEBUG_LOG_ENABLE parameter)
    function automatic void write_debug_log(input string message, input bit debug_log_enable);
        if (debug_log_enable) begin
            $display("[%0t] [DEBUG] %s", $time, message);
        end
    endfunction

    // Utility functions for string conversion
    function automatic string size_to_string(input logic [2:0] size);
        case (size)
            3'b000: return "1B";
            3'b001: return "2B";
            3'b010: return "4B";
            3'b011: return "8B";
            3'b100: return "16B";
            3'b101: return "32B";
            3'b110: return "64B";
            3'b111: return "128B";
            default: return "UNK";
        endcase
    endfunction

    function automatic string get_burst_type_string(input logic [1:0] burst);
        case (burst)
            2'b00: return "FIXED";
            2'b01: return "INCR";
            2'b10: return "WRAP";
            default: return "INCR";
        endcase
    endfunction

endpackage
