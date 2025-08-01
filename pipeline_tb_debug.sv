// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

module pipeline_tb_debug #(
    parameter DATA_WIDTH = 32,
    parameter PIPELINE_STAGES = 4,
    parameter TEST_DATA_COUNT = 100,
    parameter BUBBLE_N = 2,
    parameter STALL_N = 2
)();

    // Clock and Reset
    reg                     clk;
    reg                     rst_n;
    
    // Test pattern generator signals
    reg  [DATA_WIDTH-1:0]  test_data;
    reg                     test_valid;
    wire                    test_ready;
    integer                 test_data_count;
    integer                 bubble_cycles;
    integer                 stall_cycles;
    
    // Test pattern arrays (SystemVerilog style)
    reg  [DATA_WIDTH-1:0]  test_data_array [0:TEST_DATA_COUNT*4-1]; // Maximum size for data + bubbles
    reg                     test_valid_array [0:TEST_DATA_COUNT*4-1];
    integer                 array_index;
    integer                 array_size;
    
    // DUT signals
    wire [DATA_WIDTH-1:0]  dut_data;
    wire                    dut_valid;
    wire                    dut_ready;
    
    // Result checker signals
    wire [DATA_WIDTH-1:0]  result_data;
    wire                    result_valid;
    wire                    result_ready;
    integer                 expected_data;
    integer                 error_count;
    
    // Final output signals
    wire [DATA_WIDTH-1:0]  final_data;
    wire                    final_valid;
    wire                    final_ready;
    
    // Test control
    integer                 test_count;
    integer                 total_error_count;
    
    // Debug signals for timing analysis
    reg  [DATA_WIDTH-1:0]  debug_test_data_history [0:9]; // Last 10 cycles
    reg                     debug_test_valid_history [0:9];
    reg                     debug_test_ready_history [0:9];
    reg                     debug_prev_test_ready_history [0:9];
    integer                 debug_history_index;
    integer                 debug_cycle_count;
    
    // Sequence checker signals (moved up for debug history)
    reg  [DATA_WIDTH-1:0]  prev_test_data;
    reg                     prev_test_valid;
    reg                     prev_test_ready;
    reg  [DATA_WIDTH-1:0]  prev_result_data;
    reg                     prev_result_valid;
    reg                     prev_final_ready;
    integer                 sequence_error_count;
    
    // DUT instance: pipeline_insert -> pipeline -> pipeline_insert
    pipeline_insert #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut_insert1 (
        .clk(clk),
        .rst_n(rst_n),
        .u_data(test_data),
        .u_valid(test_valid),
        .u_ready(test_ready),
        .d_data(dut_data),
        .d_valid(dut_valid),
        .d_ready(dut_ready)
    );
    
    pipeline #(
        .DATA_WIDTH(DATA_WIDTH),
        .PIPELINE_STAGES(PIPELINE_STAGES)
    ) dut_pipeline (
        .clk(clk),
        .rst_n(rst_n),
        .u_data(dut_data),
        .u_valid(dut_valid),
        .u_ready(dut_ready),
        .d_data(result_data),
        .d_valid(result_valid),
        .d_ready(result_ready)
    );
    
    pipeline_insert #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut_insert2 (
        .clk(clk),
        .rst_n(rst_n),
        .u_data(result_data),
        .u_valid(result_valid),
        .u_ready(result_ready),
        .d_data(final_data),
        .d_valid(final_valid),
        .d_ready(final_ready)
    );
    
    // Clock generation (10ns cycle, 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Debug history tracking
    always @(posedge clk) begin
        debug_cycle_count <= debug_cycle_count + 1;
        
        // Update history
        debug_test_data_history[debug_history_index] <= test_data;
        debug_test_valid_history[debug_history_index] <= test_valid;
        debug_test_ready_history[debug_history_index] <= test_ready;
        debug_prev_test_ready_history[debug_history_index] <= prev_test_ready;
        
        // Circular buffer
        if (debug_history_index == 9) begin
            debug_history_index <= 0;
        end else begin
            debug_history_index <= debug_history_index + 1;
        end
    end
    
    // Test pattern generator
    initial begin
        // Initialize
        test_data = {DATA_WIDTH{1'bx}};
        test_valid = 0;
        test_data_count = 0;
        bubble_cycles = 0;
        stall_cycles = 0;
        expected_data = 0;
        error_count = 0;
        sequence_error_count = 0;
        total_error_count = 0;
        test_count = 0;
        array_index = 0;
        array_size = 0;
        debug_cycle_count = 0;
        debug_history_index = 0;
        
        // Initialize debug history
        for (integer i = 0; i < 10; i = i + 1) begin
            debug_test_data_history[i] = 0;
            debug_test_valid_history[i] = 0;
            debug_test_ready_history[i] = 0;
            debug_prev_test_ready_history[i] = 0;
        end
        
        // Generate test pattern arrays
        for (integer i = 0; i < TEST_DATA_COUNT; i = i + 1) begin
            // Add valid data
            test_data_array[array_size] = i;
            test_valid_array[array_size] = 1;
            array_size = array_size + 1;
            
            // Generate bubble cycles
            bubble_cycles = $random % (BUBBLE_N + 4) - BUBBLE_N;
            if (bubble_cycles < 0) bubble_cycles = 0;
            
            // Add bubbles
            for (integer j = 0; j < bubble_cycles; j = j + 1) begin
                test_data_array[array_size] = {DATA_WIDTH{1'bx}}; // Undefined data
                test_valid_array[array_size] = 0; // Invalid
                array_size = array_size + 1;
            end
        end
        
        // Reset (5 cycles)
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Stream data according to Ready signal
        while (array_index < array_size) begin
            @(posedge clk);
            
            if (test_ready) begin
                // Ready is high, send next data
                test_data = test_data_array[array_index];
                test_valid = test_valid_array[array_index];
                array_index = array_index + 1;
            end
            // If Ready is low, hold current data (no change)
        end
        
        // Stop sending data
        test_valid = 0;
        
        // Wait for pipeline to flush
        repeat (PIPELINE_STAGES * 3 + 10) @(posedge clk);
        
        // Report results
        $display("Test completed:");
        $display("  Total tests: %0d", test_count);
        $display("  Data errors: %0d", error_count);
        $display("  Sequence errors: %0d", sequence_error_count);
        $display("  Total errors: %0d", total_error_count);
        
        if (total_error_count == 0) begin
            $display("PASS: All tests passed");
        end else begin
            $display("FAIL: %0d errors found", total_error_count);
        end
        
        $finish;
    end
    
    // Downstream Ready control circuit (2.3) - Most downstream ready control
    reg final_ready_reg;
    assign final_ready = final_ready_reg;
    
    initial begin
        final_ready_reg = 0; // Start with 0
        
        // Wait for reset to complete (5 cycles after reset release)
        @(posedge clk);
        repeat (5) @(posedge clk);
        final_ready_reg = 1; // Enable after 5 cycles
        
        forever begin
            @(posedge clk);
            
            // Generate stall cycles for final_ready (most downstream)
            stall_cycles = $random % (STALL_N + 4) - STALL_N;
            if (stall_cycles < 0) stall_cycles = 0;
            
            if (stall_cycles > 0) begin
                final_ready_reg = 0;
                repeat (stall_cycles) @(posedge clk);
                final_ready_reg = 1;
            end
        end
    end
    
    // Test result checker circuit (2.4) - Check most downstream data
    always @(posedge clk) begin
        // Check final output data (most downstream) - Ready=H and Valid=H
        if (final_valid && final_ready) begin
            test_count = test_count + 1;
            
            // Check if upstream data matches downstream data
            if (final_data !== expected_data) begin
                error_count = error_count + 1;
                total_error_count = total_error_count + 1;
                $display("ERROR: Data mismatch at test %0d", test_count);
                $display("  Time: %0t", $time);
                $display("  Signal: final_data");
                $display("  Expected: %0d, Got: %0d", expected_data, final_data);
                
                // Stop after 1 clock cycle on error
                repeat (1) @(posedge clk);
                $finish;
            end else begin
                $display("PASS: Test %0d, Data: %0d", test_count, final_data);
            end
            
            expected_data = expected_data + 1;
        end
    end
    
    // Sequence checker circuit (2.5) - Input side (upstream pipeline_insert input)
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prev_test_data <= 0;
            prev_test_valid <= 0;
            prev_test_ready <= 0;
        end else begin
            // Check if data is held when ready is low
            if (!prev_test_ready && test_valid) begin
                // Check if next cycle value is same as current cycle value
                if (test_data !== prev_test_data || test_valid != prev_test_valid) begin
                    sequence_error_count = sequence_error_count + 1;
                    total_error_count = total_error_count + 1;
                    $display("ERROR: Input data not held during stall");
                    $display("  Time: %0t", $time);
                    $display("  Signal: test_data");
                    $display("  Should be held: %0d", prev_test_data);
                    $display("  Actual value: %0d", test_data);
                    $display("  Debug Info:");
                    $display("    Cycle: %0d", debug_cycle_count);
                    $display("    prev_test_ready: %0d", prev_test_ready);
                    $display("    test_valid: %0d", test_valid);
                    $display("    prev_test_valid: %0d", prev_test_valid);
                    $display("    test_ready: %0d", test_ready);
                    $display("  Signal History (last 10 cycles):");
                    for (integer i = 0; i < 10; i = i + 1) begin
                        $display("    Cycle-%0d: data=%0d, valid=%0d, ready=%0d, prev_ready=%0d", 
                                10-i, debug_test_data_history[i], debug_test_valid_history[i], 
                                debug_test_ready_history[i], debug_prev_test_ready_history[i]);
                    end
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            // Check for undefined values during valid periods
            if (test_valid && test_ready) begin
                if (test_data === {DATA_WIDTH{1'bx}}) begin
                    sequence_error_count = sequence_error_count + 1;
                    total_error_count = total_error_count + 1;
                    $display("ERROR: Undefined value detected in input data");
                    $display("  Time: %0t", $time);
                    $display("  Signal: test_data");
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            prev_test_data <= test_data;
            prev_test_valid <= test_valid;
            prev_test_ready <= test_ready;
        end
    end
    
    // Sequence checker circuit (2.5) - Output side (downstream pipeline_insert output)
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prev_result_data <= 0;
            prev_result_valid <= 0;
            prev_final_ready <= 0;
        end else begin
            // Check if data is held when ready is low
            if (!prev_final_ready && final_valid) begin
                // Check if next cycle value is same as current cycle value
                if (final_data !== prev_result_data || final_valid != prev_result_valid) begin
                    sequence_error_count = sequence_error_count + 1;
                    total_error_count = total_error_count + 1;
                    $display("ERROR: Output data not held during stall");
                    $display("  Time: %0t", $time);
                    $display("  Signal: final_data");
                    $display("  Should be held: %0d", prev_result_data);
                    $display("  Actual value: %0d", final_data);
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            // Check for undefined values during valid periods
            if (final_valid && final_ready) begin
                if (final_data === {DATA_WIDTH{1'bx}}) begin
                    sequence_error_count = sequence_error_count + 1;
                    total_error_count = total_error_count + 1;
                    $display("ERROR: Undefined value detected in output data");
                    $display("  Time: %0t", $time);
                    $display("  Signal: final_data");
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            prev_result_data <= final_data;
            prev_result_valid <= final_valid;
            prev_final_ready <= final_ready;
        end
    end

endmodule 