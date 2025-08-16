// Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.
`timescale 1ns / 1ps

module axi_simple_dual_port_ram_tb #(
    parameter MEMORY_SIZE_BYTES = 16384,         // 16KB memory size
    parameter AXI_DATA_WIDTH = 32,               // 32-bit data width
    parameter AXI_ID_WIDTH = 8,                  // 8-bit ID width
    parameter AXI_STRB_WIDTH = AXI_DATA_WIDTH/8, // Strobe width (calculated)
    parameter AXI_ADDR_WIDTH = $clog2(MEMORY_SIZE_BYTES), // Address width (auto-calculated)
    parameter MAX_BURST_LENGTH = 16,             // Maximum burst length for testing
    parameter TEST_COUNT = 1000,                 // Number of test bursts
    parameter BUBBLE_N = 2,                      // Base number of bubble cycles
    parameter STALL_N = 2                        // Base number of stall cycles
)();

    // Clock and Reset
    reg                     axi_clk;
    reg                     axi_resetn;
    
    // AXI Read Address Channel
    reg  [AXI_ADDR_WIDTH-1:0] axi_ar_addr;
    reg  [1:0]                axi_ar_burst;
    reg  [2:0]                axi_ar_size;
    reg  [AXI_ID_WIDTH-1:0]   axi_ar_id;
    reg  [7:0]                axi_ar_len;
    wire                      axi_ar_ready;
    reg                       axi_ar_valid;
    
    // AXI Read Data Channel
    wire [AXI_DATA_WIDTH-1:0] axi_r_data;
    wire [AXI_ID_WIDTH-1:0]   axi_r_id;
    wire [1:0]                axi_r_resp;
    wire                      axi_r_last;
    reg                       axi_r_ready;
    wire                      axi_r_valid;
    
    // AXI Write Address Channel
    reg  [AXI_ADDR_WIDTH-1:0] axi_aw_addr;
    reg  [1:0]                axi_aw_burst;
    reg  [2:0]                axi_aw_size;
    reg  [AXI_ID_WIDTH-1:0]   axi_aw_id;
    reg  [7:0]                axi_aw_len;
    wire                      axi_aw_ready;
    reg                       axi_aw_valid;
    
    // AXI Write Data Channel
    reg  [AXI_DATA_WIDTH-1:0] axi_w_data;
    reg                       axi_w_last;
    reg  [AXI_STRB_WIDTH-1:0] axi_w_strb;
    wire                      axi_w_ready;
    reg                       axi_w_valid;
    
    // AXI Write Response Channel
    wire [AXI_ID_WIDTH-1:0]   axi_b_id;
    wire [1:0]                axi_b_resp;
    reg                       axi_b_ready;
    wire                      axi_b_valid;
    
    // Test pattern arrays - Write interface (burst-based)
    reg  [AXI_ADDR_WIDTH-1:0] test_w_burst_addr_array [$];    // Base address for each burst
    reg  [7:0]                test_w_burst_length_array [$];   // Length for each burst
    reg  [AXI_ID_WIDTH-1:0]   test_w_burst_id_array [$];      // ID for each burst
    reg  [1:0]                test_w_burst_type_array [$];     // Burst type for each burst
    reg  [AXI_DATA_WIDTH-1:0] test_w_data_array [$];           // Data for all beats
    reg                       test_w_last_array [$];            // Last flag for all beats
    reg  [AXI_STRB_WIDTH-1:0] test_w_strb_array [$];          // Strobe for all beats
    
    // Test pattern arrays - Read interface
    reg  [AXI_ADDR_WIDTH-1:0] test_r_addr_array [$];
    reg  [7:0]                test_r_length_array [$];
    reg  [AXI_ID_WIDTH-1:0]   test_r_id_array [$];
    reg  [1:0]                test_r_burst_array [$];
    
    // Expected response arrays
    reg  [AXI_DATA_WIDTH-1:0] expected_r_data_array [$];
    reg  [AXI_ID_WIDTH-1:0]   expected_r_id_array [$];
    reg  [AXI_ID_WIDTH-1:0]   expected_b_id_array [$];
    
    // Track processed write response IDs
    reg  [AXI_ID_WIDTH-1:0]   processed_b_id_array [$];
    
    // Write completion tracking
    reg                       write_complete_array [$];         // Track completion of each write burst
    reg                       read_started_array [$];           // Track if read has started for each burst
    
    // Array control variables
    integer                   w_array_index;
    integer                   r_array_index;
    integer                   expected_r_data_index;
    integer                   array_size;
    
    // Test control signals
    integer                   test_count;
    integer                   w_burst_count;
    integer                   r_burst_count;
    integer                   w_data_count;
    integer                   r_data_count;
    integer                   b_response_count;
    
    // Burst tracking for reporting
    reg [AXI_ADDR_WIDTH-1:0] current_w_burst_addr;
    reg [7:0]                current_w_burst_length;
    reg [AXI_ID_WIDTH-1:0]   current_w_burst_id;
    integer                   current_w_burst_index;  // Track the sequential burst index
    reg [AXI_ADDR_WIDTH-1:0] current_r_burst_addr;
    reg [7:0]                current_r_burst_length;
    reg [AXI_ID_WIDTH-1:0]   current_r_burst_id;
    integer                   current_r_burst_index;  // Track the sequential read burst index
    integer                   w_burst_beat_count;      // Current beat count within burst
    integer                   w_burst_total_count;     // Total beats in current burst
    integer                   r_burst_data_count;
    
    // Burst verification queues
    reg [AXI_ADDR_WIDTH-1:0] w_burst_addr_queue [$];
    reg [7:0]                w_burst_length_queue [$];
    reg [AXI_ID_WIDTH-1:0]   w_burst_id_queue [$];
    reg [AXI_ADDR_WIDTH-1:0] r_burst_addr_queue [$];
    reg [7:0]                r_burst_length_queue [$];
    reg [AXI_ID_WIDTH-1:0]   r_burst_id_queue [$];
    integer                   w_burst_queue_index;
    integer                   r_burst_queue_index;
    
    // Test state machine
    reg [2:0]                test_state;
    reg [2:0]                next_test_state;
    reg [1:0]                burst_set_count;
    reg                       test_complete;
    
    // New control signals for channel management
    reg                       start_write_phase;
    reg                       start_read_phase;
    reg                       start_simultaneous_phase;
    reg [1:0]                phase_burst_count;      // Number of bursts to execute in current phase
    reg                       phase_complete;
    reg                       write_phase_complete;
    reg                       read_phase_complete;
    reg                       simultaneous_phase_complete;
    
    // Channel control signals
    reg                       write_addr_start;
    reg                       write_data_start;
    reg                       write_resp_start;
    reg                       read_addr_start;
    reg                       read_data_start;
    
    // Channel completion tracking
    reg                       write_addr_complete;
    reg                       write_data_complete;
    reg                       write_resp_complete;
    reg                       read_addr_complete;
    reg                       read_data_complete;
    
    // DUT instance
    axi_simple_dual_port_ram #(
        .MEMORY_SIZE_BYTES(MEMORY_SIZE_BYTES),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH)
    ) dut (
        .axi_clk(axi_clk),
        .axi_resetn(axi_resetn),
        // AXI Read Address Channel
        .axi_ar_addr(axi_ar_addr),
        .axi_ar_burst(axi_ar_burst),
        .axi_ar_size(axi_ar_size),
        .axi_ar_id(axi_ar_id),
        .axi_ar_len(axi_ar_len),
        .axi_ar_ready(axi_ar_ready),
        .axi_ar_valid(axi_ar_valid),
        // AXI Read Data Channel
        .axi_r_data(axi_r_data),
        .axi_r_id(axi_r_id),
        .axi_r_resp(axi_r_resp),
        .axi_r_last(axi_r_last),
        .axi_r_ready(axi_r_ready),
        .axi_r_valid(axi_r_valid),
        // AXI Write Address Channel
        .axi_aw_addr(axi_aw_addr),
        .axi_aw_burst(axi_aw_burst),
        .axi_aw_size(axi_aw_size),
        .axi_aw_id(axi_aw_id),
        .axi_aw_len(axi_aw_len),
        .axi_aw_ready(axi_aw_ready),
        .axi_aw_valid(axi_aw_valid),
        // AXI Write Data Channel
        .axi_w_data(axi_w_data),
        .axi_w_last(axi_w_last),
        .axi_w_strb(axi_w_strb),
        .axi_w_valid(axi_w_valid),
        .axi_w_ready(axi_w_ready),
        // AXI Write Response Channel
        .axi_b_id(axi_b_id),
        .axi_b_resp(axi_b_resp),
        .axi_b_ready(axi_b_ready),
        .axi_b_valid(axi_b_valid)
    );
    
    // Clock generation (10ns cycle, 100MHz)
    initial begin
        axi_clk = 0;
        forever #5 axi_clk = ~axi_clk;
    end
    
    // Reset generation
    initial begin
        axi_resetn = 0;
        repeat (5) @(posedge axi_clk);
        axi_resetn = 1;
    end
    
    // Test data initialization
    initial begin
        // Variable declarations must come first in SystemVerilog
        integer i, j;
        integer burst_length;
        integer data_value;
        integer addr_value;
        integer id_value;
        integer burst_type;
        integer write_data_offset;
        
        // Initialize test pattern arrays
        array_size = 0;
        expected_r_data_index = 0;
        w_burst_count = 0;
        r_burst_count = 0;
        w_data_count = 0;
        r_data_count = 0;
        b_response_count = 0;
        
        // Clear processed arrays
        processed_b_id_array.delete();
        write_complete_array.delete();
        read_started_array.delete();
        
        // Initialize test signals to avoid X values
        axi_ar_addr = 0;
        axi_ar_burst = 0;
        axi_ar_size = 0;
        axi_ar_id = 0;
        axi_ar_len = 0;
        axi_ar_valid = 0;
        axi_r_ready = 1;
        axi_aw_addr = 0;
        axi_aw_burst = 0;
        axi_aw_size = 0;
        axi_aw_id = 0;
        axi_aw_len = 0;
        axi_aw_valid = 0;
        axi_w_data = 0;
        axi_w_last = 0;
        axi_w_strb = 0;
        axi_w_valid = 0;
        axi_b_ready = 1;
        
        // Initialize array indices
        w_array_index = 0;
        r_array_index = 0;
        
        // Initialize other control signals
        test_count = 0;
        current_w_burst_addr = 0;
        current_w_burst_length = 0;
        current_w_burst_id = 0;
        current_w_burst_index = 0;
        current_r_burst_addr = 0;
        current_r_burst_length = 0;
        current_r_burst_id = 0;
        current_r_burst_index = 0;
        w_burst_beat_count = 0;
        w_burst_total_count = 0;
        r_burst_data_count = 0;
        w_burst_queue_index = 0;
        r_burst_queue_index = 0;
        
        // Initialize test state
        test_state = 0;
        next_test_state = 0;
        burst_set_count = 0;
        test_complete = 0;
        
        // Initialize new control signals
        start_write_phase = 0;
        start_read_phase = 0;
        start_simultaneous_phase = 0;
        phase_burst_count = 0;
        phase_complete = 0;
        write_phase_complete = 0;
        read_phase_complete = 0;
        simultaneous_phase_complete = 0;
        
        // Initialize channel control signals
        write_addr_start = 0;
        write_data_start = 0;
        write_resp_start = 0;
        read_addr_start = 0;
        read_data_start = 0;
        
        // Initialize channel completion tracking
        write_addr_complete = 0;
        write_data_complete = 0;
        write_resp_complete = 0;
        read_addr_complete = 0;
        read_data_complete = 0;
        
        // Generate test patterns for 1000 bursts
        for (i = 0; i < TEST_COUNT; i = i + 1) begin
            // Generate random burst parameters
            burst_length = $urandom_range(1, MAX_BURST_LENGTH);
            // Generate sequential addresses to avoid conflicts
            addr_value = i * (MAX_BURST_LENGTH + 1) * (AXI_DATA_WIDTH/8);
            // Ensure address is within memory bounds
            if (addr_value + (burst_length + 1) * (AXI_DATA_WIDTH/8) > MEMORY_SIZE_BYTES) begin
                addr_value = MEMORY_SIZE_BYTES - (burst_length + 1) * (AXI_DATA_WIDTH/8);
            end
            id_value = $urandom_range(0, (1 << AXI_ID_WIDTH) - 1);
            // Set burst type based on burst length: 1=FIXED, 2+=INCR
            burst_type = (burst_length == 1) ? 2'b00 : 2'b01; // 00: FIXED, 01: INCR
            
            // Add burst information to arrays (once per burst)
            test_w_burst_addr_array.push_back(addr_value);
            test_w_burst_length_array.push_back(burst_length);
            test_w_burst_id_array.push_back(id_value);
            test_w_burst_type_array.push_back(burst_type);
            
            // Initialize completion tracking arrays
            write_complete_array.push_back(1'b0);
            read_started_array.push_back(1'b0);
            
            // Generate write test data for all beats in this burst
            // Each beat gets a different data value
            for (j = 0; j <= burst_length; j = j + 1) begin
                data_value = $urandom;  // Generate unique data for each beat
                
                // Add data for each beat
                test_w_data_array.push_back(data_value);
                test_w_last_array.push_back(j == burst_length);
                test_w_strb_array.push_back(4'b1111); // All bytes enabled
            end
            
            // Generate read test data (same address and length)
            test_r_addr_array.push_back(addr_value);
            test_r_length_array.push_back(burst_length);
            test_r_id_array.push_back(id_value);
            test_r_burst_array.push_back(burst_type);
            
            array_size = array_size + 1;
        end
        
        // Generate expected read data array based on WRITE order (not read order)
        // This ensures the expected data matches the actual data written to memory
        write_data_offset = 0;
        for (i = 0; i < array_size; i = i + 1) begin
            burst_length = test_w_burst_length_array[i];  // Use write burst length
            // For each write burst, add expected data based on write data
            for (j = 0; j <= burst_length; j = j + 1) begin
                // Calculate the correct index in write data array
                expected_r_data_array.push_back(test_w_data_array[write_data_offset + j]);
                expected_r_id_array.push_back(test_w_burst_id_array[i]);  // Use write burst ID
            end
            // Update offset for next burst
            write_data_offset = write_data_offset + burst_length + 1;
        end
        
        // Generate expected write response array in the same order as write bursts
        for (i = 0; i < array_size; i = i + 1) begin
            expected_b_id_array.push_back(test_w_burst_id_array[i]);
        end
        
        $display("Test pattern generation completed. Total bursts: %0d", array_size);
        $display("Memory size: %0d bytes, Data width: %0d bits", MEMORY_SIZE_BYTES, AXI_DATA_WIDTH);
        $display("Address width: %0d bits, ID width: %0d bits", AXI_ADDR_WIDTH, AXI_ID_WIDTH);
        $display("Expected read data array size: %0d", expected_r_data_array.size());
        $display("Expected read ID array size: %0d", expected_r_id_array.size());
        $display("Expected write response array size: %0d", expected_b_id_array.size());
        $display("Address generation: sequential from 0, max burst length: %0d", MAX_BURST_LENGTH);
        $display("DEBUG: First few expected data values:");
        for (i = 0; i < 5 && i < expected_r_data_array.size(); i = i + 1) begin
            $display("  Index %0d: Data=%h, ID=%h", i, expected_r_data_array[i], expected_r_id_array[i]);
        end
        
        // Additional debug: Show the relationship between write and expected data
        $display("DEBUG: Write data vs Expected read data relationship:");
        write_data_offset = 0;
        for (i = 0; i < 3 && i < array_size; i = i + 1) begin
            burst_length = test_w_burst_length_array[i];
            $display("  Write Burst %0d: Length=%0d, ID=%h", 
                     i, burst_length, test_w_burst_id_array[i]);
            
            // Show first few beats of each burst
            for (j = 0; j <= burst_length && j < 4; j = j + 1) begin
                $display("    Beat %0d: Write=%h, Expected=%h", 
                         j, test_w_data_array[write_data_offset + j], expected_r_data_array[write_data_offset + j]);
            end
            if (burst_length >= 4) begin
                $display("    ... (showing first 4 beats)");
            end
            write_data_offset = write_data_offset + burst_length + 1;
        end
        
        // Test execution will start automatically in the always block
        // test_state is initialized to 0, and the always block will handle state transitions
    end
    
    // Function to check if all write bursts are complete
    function automatic integer all_writes_complete();
        integer i;
        all_writes_complete = 1;
        for (i = 0; i < array_size; i = i + 1) begin
            if (!write_complete_array[i]) begin
                all_writes_complete = 0;
                break;
            end
        end
    endfunction
    
    // Function to check if all write bursts have been started
    function automatic integer all_writes_started();
        all_writes_started = (w_array_index >= array_size);
    endfunction
    
    // Test execution control - manages phases and channel execution
    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            // Reset state
            test_state <= 0;
            start_write_phase <= 0;
            start_read_phase <= 0;
            start_simultaneous_phase <= 0;
            phase_burst_count <= 0;
        end else begin
            case (test_state)
                0: begin
                    // Wait for initialization to complete, then start test
                    if (array_size > 0) begin
                        test_state <= 1;
                        $display("DEBUG: Test execution started, moving to state 1");
                    end
                end
                
                1: begin
                    // Phase 1: Execute 2 write bursts only
                    if (!start_write_phase) begin
                        start_write_phase <= 1;
                        phase_burst_count <= 2;
                        // Preserve read burst indices from previous phases
                        $display("DEBUG: State 1 - Starting write phase with %0d bursts, current_r_burst_index=%0d", 2, current_r_burst_index);
                    end else if (write_phase_complete) begin
                        start_write_phase <= 0;
                        write_phase_complete <= 0;
                        test_state <= 2;
                        $display("DEBUG: State 1 - Write phase completed, moving to state 2");
                    end
                end
                
                2: begin
                    // Phase 2: Execute 2 read bursts only
                    if (!start_read_phase) begin
                        start_read_phase <= 1;
                        phase_burst_count <= 2;
                        // Continue read burst index from previous phase instead of resetting
                        $display("DEBUG: State 2 - Starting read phase with %0d bursts, continuing read burst index from %0d", 2, current_r_burst_index);
                    end else if (read_phase_complete) begin
                        start_read_phase <= 0;
                        read_phase_complete <= 0;
                        test_state <= 3;
                        $display("DEBUG: State 2 - Read phase completed, moving to state 3");
                    end
                end
                
                3: begin
                    // Phase 3: Execute 2 writes + 2 reads simultaneously
                    if (!start_simultaneous_phase) begin
                        start_simultaneous_phase <= 1;
                        phase_burst_count <= 2;
                        // Continue read burst index from previous phase instead of resetting
                        // current_r_burst_index should continue from where Phase 2 left off
                        $display("DEBUG: State 3 - Starting simultaneous phase with %0d bursts, continuing read burst index from %0d", 2, current_r_burst_index);
                    end else if (simultaneous_phase_complete) begin
                        start_simultaneous_phase <= 0;
                        simultaneous_phase_complete <= 0;
                        test_state <= 4;
                        $display("DEBUG: State 3 - Simultaneous phase completed, moving to state 4");
                    end
                end
                
                4: begin
                    // Check if all bursts have been processed
                    if (w_array_index >= array_size && r_array_index >= array_size) begin
                        // All bursts processed, wait for completion
                        if (w_data_count >= array_size && r_data_count >= array_size && b_response_count >= array_size) begin
                            test_state <= 5;
                        end
                    end else begin
                        // Continue with next phase
                        // Don't reset read burst indices - continue from current state
                        $display("DEBUG: State 4 - Continuing with next phase, w_array_index=%0d, r_array_index=%0d, current_r_burst_index=%0d", 
                                 w_array_index, r_array_index, current_r_burst_index);
                        test_state <= 1;
                    end
                end
                
                5: begin
                    // Test verification and completion
                    $display("Test execution completed.");
                    $display("Write bursts: %0d, Read bursts: %0d", w_burst_count, r_burst_count);
                    $display("Write data: %0d, Read data: %0d, Write responses: %0d", w_data_count, r_data_count, b_response_count);
                    test_complete <= 1'b1;
                    $finish;
                end
            endcase
        end
    end
    
    // Phase completion monitoring
    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            write_phase_complete <= 0;
            read_phase_complete <= 0;
            simultaneous_phase_complete <= 0;
        end else begin
            // Monitor write phase completion
            if (start_write_phase && !write_phase_complete) begin
                if (write_addr_complete && write_data_complete && write_resp_complete) begin
                    write_phase_complete <= 1;
                    $display("DEBUG: Write phase completed - Addr: %b, Data: %b, Resp: %b", 
                             write_addr_complete, write_data_complete, write_resp_complete);
                    $display("DEBUG: Write phase - Started bursts: %0d, Completed bursts: %0d, Responses: %0d", 
                             w_array_index, current_w_burst_index, b_response_count);
                end
            end
            
            // Monitor read phase completion
            if (start_read_phase && !read_phase_complete) begin
                if (read_addr_complete && read_data_complete) begin
                    read_phase_complete <= 1;
                    $display("DEBUG: Read phase completed - Addr: %b, Data: %b", 
                             read_addr_complete, read_data_complete);
                    $display("DEBUG: Read phase - Started bursts: %0d, Completed bursts: %0d, Data beats: %0d", 
                             r_array_index, current_r_burst_index, r_data_count);
                end
            end
            
            // Monitor simultaneous phase completion
            if (start_simultaneous_phase && !simultaneous_phase_complete) begin
                if (write_addr_complete && write_data_complete && write_resp_complete && 
                    read_addr_complete && read_data_complete) begin
                    simultaneous_phase_complete <= 1;
                    $display("DEBUG: Simultaneous phase completed - Write: %b,%b,%b, Read: %b,%b", 
                             write_addr_complete, write_data_complete, write_resp_complete,
                             read_addr_complete, read_data_complete);
                    $display("DEBUG: Simultaneous phase - Write bursts: %0d/%0d, Read bursts: %0d/%0d", 
                             current_w_burst_index, w_array_index, current_r_burst_index, r_array_index);
                end
            end
        end
    end
    
    // Write Address Channel Management
    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            axi_aw_valid <= 0;
            write_addr_complete <= 0;
        end else if (start_write_phase || start_simultaneous_phase) begin
            if (!write_addr_complete && w_array_index < array_size) begin
                // Start write address transaction
                axi_aw_addr <= test_w_burst_addr_array[w_array_index];
                axi_aw_burst <= test_w_burst_type_array[w_array_index];
                axi_aw_size <= $clog2(AXI_DATA_WIDTH/8);
                axi_aw_id <= test_w_burst_id_array[w_array_index];
                axi_aw_len <= test_w_burst_length_array[w_array_index];
                axi_aw_valid <= 1'b1;
                
                $display("DEBUG: Write Address - Started burst %0d, ID: %h, Length: %0d", 
                         w_array_index, test_w_burst_id_array[w_array_index], test_w_burst_length_array[w_array_index]);
                
                // Wait for handshake
                if (axi_aw_ready && axi_aw_valid) begin
                    axi_aw_valid <= 0;
                    w_array_index <= w_array_index + 1;
                    
                    // Check if we've started enough bursts for this phase
                    if (w_array_index >= array_size || (start_write_phase && (w_array_index + 1) % phase_burst_count == 0)) begin
                        write_addr_complete <= 1;
                        $display("DEBUG: Write Address - Phase complete, started %0d bursts", w_array_index + 1);
                    end
                end
            end
        end else begin
            // Reset completion flag when phase ends
            write_addr_complete <= 0;
        end
    end
    
    // Write Data Channel Management
    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            axi_w_valid <= 0;
            axi_w_last <= 0;
            write_data_complete <= 0;
            w_burst_beat_count <= 0;
            w_burst_total_count <= 0;
            current_w_burst_index <= 0;
        end else if (start_write_phase || start_simultaneous_phase) begin
            if (!write_data_complete && w_burst_beat_count <= w_burst_total_count) begin
            // Generate write data beats
                if (axi_w_ready && w_burst_beat_count <= w_burst_total_count) begin
                    // Calculate data index
                integer write_data_index;
                integer offset;
                integer k;
                
                write_data_index = 0;
                offset = 0;
                
                    // Calculate offset for this burst
                for (k = 0; k < current_w_burst_index; k = k + 1) begin
                    offset = offset + test_w_burst_length_array[k] + 1;
                end
                write_data_index = offset + w_burst_beat_count;
                    
                    // Verify data index is within bounds
                    if (write_data_index >= test_w_data_array.size()) begin
                        $display("ERROR: Write data index %0d out of bounds (array size: %0d) at time %0t", 
                                 write_data_index, test_w_data_array.size(), $time);
                        $finish;
                    end
                
                axi_w_data <= test_w_data_array[write_data_index];
                    axi_w_last <= (w_burst_beat_count == w_burst_total_count);
                axi_w_strb <= 4'b1111;
                axi_w_valid <= 1'b1;
                
                    $display("DEBUG: Write Data - ID: %h, Burst Index: %0d, Beat: %0d/%0d, Data: %h", 
                             test_w_burst_id_array[current_w_burst_index], current_w_burst_index, 
                             w_burst_beat_count, w_burst_total_count, test_w_data_array[write_data_index]);
                
                // Update beat counter when handshake completes
                if (axi_w_ready && axi_w_valid) begin
                    w_burst_beat_count <= w_burst_beat_count + 1;
                        
                    if (axi_w_last) begin
                        w_burst_count <= w_burst_count + 1;
                            w_burst_beat_count <= 0;
                            $display("INFO: Write burst completed at time %0t, burst #%0d, ID: %h", 
                                     $time, w_burst_count + 1, test_w_burst_id_array[current_w_burst_index]);
                            
                            // Mark write completion
                            write_complete_array[current_w_burst_index] = 1'b1;
                            
                            // Move to next burst
                            current_w_burst_index <= current_w_burst_index + 1;
                            
                            // Check if we've completed enough bursts for this phase
                            if (current_w_burst_index >= array_size || 
                                (start_write_phase && (current_w_burst_index + 1) % phase_burst_count == 0)) begin
                                write_data_complete <= 1;
                                $display("DEBUG: Write Data - Phase complete, completed %0d bursts", current_w_burst_index + 1);
                            end
                        end
                    end
                end
            end
        end else begin
            // Reset completion flag when phase ends
            write_data_complete <= 0;
        end
    end
    
    // Write Response Channel Management
    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            write_resp_complete <= 0;
        end else if (start_write_phase || start_simultaneous_phase) begin
            if (!write_resp_complete && axi_b_valid && axi_b_ready) begin
                // Process write response
                integer current_burst_num;
                integer found_index;
                integer i;
                integer already_processed;
                
                current_burst_num = b_response_count + 1;
                
                $display("INFO: Write response received at time %0t, burst #%0d", $time, current_burst_num);
                $display("  Response ID: %h, Response: %b", axi_b_id, axi_b_resp);
                
                // Check if this ID has already been processed
                already_processed = 0;
                for (i = 0; i < processed_b_id_array.size(); i = i + 1) begin
                    if (processed_b_id_array[i] === axi_b_id) begin
                        already_processed = 1;
                        break;
                    end
                end
                
                if (already_processed) begin
                    $display("FAIL: Write response ID %h already processed at time %0t, burst #%0d", axi_b_id, $time, current_burst_num);
                    $finish;
                end
                
                // Verify write response ID
                found_index = -1;
                for (i = 0; i < expected_b_id_array.size(); i = i + 1) begin
                    if (expected_b_id_array[i] === axi_b_id) begin
                        found_index = i;
                        break;
                    end
                end
                
                if (found_index === -1) begin
                    $display("FAIL: Write response ID %h not found in expected array at time %0t, burst #%0d", axi_b_id, $time, current_burst_num);
                    $finish;
                end
                
                // Mark this ID as processed
                processed_b_id_array.push_back(axi_b_id);
                
                if (axi_b_resp !== 2'b00) begin
                    $display("FAIL: Write response not OKAY at time %0t, burst #%0d, index %0d", $time, current_burst_num, found_index);
                    $finish;
                end
                
                $display("PASS: Write response verification at time %0t, burst #%0d, ID: %h", $time, current_burst_num, axi_b_id);
                
                b_response_count <= b_response_count + 1;
                
                // Check if we've received enough responses for this phase
                if (b_response_count >= array_size || 
                    (start_write_phase && b_response_count % phase_burst_count == 0)) begin
                    write_resp_complete <= 1;
                    $display("DEBUG: Write Response - Phase complete, received %0d responses", b_response_count + 1);
                end
            end
        end else begin
            // Reset completion flag when phase ends
            write_resp_complete <= 0;
        end
    end
    
    // Read Address Channel Management
    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            axi_ar_valid <= 0;
            read_addr_complete <= 0;
        end else if (start_read_phase || start_simultaneous_phase) begin
            if (!read_addr_complete && r_array_index < array_size) begin
                // Start read address transaction
                // Use the same address as the corresponding write burst
                axi_ar_addr <= test_r_addr_array[r_array_index];
                axi_ar_burst <= test_r_burst_array[r_array_index];
                axi_ar_size <= $clog2(AXI_DATA_WIDTH/8);
                axi_ar_id <= test_r_id_array[r_array_index];
                axi_ar_len <= test_r_length_array[r_array_index];
                axi_ar_valid <= 1'b1;
                
                $display("DEBUG: Read Address - Started burst %0d, ID: %h, Length: %0d, Addr: %h", 
                         r_array_index, test_r_id_array[r_array_index], test_r_length_array[r_array_index], test_r_addr_array[r_array_index]);
                
                // Wait for handshake
                if (axi_ar_ready && axi_ar_valid) begin
                    axi_ar_valid <= 0;
                    
                    // Update current_r_burst_index when starting a new read burst
                    // This should match the r_array_index for proper tracking
                    current_r_burst_index <= r_array_index;
                    $display("DEBUG: Read Address - Updated current_r_burst_index to %0d for burst %0d", r_array_index, r_array_index);
                    
                    r_array_index <= r_array_index + 1;
                    
                    // Check if we've started enough bursts for this phase
                    if (r_array_index >= array_size || (start_read_phase && (r_array_index + 1) % phase_burst_count == 0)) begin
                        read_addr_complete <= 1;
                        $display("DEBUG: Read Address - Phase complete, started %0d bursts", r_array_index + 1);
                    end
                end
            end
        end else begin
            // Reset completion flag when phase ends
            read_addr_complete <= 0;
        end
    end
    
    // Read Data Channel Management
    always @(posedge axi_clk) begin
        // Variable declarations must come first in SystemVerilog
        integer current_read_burst_num;
        integer expected_data_index;
        integer burst_offset;
        integer k;
        
        if (!axi_resetn) begin
            axi_r_ready <= 1'b1; // Ensure ready is high when reset
            read_data_complete <= 0;
            r_burst_data_count <= 0;
            current_r_burst_index <= 0;
        end else if (start_read_phase || start_simultaneous_phase) begin
            if (!read_data_complete && axi_r_valid && axi_r_ready) begin
                // Process read data
                current_read_burst_num = current_r_burst_index;
                
                // Calculate the expected data index based on read burst order
                // We need to map read burst index to the corresponding write data
                expected_data_index = 0;
                burst_offset = 0;
                
                // Find the corresponding write burst for this read burst
                // Each read burst corresponds to a write burst with the same index
                for (k = 0; k < current_read_burst_num; k = k + 1) begin
                    burst_offset = burst_offset + test_w_burst_length_array[k] + 1;
                end
                
                // Add the current beat within the burst
                expected_data_index = burst_offset + r_burst_data_count;
                
                $display("INFO: Read data received at time %0t, burst #%0d, index %0d", $time, current_read_burst_num, expected_data_index);
                $display("  Data: %h, ID: %h, Last: %b", axi_r_data, axi_r_id, axi_r_last);
                $display("  DEBUG: Expected data index: %0d, Burst offset: %0d, Beat count: %0d, Current burst index: %0d", 
                         expected_data_index, burst_offset, r_burst_data_count, current_read_burst_num);
                
                // Verify read data using the calculated expected data index
                if (expected_data_index >= expected_r_data_array.size()) begin
                    $display("ERROR: Expected data index %0d out of bounds (array size: %0d) at time %0t", 
                             expected_data_index, expected_r_data_array.size(), $time);
                    $display("  Current read burst: %0d, Burst offset: %0d, Beat count: %0d", 
                             current_read_burst_num, burst_offset, r_burst_data_count);
                    $finish;
                end
                
                if (axi_r_data !== expected_r_data_array[expected_data_index]) begin
                    $display("FAIL: Read data mismatch at time %0t, burst #%0d, index %0d", $time, current_read_burst_num, expected_data_index);
                    $display("Expected: %h, Got: %h", expected_r_data_array[expected_data_index], axi_r_data);
                    $display("DEBUG: Expected data index: %0d, Array sizes - expected_r_data: %0d, expected_r_id: %0d", 
                             expected_data_index, expected_r_data_array.size(), expected_r_id_array.size());
                    $display("DEBUG: Current indices - expected_r_data_index: %0d, r_data_count: %0d", expected_data_index, r_data_count);
                    $finish;
                end
                
                if (axi_r_id !== expected_r_id_array[expected_data_index]) begin
                    $display("FAIL: Read ID mismatch at time %0t, burst #%0d, index %0d", $time, current_read_burst_num, expected_data_index);
                    $display("Expected: %h, Got: %h", expected_r_id_array[expected_data_index], axi_r_id);
                    $finish;
                end
                
                $display("PASS: Read data verification at time %0t, burst #%0d, index %0d", $time, current_read_burst_num, expected_data_index);
                
                expected_r_data_index <= expected_data_index + 1;
                r_data_count <= r_data_count + 1;
                
                if (axi_r_last) begin
                    r_burst_count <= r_burst_count + 1;
                    // Move to next burst only when current burst is complete
                    current_r_burst_index <= current_r_burst_index + 1;
                    r_burst_data_count <= 0; // Reset beat count for next burst
                    $display("INFO: Read burst completed at time %0t, burst #%0d, moving to burst #%0d", 
                             $time, r_burst_count + 1, current_r_burst_index + 1);
                end else begin
                    r_burst_data_count <= r_burst_data_count + 1; // Increment beat count within burst
                end
                
                // Check if we've received enough data for this phase
                // For simultaneous phase, we need to track both read and write completion
                if (start_read_phase) begin
                    // Read-only phase: complete when we've received enough data beats
                    if (r_data_count >= array_size || r_data_count % phase_burst_count == 0) begin
                        read_data_complete <= 1;
                        $display("DEBUG: Read Data - Phase complete, received %0d data beats", r_data_count + 1);
                    end
                end else if (start_simultaneous_phase) begin
                    // Simultaneous phase: complete when we've received enough data beats for this phase
                    // Calculate how many data beats we expect for the current phase
                    integer expected_beats;
                    integer phase_start_burst;
                    integer i;
                    
                    expected_beats = 0;
                    phase_start_burst = current_r_burst_index;
                    
                    // Calculate expected beats for the current phase
                    for (i = 0; i < phase_burst_count && (phase_start_burst + i) < array_size; i = i + 1) begin
                        expected_beats = expected_beats + test_r_length_array[phase_start_burst + i] + 1;
                    end
                    
                    if (r_data_count >= array_size || r_burst_data_count >= expected_beats) begin
                        read_data_complete <= 1;
                        $display("DEBUG: Read Data - Simultaneous phase complete, received %0d data beats, expected %0d", 
                                 r_burst_data_count + 1, expected_beats);
                    end
                end
            end
        end else begin
            // Reset completion flag when phase ends
            read_data_complete <= 0;
        end
    end
    
    // Payload validation (check for X values)
    always @(posedge axi_clk) begin
        if (axi_resetn) begin
            // Check read data channel
            if (axi_r_valid && (axi_r_data === 'bx || axi_r_id === 'bx || axi_r_resp === 'bx || axi_r_last === 'bx)) begin
                $display("ERROR: X value detected in read data channel at time %0t", $time);
                $display("Data: %h, ID: %h, Resp: %b, Last: %b", axi_r_data, axi_r_id, axi_r_resp, axi_r_last);
                $finish;
            end
            
            // Check write response channel
            if (axi_b_valid && (axi_b_id === 'bx || axi_b_resp === 'bx)) begin
                $display("ERROR: X value detected in write response channel at time %0t", $time);
                $display("Response: %b", axi_b_id, axi_b_resp);
                $finish;
            end
        end
    end
    
    // Stall test (insert random stalls)
    always @(posedge axi_clk) begin
        if (axi_resetn && !test_complete) begin
            // Randomly insert stalls
            if ($urandom_range(0, 99) < 10) begin // 10% chance of stall
                axi_r_ready <= 1'b0;
                axi_b_ready <= 1'b0;
                repeat($urandom_range(1, STALL_N)) @(posedge axi_clk);
                axi_r_ready <= 1'b1;
                axi_b_ready <= 1'b1;
            end
        end
    end
    
    // Test timeout
    initial begin
        repeat(100000) @(posedge axi_clk); // 100,000 cycles timeout
        $display("ERROR: Test timeout at time %0t", $time);
        $finish;
    end

endmodule
