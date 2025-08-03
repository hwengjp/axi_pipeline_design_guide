// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.
`timescale 1ns / 1ps
module pipeline_tb #(
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
    integer                 bubble_cycles;
    integer                 stall_cycles;
    
    // Test pattern arrays
    reg  [DATA_WIDTH-1:0]  test_data_array [0:TEST_DATA_COUNT*4-1];
    reg                     test_valid_array [0:TEST_DATA_COUNT*4-1];
    reg  [DATA_WIDTH-1:0]  expected_data_array [0:TEST_DATA_COUNT*4-1];
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
    integer                 expected_data_index;
    
    // Final output signals
    wire [DATA_WIDTH-1:0]  final_data;
    wire                    final_valid;
    reg                    final_ready;
    
    // Sequence checker signals
    reg  [DATA_WIDTH-1:0]  prev_test_data;
    reg                     prev_test_valid;
    reg  [DATA_WIDTH-1:0]  prev_result_data;
    reg                     prev_result_valid;
    
    // Test control
    integer                 test_count;
    
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
    
    // Reset generation
    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
    end
    
    // Test data initialization
    initial begin
        // Variable declarations
        integer expected_index;
        integer i, j;
        
        // Initialize test pattern arrays
        array_size = 0;
        expected_index = 0;
        
        // Generate test pattern arrays
        for (i = 0; i < TEST_DATA_COUNT; i = i + 1) begin
            // Add valid data
            test_data_array[array_size] = i;
            test_valid_array[array_size] = 1;
            expected_data_array[expected_index] = i;
            array_size = array_size + 1;
            expected_index = expected_index + 1;
            
            // Generate bubble cycles
            bubble_cycles = $random % (BUBBLE_N + 4) - BUBBLE_N;
            if (bubble_cycles < 0) bubble_cycles = 0;
            
            // Add bubbles (only to test arrays, not to expected array)
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_data_array[array_size] = {DATA_WIDTH{1'bx}};
                test_valid_array[array_size] = 0;
                array_size = array_size + 1;
            end
        end
    end
    
    // Test pattern generator (always block)
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state - hold current data
            test_data <= {DATA_WIDTH{1'bx}};
            test_valid <= 0;
            array_index <= 0;
        end else begin
            if (array_index < array_size) begin
                if (test_ready) begin
                    // Ready is high, send next data
                    test_data <= test_data_array[array_index];
                    test_valid <= test_valid_array[array_index];
                    array_index <= array_index + 1;
                end
                // If Ready is low, hold current data (no change)
            end else begin
                // All data sent, stop sending
                test_valid <= 0;
            end
        end
    end
    
    // Downstream Ready control circuit
    reg [2:0] stall_counter;
    reg stall_active;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state
            final_ready <= 0;
            stall_counter <= 0;
            stall_active <= 0;
        end else begin
            if (stall_counter == 0 && !stall_active) begin
                // Generate new stall cycles
                stall_cycles = $random % (STALL_N + 4) - STALL_N;
                if (stall_cycles < 0) stall_cycles = 0;
                
                if (stall_cycles > 0) begin
                    final_ready <= 0;
                    stall_counter <= stall_cycles;
                    stall_active <= 1;
                end else begin
                    final_ready <= 1;
                end
            end else if (stall_active) begin
                // Stall is active, count down
                if (stall_counter > 1) begin
                    stall_counter <= stall_counter - 1;
                end else begin
                    // Stall complete
                    final_ready <= 1;
                    stall_counter <= 0;
                    stall_active <= 0;
                end
            end
        end
    end
    
    // Test result checker circuit
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state
            test_count <= 0;
            expected_data_index <= 0;
        end else begin
            // Check if test count reached maximum
            if (test_count >= TEST_DATA_COUNT) begin
                $display("Test completed:");
                $display("  Total tests: %0d", test_count);
                $display("PASS: All tests passed");
                // Stop after 1 clock cycle on success
                repeat (1) @(posedge clk);
                $finish;
            end
            
            // Check final output data
            if (final_valid && final_ready) begin
                test_count <= test_count + 1;
                
                // Check if data matches expected value from array
                if (final_data !== expected_data_array[expected_data_index]) begin
                    $display("ERROR: Data mismatch at test %0d", test_count);
                    $display("  Time: %0t", $time);
                    $display("  Signal: final_data");
                    $display("  Expected: %0d, Got: %0d", expected_data_array[expected_data_index], final_data);
                    
                    // Stop after 1 clock cycle on error
                    repeat (1) @(posedge clk);
                    $finish;
                end else begin
                    $display("PASS: Test %0d, Data: %0d", test_count, final_data);
                end
                
                expected_data_index <= expected_data_index + 1;
            end
        end
    end
    
    // Sequence checker circuit - Input side
    reg prev_test_ready;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prev_test_data <= {DATA_WIDTH{1'bx}};
            prev_test_valid <= 0;
            prev_test_ready <= 0;
        end else begin
            // Check if data is held when ready is low
            if (!prev_test_ready && test_valid) begin
                // Check if data value is same as previous cycle
                if (test_data !== prev_test_data || test_valid != prev_test_valid) begin
                    $display("ERROR: Input data not held during stall");
                    $display("  Time: %0t", $time);
                    $display("  Signal: test_data");
                    $display("  Should be held: %0d", prev_test_data);
                    $display("  Actual value: %0d", test_data);
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            // Check for undefined values during valid periods
            if (test_valid && test_ready) begin
                if (test_data === {DATA_WIDTH{1'bx}}) begin
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
    
    // Sequence checker circuit - Output side
    reg prev_final_ready;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prev_result_data <= 0;
            prev_result_valid <= 0;
            prev_final_ready <= 0;
        end else begin
            // Check if data is held when ready is low
            if (!prev_final_ready && final_valid) begin
                // Check if data value is same as previous cycle
                if (final_data !== prev_result_data || final_valid != prev_result_valid) begin
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
