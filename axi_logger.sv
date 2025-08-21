// AXI4 Logger Module
// I/O-less module for logging and monitoring AXI4 protocol signals
// Uses hierarchical signal names for signal observation

// Import common logging package
import axi_logger_pkg::*;

// Define TOP macro for hierarchical references
`define TOP axi_simple_dual_port_ram_tb

module axi_logger;
    // Extract parameters from TOP module and copy to local parameters
    // AXI4 configuration parameters
    localparam int AXI_ADDR_WIDTH = `TOP.AXI_ADDR_WIDTH;
    localparam int AXI_DATA_WIDTH = `TOP.AXI_DATA_WIDTH;
    localparam int AXI_ID_WIDTH = `TOP.AXI_ID_WIDTH;
    localparam int AXI_STRB_WIDTH = `TOP.AXI_STRB_WIDTH;
    
    // Logging control parameters
    localparam bit LOG_ENABLE = `TOP.LOG_ENABLE;
    localparam bit DEBUG_LOG_ENABLE = `TOP.DEBUG_LOG_ENABLE;
    
    // Test configuration parameters
    localparam int TOTAL_TEST_COUNT = `TOP.TOTAL_TEST_COUNT;
    localparam int PHASE_TEST_COUNT = `TOP.PHASE_TEST_COUNT;
    
    // Clock and reset parameters
    localparam time CLK_PERIOD = `TOP.CLK_PERIOD;
    localparam int RESET_CYCLES = `TOP.RESET_CYCLES;
    
    // Ready negate control parameters
    localparam int READY_NEGATE_ARRAY_LENGTH = `TOP.READY_NEGATE_ARRAY_LENGTH;
    
    // Clock and time tracking
    logic clk;                                 // Clock signal (hierarchical reference)
    time current_time;                         // Current simulation time
    
    // AXI4 Write Address Channel signals (hierarchical references)
    logic [AXI_ADDR_WIDTH-1:0] axi_aw_addr;   // Write address
    logic [1:0]                axi_aw_burst;  // Burst type
    logic [2:0]                axi_aw_size;   // Burst size
    logic [AXI_ID_WIDTH-1:0]   axi_aw_id;    // Write ID
    logic [7:0]                axi_aw_len;    // Burst length
    logic                      axi_aw_valid;  // Write address valid
    logic                      axi_aw_ready;  // Write address ready
    
    // AXI4 Write Data Channel signals (hierarchical references)
    logic [AXI_DATA_WIDTH-1:0] axi_w_data;   // Write data
    logic [AXI_STRB_WIDTH-1:0] axi_w_strb;   // Write strobe
    logic                       axi_w_last;   // Write last
    logic                       axi_w_valid;  // Write data valid
    logic                       axi_w_ready;  // Write data ready
    
    // AXI4 Write Response Channel signals (hierarchical references)
    logic [1:0]                axi_b_resp;   // Write response
    logic [AXI_ID_WIDTH-1:0]   axi_b_id;     // Write response ID
    logic                       axi_b_valid;  // Write response valid
    logic                       axi_b_ready;  // Write response ready
    
    // AXI4 Read Address Channel signals (hierarchical references)
    logic [AXI_ADDR_WIDTH-1:0] axi_ar_addr;  // Read address
    logic [1:0]                axi_ar_burst; // Burst type
    logic [2:0]                axi_ar_size;  // Burst size
    logic [AXI_ID_WIDTH-1:0]   axi_ar_id;    // Read ID
    logic [7:0]                axi_ar_len;   // Burst length
    logic                       axi_ar_valid; // Read address valid
    logic                       axi_ar_ready; // Read address ready
    
    // AXI4 Read Data Channel signals (hierarchical references)
    logic [AXI_DATA_WIDTH-1:0] axi_r_data;   // Read data
    logic [AXI_ID_WIDTH-1:0]   axi_r_id;     // Read ID
    logic [1:0]                axi_r_resp;   // Read response
    logic                       axi_r_last;   // Read last
    logic                       axi_r_valid;  // Read data valid
    logic                       axi_r_ready;  // Read data ready
    
    // Phase control signals (hierarchical references)
    logic [7:0]                current_phase;        // Current test phase
    logic                       write_addr_phase_start;  // Write address phase start
    logic                       read_addr_phase_start;   // Read address phase start
    logic                       write_data_phase_start;  // Write data phase start
    logic                       read_data_phase_start;   // Read data phase start
    logic                       write_resp_phase_start;  // Write response phase start
    
    // Test control signals (hierarchical references)
    logic                       generate_stimulus_expected_done;  // Stimulus generation complete
    logic                       test_execution_completed;        // Test execution complete
    
    // Hierarchical signal bindings
    // These assignments connect the module signals to the actual testbench signals
    // The hierarchical paths should be updated based on the actual testbench structure
    
    // Clock and time binding
    assign clk = `TOP.clk;
    assign current_time = $time;
    
    // Write Address Channel binding
    assign axi_aw_addr = `TOP.axi_aw_addr;
    assign axi_aw_burst = `TOP.axi_aw_burst;
    assign axi_aw_size = `TOP.axi_aw_size;
    assign axi_aw_id = `TOP.axi_aw_id;
    assign axi_aw_len = `TOP.axi_aw_len;
    assign axi_aw_valid = `TOP.axi_aw_valid;
    assign axi_aw_ready = `TOP.axi_aw_ready;
    
    // Write Data Channel binding
    assign axi_w_data = `TOP.axi_w_data;
    assign axi_w_strb = `TOP.axi_w_strb;
    assign axi_w_last = `TOP.axi_w_last;
    assign axi_w_valid = `TOP.axi_w_valid;
    assign axi_w_ready = `TOP.axi_w_ready;
    
    // Write Response Channel binding
    assign axi_b_resp = `TOP.axi_b_resp;
    assign axi_b_id = `TOP.axi_b_id;
    assign axi_b_valid = `TOP.axi_b_valid;
    assign axi_b_ready = `TOP.axi_b_ready;
    
    // Read Address Channel binding
    assign axi_ar_addr = `TOP.axi_ar_addr;
    assign axi_ar_burst = `TOP.axi_ar_burst;
    assign axi_ar_size = `TOP.axi_ar_size;
    assign axi_ar_id = `TOP.axi_ar_id;
    assign axi_ar_len = `TOP.axi_ar_len;
    assign axi_ar_valid = `TOP.axi_ar_valid;
    assign axi_ar_ready = `TOP.axi_ar_ready;
    
    // Read Data Channel binding
    assign axi_r_data = `TOP.axi_r_data;
    assign axi_r_id = `TOP.axi_r_id;
    assign axi_r_resp = `TOP.axi_r_resp;
    assign axi_r_last = `TOP.axi_r_last;
    assign axi_r_valid = `TOP.axi_r_valid;
    assign axi_r_ready = `TOP.axi_r_ready;
    
    // Phase control binding
    assign current_phase = `TOP.current_phase;
    assign write_addr_phase_start = `TOP.write_addr_phase_start;
    assign read_addr_phase_start = `TOP.read_addr_phase_start;
    assign write_data_phase_start = `TOP.write_data_phase_start;
    assign read_data_phase_start = `TOP.read_data_phase_start;
    assign write_resp_phase_start = `TOP.write_resp_phase_start;
    
    // Test control binding
    assign generate_stimulus_expected_done = `TOP.generate_stimulus_expected_done;
    assign test_execution_completed = `TOP.test_execution_completed;
    
    // Utility functions
    function automatic string size_to_string(input logic [2:0] size);
        return $sformatf("%0d(%0d bytes)", size, (1 << size));
    endfunction
    
    function automatic string get_burst_type_string(input logic [1:0] burst);
        case (burst)
            2'b00: return "FIXED";
            2'b01: return "INCR";
            2'b10: return "WRAP";
            default: return "INCR";
        endcase
    endfunction
    
        // Log output functions (imported from axi_logger_pkg)
    
    // Test start and completion summary logging
    initial begin
        // Phase 1: Display test configuration
        write_log("=== AXI4 Logger Configuration ===", LOG_ENABLE);
        write_log("Logger Configuration:", LOG_ENABLE);
        write_log($sformatf("  - Address Width: %0d bits", AXI_ADDR_WIDTH), LOG_ENABLE);
        write_log($sformatf("  - Data Width: %0d bits", AXI_DATA_WIDTH), LOG_ENABLE);
        write_log($sformatf("  - ID Width: %0d bits", AXI_ID_WIDTH), LOG_ENABLE);
        write_log($sformatf("  - Strobe Width: %0d bits", AXI_STRB_WIDTH), LOG_ENABLE);
        write_log("  - Logging Enabled: Yes", LOG_ENABLE);
        write_log($sformatf("  - Debug Logging: %s", DEBUG_LOG_ENABLE ? "Yes" : "No"), LOG_ENABLE);
    end
    
    // Phase execution logging
    always @(posedge clk) begin
        if (write_addr_phase_start) begin
            write_log($sformatf("Phase %0d: Write Address Channel started", current_phase), LOG_ENABLE);
        end
        if (read_addr_phase_start) begin
            write_log($sformatf("Phase %0d: Read Address Channel started", current_phase), LOG_ENABLE);
        end
        if (write_data_phase_start) begin
            write_log($sformatf("Phase %0d: Write Data Channel started", current_phase), LOG_ENABLE);
        end
        if (read_data_phase_start) begin
            write_log($sformatf("Phase %0d: Read Data Channel started", current_phase), LOG_ENABLE);
        end
        if (write_resp_phase_start) begin
            write_log($sformatf("Phase %0d: Write Response Channel started", current_phase), LOG_ENABLE);
        end
    end
    
    // AXI4 transfer logging (debug)
    always @(posedge clk) begin
        // Write Address Channel transfer
        if (axi_aw_valid && axi_aw_ready) begin
            write_debug_log($sformatf("Write Addr Transfer: addr=0x%h, burst=%s, size=%s, id=%0d, len=%0d", 
                axi_aw_addr, get_burst_type_string(axi_aw_burst), size_to_string(axi_aw_size), axi_aw_id, axi_aw_len), DEBUG_LOG_ENABLE);
        end
        
        // Write Data Channel transfer
        if (axi_w_valid && axi_w_ready) begin
            write_debug_log($sformatf("Write Data Transfer: data=0x%h, strb=0x%h, last=%0d", 
                axi_w_data, axi_w_strb, axi_w_last), DEBUG_LOG_ENABLE);
        end
        
        // Write Response Channel transfer
        if (axi_b_valid && axi_b_ready) begin
            write_debug_log($sformatf("Write Response Transfer: resp=%0d, id=%0d", 
                axi_b_resp, axi_b_id), DEBUG_LOG_ENABLE);
        end
        
        // Read Address Channel transfer
        if (axi_ar_valid && axi_ar_ready) begin
            write_debug_log($sformatf("Read Addr Transfer: addr=0x%h, burst=%s, size=%s, id=%0d, len=%0d", 
                axi_ar_addr, get_burst_type_string(axi_ar_burst), size_to_string(axi_ar_size), axi_ar_id, axi_ar_len), DEBUG_LOG_ENABLE);
        end
        
        // Read Data Channel transfer
        if (axi_r_valid && axi_r_ready) begin
            write_debug_log($sformatf("Read Data Transfer: data=0x%h, resp=%0d, last=%0d", 
                axi_r_data, axi_r_resp, axi_r_last), DEBUG_LOG_ENABLE);
        end
    end
    
    // Stall cycle logging (debug)
    always @(posedge clk) begin
        // Write Address Channel stall
        if (axi_aw_valid && !axi_aw_ready) begin
            write_debug_log("Write Addr Channel: Stall detected", DEBUG_LOG_ENABLE);
        end
        
        // Write Data Channel stall
        if (axi_w_valid && !axi_w_ready) begin
            write_debug_log("Write Data Channel: Stall detected", DEBUG_LOG_ENABLE);
        end
        
        // Read Address Channel stall
        if (axi_ar_valid && !axi_ar_ready) begin
            write_debug_log("Read Addr Channel: Stall detected", DEBUG_LOG_ENABLE);
        end
        
        // Read Data Channel stall
        if (axi_r_valid && !axi_r_ready) begin
            write_debug_log("Read Data Channel: Stall detected", DEBUG_LOG_ENABLE);
        end
    end
    
    // Test completion monitoring
    always @(posedge clk) begin
        if (generate_stimulus_expected_done) begin
            write_log("=== Stimulus Generation Completed ===", LOG_ENABLE);
        end
        
        if (test_execution_completed) begin
            write_log("=== Test Execution Completed ===", LOG_ENABLE);
            write_log("  - Test Status: COMPLETED SUCCESSFULLY", LOG_ENABLE);
            write_log("=== AXI4 Logger End ===", LOG_ENABLE);
        end
    end

endmodule
