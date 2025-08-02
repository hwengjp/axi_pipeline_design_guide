// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

module burst_read_pipeline_tb #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MAX_BURST_LENGTH = 4,
    parameter TEST_MAX_LENGTH = 3,  // テスト用の最大Length値
    parameter TEST_BURST_COUNT = 10,
    parameter BUBBLE_N = 2,
    parameter STALL_N = 2
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
    
    // Test pattern arrays
    reg  [ADDR_WIDTH-1:0]  test_addr_array [0:TEST_BURST_COUNT*4-1];
    reg  [7:0]             test_length_array [0:TEST_BURST_COUNT*4-1];
    reg                     test_valid_array [0:TEST_BURST_COUNT*4-1];
    reg  [DATA_WIDTH-1:0]  expected_data_array [0:TEST_BURST_COUNT*MAX_BURST_LENGTH-1];
    integer                 array_index;
    integer                 array_size;
    integer                 expected_data_index;
    
    // DUT signals
    wire [ADDR_WIDTH-1:0]  dut_mem_addr;
    wire                    dut_mem_read_en;
    wire [DATA_WIDTH-1:0]  dut_data;
    wire                    dut_valid;
    wire                    dut_last;
    wire                    dut_ready;
    
    // Memory interface (simulated)
    wire [DATA_WIDTH-1:0]  mem_data;
    wire                    mem_valid;
    
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
        .mem_addr(dut_mem_addr),
        .mem_read_en(dut_mem_read_en),
        .mem_data(mem_data),
        .mem_valid(mem_valid),
        .d_data(dut_data),
        .d_valid(dut_valid),
        .d_last(dut_last),
        .d_ready(dut_ready)
    );
    
    // Memory simulation (data = address, latency = 1)
    reg [DATA_WIDTH-1:0] mem_data_reg;
    reg mem_valid_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_data_reg <= {DATA_WIDTH{1'b0}};
            mem_valid_reg <= 1'b0;
        end else if (dut_mem_read_en) begin
            mem_data_reg <= dut_mem_addr;
            mem_valid_reg <= 1'b1;
        end else begin
            mem_valid_reg <= 1'b0;
        end
    end
    
    assign mem_data = mem_data_reg;
    assign mem_valid = mem_valid_reg;
    
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
        
        // Initialize test pattern arrays
        array_size = 0;
        expected_data_index = 0;
        
        // Generate test pattern arrays
        for (i = 0; i < TEST_BURST_COUNT; i = i + 1) begin
            // Generate random burst length (1 to TEST_MAX_LENGTH)
            burst_length = ($random % TEST_MAX_LENGTH) + 1;
            
            // Add valid burst request
            test_addr_array[array_size] = i * 16;  // Start address
            test_length_array[array_size] = burst_length - 1;  // Length - 1
            test_valid_array[array_size] = 1;
            array_size = array_size + 1;
            
            // Generate expected data for this burst
            for (j = 0; j < burst_length; j = j + 1) begin
                expected_data_array[expected_data_index] = (i * 16) + j;
                expected_data_index = expected_data_index + 1;
            end
            
            // Generate bubble cycles
            bubble_cycles = $random % (BUBBLE_N + 4) - BUBBLE_N;
            if (bubble_cycles < 0) bubble_cycles = 0;
            
            // Add bubbles
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_addr_array[array_size] = {ADDR_WIDTH{1'bx}};
                test_length_array[array_size] = 8'hxx;
                test_valid_array[array_size] = 0;
                array_size = array_size + 1;
            end
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
    
    // Connect final ready to dut ready
    assign dut_ready = final_ready;
    
    // Test result checker circuit
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state
            test_count <= 0;
            burst_count <= 0;
            data_count <= 0;
        end else begin
            // Check if test count reached maximum
            if (data_count >= expected_data_index) begin
                $display("Test completed:");
                $display("  Total bursts: %0d", burst_count);
                $display("  Total data: %0d", test_count);
                $display("  Test max length: %0d", TEST_MAX_LENGTH);
                $display("PASS: All tests passed");
                // Stop after 1 clock cycle on success
                repeat (1) @(posedge clk);
                $finish;
            end
            
            // Check final output data
            if (dut_valid && dut_ready) begin
                test_count <= test_count + 1;
                
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
                end else begin
                    $display("PASS: Test %0d, Data: %0d, Last: %0d", test_count, dut_data, dut_last);
                end
                
                data_count <= data_count + 1;
                
                // Count bursts
                if (dut_last) begin
                    burst_count <= burst_count + 1;
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
                    $display("  Signal: test_addr");
                    $display("  Should be held: %0d", prev_test_addr);
                    $display("  Actual value: %0d", test_addr);
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