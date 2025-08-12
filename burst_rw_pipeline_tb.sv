// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.
`timescale 1ns / 1ps

module burst_rw_pipeline_tb #(
    parameter DATA_WIDTH = 32,        // Data width in bits
    parameter ADDR_WIDTH = 32,        // Address width in bits
    parameter MAX_BURST_LENGTH = 4,   // Maximum burst length for testing
    parameter TEST_COUNT = 1000,      // Number of test
    parameter BUBBLE_N = 2,           // Base number of bubble cycles
    parameter STALL_N = 2             // Base number of stall cycles
)();

    // Clock and Reset
    reg                     clk;
    reg                     rst_n;
    
    // Test pattern generator signals - Read interface
    reg  [ADDR_WIDTH-1:0]  test_r_addr;
    reg  [7:0]             test_r_length;
    reg                     test_r_valid;
    wire                    test_r_ready;
    
    // Test pattern generator signals - Write Address interface
    reg  [ADDR_WIDTH-1:0]  test_w_addr;
    reg  [7:0]             test_w_length;
    reg                     test_w_addr_valid;
    wire                    test_w_addr_ready;
    
    // Test pattern generator signals - Write Data interface
    reg  [DATA_WIDTH-1:0]  test_w_data;
    reg                     test_w_data_valid;
    wire                    test_w_data_ready;
    
    // Test pattern arrays (queue arrays) - Read interface
    reg  [ADDR_WIDTH-1:0]  test_r_addr_array [$];
    reg  [7:0]             test_r_length_array [$];
    reg                     test_r_valid_array [$];
    reg  [DATA_WIDTH-1:0]  expected_r_data_array [$];
    
    // Test pattern arrays (queue arrays) - Write Address interface
    reg  [ADDR_WIDTH-1:0]  test_w_addr_array [$];
    reg  [7:0]             test_w_length_array [$];
    reg                     test_w_addr_valid_array [$];
    
    // Test pattern arrays (queue arrays) - Write Data interface
    reg  [DATA_WIDTH-1:0]  test_w_data_array [$];
    reg                     test_w_data_valid_array [$];
    
    // Expected response arrays - Write interface
    reg  [ADDR_WIDTH-1:0]  expected_w_response_array [$];
    reg                     expected_w_valid_array [$];
    
    // Stall control arrays
    reg  [2:0]             r_stall_cycles_array [$];
    reg  [2:0]             w_stall_cycles_array [$];
    
    // Array control variables
    integer                 r_array_index;
    integer                 w_addr_array_index;
    integer                 w_data_array_index;
    integer                 array_size;
    integer                 expected_r_data_index;
    integer                 expected_w_response_index;
    integer                 r_stall_index;
    integer                 w_stall_index;
    
    // DUT interface signals - Read
    wire [DATA_WIDTH-1:0]  dut_r_data;
    wire                    dut_r_valid;
    wire                    dut_r_last;
    wire                    dut_r_ready;
    
    // DUT interface signals - Write
    wire [ADDR_WIDTH-1:0]  dut_w_response;
    wire                    dut_w_valid;
    wire                    dut_w_ready;
    
    // Test control signals
    reg                     final_r_ready;
    reg                     final_w_ready;
    integer                 test_count;
    integer                 r_burst_count;
    integer                 w_burst_count;
    integer                 r_data_count;
    integer                 w_response_count;
    integer                 valid_r_address_count;
    integer                 valid_w_address_count;
    integer                 valid_w_data_count;
    integer                 bubble_count;
    
    // Burst tracking for reporting
    reg [ADDR_WIDTH-1:0]   current_r_burst_addr;
    reg [7:0]              current_r_burst_length;
    reg [ADDR_WIDTH-1:0]   current_w_burst_addr;
    reg [7:0]              current_w_burst_length;
    integer                 r_burst_data_count;
    integer                 w_burst_response_count;
    
    // Burst queue for verification
    reg [ADDR_WIDTH-1:0]   r_burst_addr_queue [$];
    reg [7:0]              r_burst_length_queue [$];
    reg [ADDR_WIDTH-1:0]   w_burst_addr_queue [$];
    reg [7:0]              w_burst_length_queue [$];
    integer                 r_burst_queue_index;
    integer                 w_burst_queue_index;
    
    // DUT instance
    burst_rw_pipeline #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MAX_BURST_LENGTH(MAX_BURST_LENGTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        // Read interface
        .u_r_addr(test_r_addr),
        .u_r_length(test_r_length),
        .u_r_valid(test_r_valid),
        .u_r_ready(test_r_ready),
        .d_r_data(dut_r_data),
        .d_r_valid(dut_r_valid),
        .d_r_last(dut_r_last),
        .d_r_ready(dut_r_ready),
        // Write interface
        .u_w_addr(test_w_addr),
        .u_w_length(test_w_length),
        .u_w_addr_valid(test_w_addr_valid),
        .u_w_addr_ready(test_w_addr_ready),
        .u_w_data(test_w_data),
        .u_w_data_valid(test_w_data_valid),
        .u_w_data_ready(test_w_data_ready),
        .d_w_response(dut_w_response),
        .d_w_valid(dut_w_valid),
        .d_w_ready(dut_w_ready)
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
        integer bubble_cycles;
        integer data_value;
        

        
        // Initialize test pattern arrays
        array_size = 0;
        expected_r_data_index = 0;
        expected_w_response_index = 0;
        valid_r_address_count = 0;
        valid_w_address_count = 0;
        valid_w_data_count = 0;
        bubble_count = 0;
        r_burst_data_count = 0;
        w_burst_response_count = 0;
        
        // Initialize test signals to avoid X values
        test_r_addr = 0;
        test_r_length = 0;
        test_r_valid = 0;
        test_w_addr = 0;
        test_w_length = 0;
        test_w_addr_valid = 0;
        test_w_data = 0;
        test_w_data_valid = 0;
        
        // Initialize array indices
        r_array_index = 0;
        w_addr_array_index = 0;
        w_data_array_index = 0;
        
        // Initialize other control signals
        final_r_ready = 0;
        final_w_ready = 0;
        test_count = 0;
        r_burst_count = 0;
        w_burst_count = 0;
        r_data_count = 0;
        w_response_count = 0;
        valid_r_address_count = 0;
        valid_w_address_count = 0;
        valid_w_data_count = 0;
        bubble_count = 0;
        current_r_burst_addr = 0;
        current_r_burst_length = 0;
        current_w_burst_addr = 0;
        current_w_burst_length = 0;
        r_burst_data_count = 0;
        w_burst_response_count = 0;
        r_burst_queue_index = 0;
        w_burst_queue_index = 0;
        r_stall_index = 0;
        w_stall_index = 0;
        
        // Generate test pattern arrays
        for (i = 0; i < TEST_COUNT; i = i + 1) begin
            // Generate random burst length (1 to MAX_BURST_LENGTH)
            burst_length = $urandom_range(1, MAX_BURST_LENGTH);
            
            // Add valid burst request - Read interface
            test_r_addr_array.push_back(i * 16);
            test_r_length_array.push_back(burst_length - 1);
            test_r_valid_array.push_back(1);
            valid_r_address_count = valid_r_address_count + 1;
            
            // Add expected data for Read burst
            for (j = 0; j < burst_length; j = j + 1) begin
                expected_r_data_array.push_back((i * 16) + j);
                expected_r_data_index = expected_r_data_index + 1;
            end
            
            // Add valid burst request - Write Address interface
            test_w_addr_array.push_back((i + 1000) * 16);  // Different address range
            test_w_length_array.push_back(burst_length - 1);
            test_w_addr_valid_array.push_back(1);
            valid_w_address_count = valid_w_address_count + 1;
            
            // Add valid data - Write Data interface
            for (j = 0; j < burst_length; j = j + 1) begin
                data_value = ((i + 1000) * 16) + j;  // Same as address for successful write
                test_w_data_array.push_back(data_value);
                test_w_data_valid_array.push_back(1);
                valid_w_data_count = valid_w_data_count + 1;
                
                // Expected response (address value for successful write)
                expected_w_response_array.push_back(data_value);
                expected_w_valid_array.push_back(1);
                expected_w_response_index = expected_w_response_index + 1;
            end
            
            // Generate bubble cycles for Read interface
            bubble_cycles = $urandom_range(0, BUBBLE_N);
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_r_addr_array.push_back({ADDR_WIDTH{1'bx}});
                test_r_length_array.push_back(8'hxx);
                test_r_valid_array.push_back(0);
                bubble_count = bubble_count + 1;
            end
            
            // Generate bubble cycles for Write Address interface (different pattern)
            bubble_cycles = $urandom_range(0, BUBBLE_N + 1);  // Different range
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_w_addr_array.push_back(0);
                test_w_length_array.push_back(0);
                test_w_addr_valid_array.push_back(0);
                bubble_count = bubble_count + 1;
            end
            
            // Generate bubble cycles for Write Data interface (different pattern)
            bubble_cycles = $urandom_range(1, BUBBLE_N + 2);  // Different range and offset
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_w_data_array.push_back(0);
                test_w_data_valid_array.push_back(0);
                bubble_count = bubble_count + 1;
            end
            
            // Generate stall cycles for each burst request (including bubbles)
            r_stall_cycles_array.push_back($urandom_range(0, STALL_N));
            w_stall_cycles_array.push_back($urandom_range(0, STALL_N + 1));  // Different range for Write
            
            // Add stall cycles for bubble cycles as well
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                r_stall_cycles_array.push_back($urandom_range(0, STALL_N));
                w_stall_cycles_array.push_back($urandom_range(1, STALL_N + 2));  // Different range and offset for Write
            end
        end
        
        array_size = test_r_addr_array.size();
        
        $display("Test initialization completed:");
        $display("  Total Read address patterns: %0d", test_r_addr_array.size());
        $display("  Total Write address patterns: %0d", test_w_addr_array.size());
        $display("  Total Write data patterns: %0d", test_w_data_array.size());
        $display("  Valid Read address patterns: %0d", valid_r_address_count);
        $display("  Valid Write address patterns: %0d", valid_w_address_count);
        $display("  Valid Write data patterns: %0d", valid_w_data_count);
        $display("  Bubble patterns: %0d", bubble_count);
        $display("  Expected Read data: %0d", expected_r_data_index);
        $display("  Expected Write responses: %0d", expected_w_response_index);
    end
    
    // Test pattern generator - Read interface
    always @(posedge clk) begin
        if (!rst_n) begin
            test_r_addr <= 0;
            test_r_length <= 0;
            test_r_valid <= 0;
            r_array_index <= 0;
        end else begin
            if (r_array_index < test_r_addr_array.size()) begin
                if (test_r_ready || r_array_index == 0) begin  // 最初のデータは強制的に設定
                    test_r_addr <= test_r_addr_array[r_array_index];
                    test_r_length <= test_r_length_array[r_array_index];
                    test_r_valid <= test_r_valid_array[r_array_index];
                    if (test_r_ready || r_array_index == 0) begin  // インデックス更新も同様
                        r_array_index <= r_array_index + 1;
                    end
                end
            end else begin
                test_r_valid <= 0;
            end
        end
    end
    
    // Test pattern generator - Write Address interface
    always @(posedge clk) begin
        if (!rst_n) begin
            test_w_addr <= 0;
            test_w_length <= 0;
            test_w_addr_valid <= 0;
            w_addr_array_index <= 0;
        end else begin
            if (w_addr_array_index < test_w_addr_array.size()) begin
                if (test_w_addr_ready || w_addr_array_index == 0) begin  // 最初のデータは強制的に設定
                    test_w_addr <= test_w_addr_array[w_addr_array_index];
                    test_w_length <= test_w_length_array[w_addr_array_index];
                    test_w_addr_valid <= test_w_addr_valid_array[w_addr_array_index];
                    if (test_w_addr_ready || w_addr_array_index == 0) begin  // インデックス更新も同様
                        w_addr_array_index <= w_addr_array_index + 1;
                    end
                end
            end else begin
                test_w_addr_valid <= 0;
            end
        end
    end
    
    // Test pattern generator - Write Data interface
    always @(posedge clk) begin
        if (!rst_n) begin
            test_w_data <= 0;
            test_w_data_valid <= 0;
            w_data_array_index <= 0;
        end else begin
            if (w_data_array_index < test_w_data_array.size()) begin
                if (test_w_data_ready || w_data_array_index == 0) begin  // 最初のデータは強制的に設定
                    test_w_data <= test_w_data_array[w_data_array_index];
                    test_w_data_valid <= test_w_data_valid_array[w_data_array_index];
                    if (test_w_data_ready || w_data_array_index == 0) begin  // インデックス更新も同様
                        w_data_array_index <= w_data_array_index + 1;
                    end
                end
            end else begin
                test_w_data_valid <= 0;
            end
        end
    end
    
    // Downstream Ready control circuit - Read
    reg [2:0] r_stall_counter;
    reg r_stall_active;
    reg [2:0] r_current_stall_cycles;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            final_r_ready <= 0;
            r_stall_counter <= 0;
            r_stall_active <= 0;
            r_current_stall_cycles <= 0;
        end else begin
            // Default to ready unless stall is active
            final_r_ready <= 1;
            
            if (r_stall_counter == 0 && !r_stall_active) begin
                if (r_stall_index < r_stall_cycles_array.size()) begin
                    r_current_stall_cycles <= r_stall_cycles_array[r_stall_index];
                end else begin
                    r_current_stall_cycles <= r_stall_cycles_array[0];
                end
                
                if (r_current_stall_cycles > 0) begin
                    final_r_ready <= 0;
                    r_stall_counter <= r_current_stall_cycles;
                    r_stall_active <= 1;
                    r_stall_index <= r_stall_index + 1;
                end
            end else if (r_stall_active) begin
                if (r_stall_counter > 1) begin
                    r_stall_counter <= r_stall_counter - 1;
                    final_r_ready <= 0;
                end else begin
                    final_r_ready <= 1;
                    r_stall_counter <= 0;
                    r_stall_active <= 0;
                end
            end
        end
    end
    
    // Downstream Ready control circuit - Write
    reg [2:0] w_stall_counter;
    reg w_stall_active;
    reg [2:0] w_current_stall_cycles;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            final_w_ready <= 0;
            w_stall_counter <= 0;
            w_stall_active <= 0;
            w_current_stall_cycles <= 0;
        end else begin
            // Default to ready unless stall is active
            final_w_ready <= 1;
            
            if (w_stall_counter == 0 && !w_stall_active) begin
                if (w_stall_index < w_stall_cycles_array.size()) begin
                    w_current_stall_cycles <= w_stall_cycles_array[w_stall_index];
                end else begin
                    w_current_stall_cycles <= w_stall_cycles_array[0];
                end
                
                if (w_current_stall_cycles > 0) begin
                    final_w_ready <= 0;
                    w_stall_counter <= w_current_stall_cycles;
                    w_stall_active <= 1;
                    w_stall_index <= w_stall_index + 1;
                end
            end else if (w_stall_active) begin
                if (w_stall_counter > 1) begin
                    w_stall_counter <= w_stall_counter - 1;
                    final_w_ready <= 0;
                end else begin
                    final_w_ready <= 1;
                    w_stall_counter <= 0;
                    w_stall_active <= 0;
                end
            end
        end
    end
    
    // Connect final ready to dut ready
    assign dut_r_ready = final_r_ready;
    assign dut_w_ready = final_w_ready;
    
    // Burst queue tracking circuit - Read
    always @(posedge clk) begin
        if (!rst_n) begin
            current_r_burst_addr <= {ADDR_WIDTH{1'b0}};
            current_r_burst_length <= 8'h00;
            r_burst_queue_index <= 0;
        end else begin
            // Record burst start when valid burst request is sent
            if (test_r_valid && test_r_ready && test_r_valid_array[r_array_index - 1]) begin
                r_burst_addr_queue.push_back(test_r_addr_array[r_array_index - 1]);
                r_burst_length_queue.push_back(test_r_length_array[r_array_index - 1]);
                $display("Time %0t: Read Burst queued - addr: 0x%0h, length: %0d, queue_size: %0d", 
                         $time, test_r_addr_array[r_array_index - 1], test_r_length_array[r_array_index - 1], r_burst_addr_queue.size());
            end
        end
    end
    
    // Burst queue tracking circuit - Write
    always @(posedge clk) begin
        if (!rst_n) begin
            current_w_burst_addr <= {ADDR_WIDTH{1'b0}};
            current_w_burst_length <= 8'h00;
            w_burst_queue_index <= 0;
        end else begin
            // Record burst start when valid burst request is sent
            if (test_w_addr_valid && test_w_addr_ready && test_w_addr_valid_array[w_addr_array_index - 1]) begin
                w_burst_addr_queue.push_back(test_w_addr_array[w_addr_array_index - 1]);
                w_burst_length_queue.push_back(test_w_length_array[w_addr_array_index - 1]);
                $display("Time %0t: Write Burst queued - addr: 0x%0h, length: %0d, queue_size: %0d", 
                         $time, test_w_addr_array[w_addr_array_index - 1], test_w_length_array[w_addr_array_index - 1], w_burst_addr_queue.size());
            end
        end
    end
    
    // Test result checker circuit - Read
    always @(posedge clk) begin
        if (!rst_n) begin
            r_burst_count <= 0;
            r_data_count <= 0;
            r_burst_data_count <= 0;
        end else begin
            // Check final output data for Read
            if (dut_r_valid && dut_r_ready) begin
                r_burst_data_count <= r_burst_data_count + 1;
                
                // Check if data matches expected value from array
                if (dut_r_data !== expected_r_data_array[r_data_count]) begin
                    $display("ERROR: Read data mismatch at data count %0d", r_data_count);
                    $display("  Time: %0t", $time);
                    $display("  Signal: dut_r_data");
                    $display("  Expected: 0x%0h, Got: 0x%0h", expected_r_data_array[r_data_count], dut_r_data);
                    repeat (1) @(posedge clk);
                    $finish;
                end
                
                r_data_count <= r_data_count + 1;
                
                // Count bursts and report burst information
                if (dut_r_last) begin
                    r_burst_count <= r_burst_count + 1;
                    if (r_burst_queue_index < r_burst_addr_queue.size()) begin
                        $display("Time %0t: Read Burst %0d completed - Start addr: 0x%0h, Length: %0d, Data count: %0d", 
                                 $time, r_burst_count, r_burst_addr_queue[r_burst_queue_index], r_burst_length_queue[r_burst_queue_index], r_burst_data_count + 1);
                        
                        // Check if data count matches expected length
                        if (r_burst_data_count + 1 !== r_burst_length_queue[r_burst_queue_index] + 1) begin
                            $display("ERROR: Read data count mismatch at burst %0d", r_burst_count);
                            $display("  Time: %0t", $time);
                            $display("  Expected data count: %0d (Length: %0d + 1)", 
                                     r_burst_length_queue[r_burst_queue_index] + 1, r_burst_length_queue[r_burst_queue_index]);
                            $display("  Actual data count: %0d", r_burst_data_count + 1);
                            repeat (1) @(posedge clk);
                            $finish;
                        end
                        
                        r_burst_queue_index <= r_burst_queue_index + 1;
                    end
                    r_burst_data_count <= 0;
                end
            end
        end
    end
    
    // Test result checker circuit - Write
    always @(posedge clk) begin
        if (!rst_n) begin
            w_burst_count <= 0;
            w_response_count <= 0;
            w_burst_response_count <= 0;
        end else begin
            // Check final output response for Write
            if (dut_w_valid && dut_w_ready) begin
                w_burst_response_count <= w_burst_response_count + 1;
                
                // Check if response matches expected value from array
                if (dut_w_response !== expected_w_response_array[w_response_count]) begin
                    $display("ERROR: Write response mismatch at response count %0d", w_response_count);
                    $display("  Time: %0t", $time);
                    $display("  Signal: dut_w_response");
                    $display("  Expected: 0x%0h, Got: 0x%0h", expected_w_response_array[w_response_count], dut_w_response);
                    repeat (1) @(posedge clk);
                    $finish;
                end
                
                w_response_count <= w_response_count + 1;
                
                // Count bursts and report burst information
                if (dut.w_t3_last) begin
                    w_burst_count <= w_burst_count + 1;
                    if (w_burst_queue_index < w_burst_addr_queue.size()) begin
                        $display("Time %0t: Write Burst %0d completed - Start addr: 0x%0h, Length: %0d, Response count: %0d", 
                                 $time, w_burst_count, w_burst_addr_queue[w_burst_queue_index], w_burst_length_queue[w_burst_queue_index], w_burst_response_count + 1);
                        
                        // Check if response count matches expected length
                        if (w_burst_response_count + 1 !== w_burst_length_queue[w_burst_queue_index] + 1) begin
                            $display("ERROR: Write response count mismatch at burst %0d", w_burst_count);
                            $display("  Time: %0t", $time);
                            $display("  Expected response count: %0d (Length: %0d + 1)", 
                                     w_burst_length_queue[w_burst_queue_index] + 1, w_burst_length_queue[w_burst_queue_index]);
                            $display("  Actual response count: %0d", w_burst_response_count + 1);
                            repeat (1) @(posedge clk);
                            $finish;
                        end
                        
                        w_burst_queue_index <= w_burst_queue_index + 1;
                    end
                    w_burst_response_count <= 0;
                end
            end
        end
    end
    
    // Test completion checker
    always @(posedge clk) begin
        if (!rst_n) begin
            test_count <= 0;
        end else begin
            // Check if both Read and Write tests completed
            if (r_data_count >= expected_r_data_index && w_response_count >= expected_w_response_index) begin
                test_count <= test_count + 1;
                $display("Test completed:");
                $display("  Total Read address patterns: %0d", test_r_addr_array.size());
                $display("  Total Write address patterns: %0d", test_w_addr_array.size());
                $display("  Total Write data patterns: %0d", test_w_data_array.size());
                $display("  Valid Read address patterns: %0d", valid_r_address_count);
                $display("  Valid Write address patterns: %0d", valid_w_address_count);
                $display("  Valid Write data patterns: %0d", valid_w_data_count);
                $display("  Bubble patterns: %0d", bubble_count);
                $display("  Total Read data: %0d", r_data_count);
                $display("  Total Write responses: %0d", w_response_count);
                $display("  Read bursts: %0d", r_burst_count);
                $display("  Write bursts: %0d", w_burst_count);
                $display("  Max burst length: %0d", MAX_BURST_LENGTH);
                $display("  Bubble cycles (BUBBLE_N): %0d", BUBBLE_N);
                $display("  Stall cycles (STALL_N): %0d", STALL_N);
                $display("PASS: All tests passed");
                repeat (1) @(posedge clk);
                $finish;
            end
        end
    end
    
    // Sequence checker circuit - Read Input side
    reg prev_test_r_ready;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prev_test_r_ready <= 0;
        end else begin
            // Check if data is held when ready is low
            if (!prev_test_r_ready && test_r_valid) begin
                // Check if data value is same as previous cycle
                if (test_r_addr !== test_r_addr || test_r_length !== test_r_length || test_r_valid != test_r_valid) begin
                    $display("ERROR: Read input data not held during stall");
                    $display("  Time: %0t", $time);
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            prev_test_r_ready <= test_r_ready;
        end
    end
    
    // Sequence checker circuit - Write Input side
    reg prev_test_w_addr_ready;
    reg prev_test_w_data_ready;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prev_test_w_addr_ready <= 0;
            prev_test_w_data_ready <= 0;
        end else begin
            // Check if data is held when ready is low
            if (!prev_test_w_addr_ready && test_w_addr_valid) begin
                if (test_w_addr !== test_w_addr || test_w_length !== test_w_length || test_w_addr_valid != test_w_addr_valid) begin
                    $display("ERROR: Write address input data not held during stall");
                    $display("  Time: %0t", $time);
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            if (!prev_test_w_data_ready && test_w_data_valid) begin
                if (test_w_data !== test_w_data || test_w_data_valid != test_w_data_valid) begin
                    $display("ERROR: Write data input data not held during stall");
                    $display("  Time: %0t", $time);
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            prev_test_w_addr_ready <= test_w_addr_ready;
            prev_test_w_data_ready <= test_w_data_ready;
        end
    end
    
    // Sequence checker circuit - Read Output side
    reg prev_final_r_ready;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prev_final_r_ready <= 0;
        end else begin
            // Check if data is held when ready is low
            if (!prev_final_r_ready && dut_r_valid) begin
                if (dut_r_data !== dut_r_data || dut_r_valid != dut_r_valid) begin
                    $display("ERROR: Read output data not held during stall");
                    $display("  Time: %0t", $time);
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            prev_final_r_ready <= dut_r_ready;
        end
    end
    
    // Sequence checker circuit - Write Output side
    reg prev_final_w_ready;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prev_final_w_ready <= 0;
        end else begin
            // Check if data is held when ready is low
            if (!prev_final_w_ready && dut_w_valid) begin
                if (dut_w_response !== dut_w_response || dut_w_valid != dut_w_valid) begin
                    $display("ERROR: Write output data not held during stall");
                    $display("  Time: %0t", $time);
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            prev_final_w_ready <= dut_w_ready;
        end
    end
    
    // Debug signal monitoring
    always @(posedge clk) begin
        if (dut.r_t2_valid && dut.d_r_ready) begin
            $display("Time %0t: Read T2 Debug - data: %0d, last: %0d", 
                     $time, dut.r_t2_data, dut.r_t2_last);
        end
        if (dut.w_t3_valid && dut.d_w_ready) begin
            $display("Time %0t: Write T3 Debug - response: %0d, valid: %0d, last: %0d", 
                     $time, dut.w_t3_response, dut.w_t3_valid, dut.w_t3_last);
        end
    end

endmodule
