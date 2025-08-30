// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.
`timescale 1ns / 1ps

module burst_write_pipeline_tb #(
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
    
    // Test pattern generator signals - Address interface
    reg  [ADDR_WIDTH-1:0]  test_addr;
    reg  [7:0]             test_length;
    reg                     test_addr_valid;
    wire                    test_addr_ready;
    
    // Test pattern generator signals - Data interface
    reg  [DATA_WIDTH-1:0]  test_data;
    reg                     test_data_valid;
    wire                    test_data_ready;
    
    // Test pattern arrays (queue arrays) - Address interface
    reg  [ADDR_WIDTH-1:0]  test_addr_array [$];
    reg  [7:0]             test_length_array [$];
    reg                     test_addr_valid_array [$];
    
    // Test pattern arrays (queue arrays) - Data interface
    reg  [DATA_WIDTH-1:0]  test_data_array [$];
    reg                     test_data_valid_array [$];
    
    // Expected response arrays
    reg  [ADDR_WIDTH-1:0]  expected_response_array [$];
    reg                     expected_valid_array [$];
    
    // Stall control arrays
    reg  [2:0]             stall_cycles_array [$];
    
    // Array control variables
    integer                 array_index;
    integer                 array_size;
    integer                 expected_response_index;
    integer                 stall_index;
    
    // DUT interface signals
    wire [ADDR_WIDTH-1:0]  dut_response;
    wire                    dut_valid;
    wire                    dut_ready;
    
    // Test control signals
    reg                     final_ready;
    integer                 test_count;
    integer                 burst_count;
    integer                 response_count;
    integer                 valid_address_count;
    integer                 valid_data_count;
    integer                 bubble_count;
    
    // Burst tracking for reporting
    reg [ADDR_WIDTH-1:0]   current_burst_addr;
    reg [7:0]              current_burst_length;
    integer                 burst_response_count;
    
    // DUT instance
    burst_write_pipeline #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MAX_BURST_LENGTH(MAX_BURST_LENGTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .u_addr(test_addr),
        .u_length(test_length),
        .u_addr_valid(test_addr_valid),
        .u_addr_ready(test_addr_ready),
        .u_data(test_data),
        .u_data_valid(test_data_valid),
        .u_data_ready(test_data_ready),
        .d_response(dut_response),
        .d_valid(dut_valid),
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
        integer bubble_cycles;
        integer data_value;
        
        // Initialize test pattern arrays
        array_size = 0;
        expected_response_index = 0;
        stall_index = 0;
        valid_address_count = 0;
        valid_data_count = 0;
        bubble_count = 0;
        burst_response_count = 0;
        
        // Initialize test signals to avoid X values
        test_addr = 0;
        test_length = 0;
        test_addr_valid = 0;
        test_data = 0;
        test_data_valid = 0;
        
        // Generate test pattern arrays
        for (i = 0; i < TEST_COUNT; i = i + 1) begin
            // Generate random burst length (1 to MAX_BURST_LENGTH)
            burst_length = $urandom_range(1, MAX_BURST_LENGTH);
            
            // Add valid burst request - Address interface
            test_addr_array.push_back(i * 16);  // Start address
            test_length_array.push_back(burst_length - 1);  // Length - 1
            test_addr_valid_array.push_back(1);
            valid_address_count = valid_address_count + 1;
            
            // Add valid data - Data interface
            for (j = 0; j < burst_length; j = j + 1) begin
                data_value = (i * 16) + j;  // Same as address for successful write
                test_data_array.push_back(data_value);
                test_data_valid_array.push_back(1);
                valid_data_count = valid_data_count + 1;
                
                // Expected response (address value for successful write)
                expected_response_array.push_back(data_value);
                expected_valid_array.push_back(1);
                expected_response_index = expected_response_index + 1;
            end
            
            // Generate bubble cycles for address interface
            bubble_cycles = $urandom_range(0, BUBBLE_N);
            
            // Add bubbles for address
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_addr_array.push_back(0);
                test_length_array.push_back(0);
                test_addr_valid_array.push_back(0);
                bubble_count = bubble_count + 1;
            end
            
            // Generate bubble cycles for data interface
            bubble_cycles = $urandom_range(0, BUBBLE_N);
            
            // Add bubbles for data
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_data_array.push_back(0);
                test_data_valid_array.push_back(0);
                bubble_count = bubble_count + 1;
            end
            
            // Generate stall cycles for each burst request (including bubbles)
            stall_cycles = $urandom_range(0, STALL_N);
            stall_cycles_array.push_back(stall_cycles);
            
            // Add stall cycles for bubble cycles as well
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                stall_cycles = $urandom_range(0, STALL_N);
                stall_cycles_array.push_back(stall_cycles);
            end
        end
        
        array_size = test_addr_array.size();
        
        $display("Test initialization completed:");
        $display("  Total address patterns: %0d", test_addr_array.size());
        $display("  Total data patterns: %0d", test_data_array.size());
        $display("  Valid address patterns: %0d", valid_address_count);
        $display("  Valid data patterns: %0d", valid_data_count);
        $display("  Bubble patterns: %0d", bubble_count);
        $display("  Expected responses: %0d", expected_response_index);
    end
    
    // Test pattern generator - Address interface
    reg [31:0] addr_array_index;
    always @(posedge clk) begin
        if (!rst_n) begin
            test_addr <= 0;
            test_length <= 0;
            test_addr_valid <= 0;
            addr_array_index <= 0;
        end else begin
            if (addr_array_index < test_addr_array.size()) begin
                if (test_addr_ready) begin
                    test_addr <= test_addr_array[addr_array_index];
                    test_length <= test_length_array[addr_array_index];
                    test_addr_valid <= test_addr_valid_array[addr_array_index];
                    addr_array_index <= addr_array_index + 1;
                end
            end else begin
                test_addr_valid <= 0;
            end
        end
    end
    
    // Test pattern generator - Data interface
    reg [31:0] data_array_index;
    always @(posedge clk) begin
        if (!rst_n) begin
            test_data <= 0;
            test_data_valid <= 0;
            data_array_index <= 0;
        end else begin
            if (data_array_index < test_data_array.size()) begin
                if (test_data_ready) begin
                    test_data <= test_data_array[data_array_index];
                    test_data_valid <= test_data_valid_array[data_array_index];
                    data_array_index <= data_array_index + 1;
                end
            end else begin
                test_data_valid <= 0;
            end
        end
    end
    
    // Downstream Ready control circuit
    reg [2:0] stall_counter;
    reg stall_active;
    reg [2:0] current_stall_cycles;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            final_ready <= 0;
            stall_counter <= 0;
            stall_active <= 0;
            current_stall_cycles <= 0;
            stall_index <= 0;
        end else begin
            // Default to ready unless stall is active
            final_ready <= 1;
            
            if (stall_counter == 0 && !stall_active) begin
                if (stall_index < stall_cycles_array.size()) begin
                    current_stall_cycles <= stall_cycles_array[stall_index];
                    stall_index <= stall_index + 1;
                end else begin
                    // Reset stall_index when reaching the end to cycle through the array
                    current_stall_cycles <= stall_cycles_array[0];
                    stall_index <= 1;
                end
                
                if (current_stall_cycles > 0) begin
                    final_ready <= 0;
                    stall_counter <= current_stall_cycles;
                    stall_active <= 1;
                end
            end else if (stall_active) begin
                if (stall_counter > 1) begin
                    stall_counter <= stall_counter - 1;
                    final_ready <= 0;
                end else begin
                    final_ready <= 1;
                    stall_counter <= 0;
                    stall_active <= 0;
                end
            end
        end
    end
    
    // Connect final ready to dut ready
    assign dut_ready = final_ready;
    
    // Test result checker circuit
    always @(posedge clk) begin
        if (!rst_n) begin
            test_count <= 0;
            burst_count <= 0;
            response_count <= 0;
            burst_response_count <= 0;
        end else begin
            // Check if test count reached maximum
            if (response_count >= expected_response_index) begin
                $display("Test completed:");
                $display("  Total address patterns: %0d", test_addr_array.size());
                $display("  Total data patterns: %0d", test_data_array.size());
                $display("  Valid address patterns: %0d", valid_address_count);
                $display("  Valid data patterns: %0d", valid_data_count);
                $display("  Bubble patterns: %0d", bubble_count);
                $display("  Total responses: %0d", test_count);
                $display("  Max burst length: %0d", MAX_BURST_LENGTH);
                $display("  Bubble cycles (BUBBLE_N): %0d", BUBBLE_N);
                $display("  Stall cycles (STALL_N): %0d", STALL_N);
                $display("  Total stall cycles generated: %0d", stall_cycles_array.size());
                $display("PASS: All tests passed");
                repeat (1) @(posedge clk);
                $finish;
            end
            
            // Check final output response
            if (dut_valid && dut_ready) begin
                test_count <= test_count + 1;
                burst_response_count <= burst_response_count + 1;
                
                // Check if response matches expected value from array
                if (dut_response !== expected_response_array[response_count]) begin
                    $display("ERROR: Response mismatch at test %0d", test_count);
                    $display("  Time: %0t", $time);
                    $display("  Signal: dut_response");
                    $display("  Expected: 0x%0h, Got: 0x%0h", expected_response_array[response_count], dut_response);
                    $display("  Debug - T1_addr: 0x%0h, T1_data: 0x%0h, T1_we: %0d, T1_valid: %0d", 
                             dut.t1_addr, dut.t1_data, dut.t1_we, dut.t1_valid);
                    $display("  Test count: %0d, Response count: %0d", test_count, response_count);
                    repeat (1) @(posedge clk);
                    $finish;
                end else begin
                    // Success message with test count
                    $display("Time %0t: Test %0d passed - Response: 0x%0h, Test count: %0d, Response count: %0d", 
                             $time, test_count, dut_response, test_count, response_count);
                end
                
                response_count <= response_count + 1;
                
                // Report burst information
                if (dut.t1_last) begin
                    burst_count <= burst_count + 1;
                    $display("Time %0t: Burst %0d completed - Response count: %0d, Test count: %0d", 
                             $time, burst_count, burst_response_count + 1, test_count);
                    burst_response_count <= 0;
                end
            end
        end
    end
    
    // Debug signal monitoring
    always @(posedge clk) begin
        if (dut.t1_valid && dut_ready) begin
            $display("Time %0t: T1 Debug - addr: %0d, data: %0d, we: %0d, valid: %0d, last: %0d", 
                     $time, dut.t1_addr, dut.t1_data, dut.t1_we, dut.t1_valid, dut.t1_last);
        end
    end

endmodule 