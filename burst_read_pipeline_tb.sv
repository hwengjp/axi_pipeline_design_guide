// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.
`timescale 1ns / 1ps
module burst_read_pipeline_tb #(
    parameter DATA_WIDTH = 32,        // Data width in bits
    parameter ADDR_WIDTH = 32,        // Address width in bits
    parameter MAX_BURST_LENGTH = 3,   // Maximum burst length for testing
    parameter TEST_COUNT = 1000,      // Number of test
    parameter BUBBLE_N = 2,           // Base number of bubble cycles
    parameter STALL_N = 2             // Base number of stall cycles
)();

    // Clock and Reset
    reg                     clk;
    reg                     rst_n;
    
    // Test pattern generator signals
    reg  [ADDR_WIDTH-1:0]  test_addr;
    reg  [7:0]             test_length;
    reg                     test_valid;
    wire                    test_ready;
    integer                 bubble_cycles;
    integer                 stall_cycles;
    
    // Test pattern arrays (queue arrays)
    reg  [ADDR_WIDTH-1:0]  test_addr_array [$];
    reg  [7:0]             test_length_array [$];
    reg                     test_valid_array [$];
    reg  [DATA_WIDTH-1:0]  expected_data_array [$];
    reg  [2:0]             stall_cycles_array [$];
    integer                 array_index;
    integer                 array_size;
    integer                 expected_data_index;
    integer                 stall_index;
    
    // DUT signals (upstream and downstream only)
    wire [DATA_WIDTH-1:0]  dut_data;
    wire                    dut_valid;
    wire                    dut_last;
    wire                    dut_ready;
    
    // Final output signals
    reg                     final_ready;
    
    // Sequence checker signals
    reg  [ADDR_WIDTH-1:0]  prev_test_addr;
    reg  [7:0]             prev_test_length;
    reg                     prev_test_valid;
    reg  [DATA_WIDTH-1:0]  prev_result_data;
    reg                     prev_result_valid;
    
    // Test control
    integer                 test_count;
    integer                 burst_count;
    integer                 data_count;
    integer                 valid_address_count;  // Valid address count (excluding bubbles)
    integer                 bubble_count;         // Bubble count
    
    // Burst tracking for reporting
    reg [ADDR_WIDTH-1:0]   current_burst_addr;   // Current burst start address
    reg [7:0]              current_burst_length;  // Current burst length
    integer                 burst_data_count;      // Data count within burst
    
    // DUT instance
    burst_read_pipeline #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MAX_BURST_LENGTH(MAX_BURST_LENGTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .u_addr(test_addr),
        .u_length(test_length),
        .u_valid(test_valid),
        .u_ready(test_ready),
        .d_data(dut_data),
        .d_valid(dut_valid),
        .d_last(dut_last),
        .d_ready(dut_ready)
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
        integer i, j;
        integer burst_length;
        integer stall_cycles;
        
        // Initialize test pattern arrays
        array_size = 0;
        expected_data_index = 0;
        stall_index = 0;
        valid_address_count = 0;  // 有効なアドレス数（バブルを含まない）
        bubble_count = 0;         // バブル数
        burst_data_count = 0;     // バースト内データカウント
        
        // Generate test pattern arrays
        for (i = 0; i < TEST_COUNT; i = i + 1) begin
            // Generate random burst length (1 to MAX_BURST_LENGTH)
            burst_length = $urandom_range(1, MAX_BURST_LENGTH);
            
            // Add valid burst request
            test_addr_array.push_back(i * 16);  // Start address
            test_length_array.push_back(burst_length - 1);  // Length - 1
            test_valid_array.push_back(1);
            array_size = array_size + 1;
            valid_address_count = valid_address_count + 1;
            
            // Generate expected data for this burst
            for (j = 0; j < burst_length; j = j + 1) begin
                expected_data_array.push_back((i * 16) + j);
                expected_data_index = expected_data_index + 1;
            end
            
            // Generate bubble cycles
            bubble_cycles = $random % (BUBBLE_N + 4) - BUBBLE_N;
            if (bubble_cycles < 0) bubble_cycles = 0;
            
            // Add bubbles
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_addr_array.push_back({ADDR_WIDTH{1'bx}});
                test_length_array.push_back(8'hxx);
                test_valid_array.push_back(0);
                array_size = array_size + 1;
                bubble_count = bubble_count + 1;
            end
            
            // Generate stall cycles (except for last burst)
            if (i < TEST_COUNT - 1) begin
                stall_cycles = $random % (STALL_N + 4) - STALL_N;
                if (stall_cycles < 0) stall_cycles = 0;
                stall_cycles_array.push_back(stall_cycles);
            end
        end
        
        // Generate additional stall cycles for bubble cycles
        for (i = 0; i < array_size - TEST_COUNT; i = i + 1) begin
            stall_cycles = $random % (STALL_N + 4) - STALL_N;
            if (stall_cycles < 0) stall_cycles = 0;
            stall_cycles_array.push_back(stall_cycles);
        end
        

    end
    
    // Test pattern generator (always block)
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state - hold current data
            test_addr <= {ADDR_WIDTH{1'bx}};
            test_length <= 8'hxx;
            test_valid <= 0;
            array_index <= 0;
        end else begin
            if (array_index < array_size) begin
                if (test_ready) begin
                    // Ready is high, send next data
                    test_addr <= test_addr_array[array_index];
                    test_length <= test_length_array[array_index];
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
    reg [2:0] current_stall_cycles;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state
            final_ready <= 0;
            stall_counter <= 0;
            stall_active <= 0;
            current_stall_cycles <= 0;
            stall_index <= 0;
        end else begin
            if (stall_counter == 0 && !stall_active) begin
                // Read stall cycles from array
                if (stall_index < stall_cycles_array.size()) begin
                    current_stall_cycles <= stall_cycles_array[stall_index];
                    stall_index <= stall_index + 1;
                end else begin
                    current_stall_cycles <= 0;
                end
                
                if (current_stall_cycles > 0) begin
                    final_ready <= 0;
                    stall_counter <= current_stall_cycles;
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
    
    // Connect final ready to dut ready
    assign dut_ready = final_ready;
    
    // Burst tracking circuit - record burst start information
    reg [ADDR_WIDTH-1:0]   burst_addr_queue [$];  // Burst address queue
    reg [7:0]              burst_length_queue [$]; // Burst length queue
    integer                 burst_queue_index;     // Queue index
    
    always @(posedge clk) begin
        if (!rst_n) begin
            current_burst_addr <= {ADDR_WIDTH{1'b0}};
            current_burst_length <= 8'h00;
            burst_queue_index <= 0;
        end else begin
            // Record burst start when valid burst request is sent
            if (test_valid && test_ready && test_valid_array[array_index - 1]) begin
                burst_addr_queue.push_back(test_addr_array[array_index - 1]);
                burst_length_queue.push_back(test_length_array[array_index - 1]);
                $display("Time %0t: Burst queued - addr: 0x%0h, length: %0d, queue_size: %0d", 
                         $time, test_addr_array[array_index - 1], test_length_array[array_index - 1], burst_addr_queue.size());
            end
            

        end
    end
    
    // Test result checker circuit
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state
            test_count <= 0;
            burst_count <= 0;
            data_count <= 0;
            burst_data_count <= 0;
        end else begin
            // Check if test count reached maximum
            if (data_count >= expected_data_index) begin
                $display("Test completed:");
                $display("  Total address patterns: %0d (including bubbles)", array_size);
                $display("  Valid address patterns: %0d (excluding bubbles)", valid_address_count);
                $display("  Bubble patterns: %0d", bubble_count);
                $display("  Total data: %0d", test_count);
                $display("  Max burst length: %0d", MAX_BURST_LENGTH);
                $display("  Bubble cycles (BUBBLE_N): %0d", BUBBLE_N);
                $display("  Stall cycles (STALL_N): %0d", STALL_N);
                $display("  Total stall cycles generated: %0d", stall_cycles_array.size());
                $display("PASS: All tests passed");
                // Stop after 1 clock cycle on success
                repeat (1) @(posedge clk);
                $finish;
            end
            
            // Check final output data
            if (dut_valid && dut_ready) begin
                test_count <= test_count + 1;
                burst_data_count <= burst_data_count + 1;
                
                // Check if data matches expected value from array
                if (dut_data !== expected_data_array[data_count]) begin
                    $display("ERROR: Data mismatch at test %0d", test_count);
                    $display("  Time: %0t", $time);
                    $display("  Signal: dut_data");
                    $display("  Expected: %0d, Got: %0d", expected_data_array[data_count], dut_data);
                    $display("  Burst: %0d, Data in burst: %0d", burst_count, test_count);
                    
                    // Stop after 1 clock cycle on error
                    repeat (1) @(posedge clk);
                    $finish;
                end
                
                data_count <= data_count + 1;
                
                // Count bursts and report burst information
                if (dut_last) begin
                    burst_count <= burst_count + 1;
                    if (burst_queue_index < burst_addr_queue.size()) begin
                        $display("Time %0t: Burst %0d completed - Start addr: 0x%0h, Length: %0d, Data count: %0d", 
                                 $time, burst_count, burst_addr_queue[burst_queue_index], burst_length_queue[burst_queue_index], burst_data_count + 1);
                        
                        // Check if data count matches expected length
                        if (burst_data_count + 1 !== burst_length_queue[burst_queue_index] + 1) begin
                            $display("ERROR: Data count mismatch at burst %0d", burst_count);
                            $display("  Time: %0t", $time);
                            $display("  Expected data count: %0d (Length: %0d + 1)", 
                                     burst_length_queue[burst_queue_index] + 1, burst_length_queue[burst_queue_index]);
                            $display("  Actual data count: %0d", burst_data_count + 1);
                            $display("  Start addr: 0x%0h", burst_addr_queue[burst_queue_index]);
                            repeat (1) @(posedge clk);
                            $finish;
                        end
                        
                        burst_queue_index <= burst_queue_index + 1;
                    end else begin
                        $display("Time %0t: Burst %0d completed - Queue empty, Data count: %0d", 
                                 $time, burst_count, burst_data_count + 1);
                    end
                    $display("  Debug: array_index=%0d, test_valid=%0d, test_ready=%0d, queue_index=%0d, queue_size=%0d", 
                             array_index, test_valid, test_ready, burst_queue_index, burst_addr_queue.size());
                    burst_data_count <= 0;
                end
            end
        end
    end
    
    // Sequence checker circuit - Input side
    reg prev_test_ready;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prev_test_addr <= {ADDR_WIDTH{1'bx}};
            prev_test_length <= 8'hxx;
            prev_test_valid <= 0;
            prev_test_ready <= 0;
        end else begin
            // Check if data is held when ready is low
            if (!prev_test_ready && test_valid) begin
                // Check if data value is same as previous cycle
                if (test_addr !== prev_test_addr || test_length !== prev_test_length || test_valid != prev_test_valid) begin
                    $display("ERROR: Input data not held during stall");
                    $display("  Time: %0t", $time);
                    $display("  Signal: test_addr, test_length, test_valid");
                    $display("  Should be held: addr=%0d, length=%0d, valid=%0d", prev_test_addr, prev_test_length, prev_test_valid);
                    $display("  Actual value: addr=%0d, length=%0d, valid=%0d", test_addr, test_length, test_valid);
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            // Check for undefined values during valid periods
            if (test_valid && test_ready) begin
                if (test_addr === {ADDR_WIDTH{1'bx}} || test_length === 8'hxx) begin
                    $display("ERROR: Undefined value detected in input data");
                    $display("  Time: %0t", $time);
                    $display("  Signal: test_addr or test_length");
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            prev_test_addr <= test_addr;
            prev_test_length <= test_length;
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
            if (!prev_final_ready && dut_valid) begin
                // Check if data value is same as previous cycle
                if (dut_data !== prev_result_data || dut_valid != prev_result_valid) begin
                    $display("ERROR: Output data not held during stall");
                    $display("  Time: %0t", $time);
                    $display("  Signal: dut_data");
                    $display("  Should be held: %0d", prev_result_data);
                    $display("  Actual value: %0d", dut_data);
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            // Check for undefined values during valid periods
            if (dut_valid && dut_ready) begin
                if (dut_data === {DATA_WIDTH{1'bx}}) begin
                    $display("ERROR: Undefined value detected in output data");
                    $display("  Time: %0t", $time);
                    $display("  Signal: dut_data");
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            prev_result_data <= dut_data;
            prev_result_valid <= dut_valid;
            prev_final_ready <= dut_ready;
        end
    end

endmodule 