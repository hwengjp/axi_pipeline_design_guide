// AXI4 Simple Dual Port RAM Testbench
// Generated from part08_axi4_bus_testbench_abstraction.md
// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.

`timescale 1ns/1ps

module axi_simple_dual_port_ram_tb;

// Include split function files
`include "axi_common_defs.svh"
`include "axi_stimulus_functions.svh"
`include "axi_verification_functions.svh"
`include "axi_utility_functions.svh"
`include "axi_random_generation.svh"
`include "axi_monitoring_functions.svh"


// Clock and Reset
reg clk;
reg rst_n;

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz clock
end

// Reset generation
initial begin
    rst_n = 0;
    repeat(10) @(posedge clk);
    #1;
    rst_n = 1;
end

// Testbench parameters
     // 32MB
              // 32bit
                 // 8bit ID
          // Total test count
           // Tests per phase
//          // Total test count
//           // Tests per phase
 // Address size per test count
                  // 10ns period
             // 5ns half period
                // Reset cycles

// Derived parameters



// AXI4 Write Address Channel
logic [AXI_ADDR_WIDTH-1:0] axi_aw_addr;
logic [1:0]                axi_aw_burst;
logic [2:0]                axi_aw_size;
logic [AXI_ID_WIDTH-1:0]   axi_aw_id;
logic [7:0]                axi_aw_len;
logic                      axi_aw_valid;
wire                       axi_aw_ready;

// AXI4 Write Data Channel
logic [AXI_DATA_WIDTH-1:0] axi_w_data;
logic [AXI_STRB_WIDTH-1:0] axi_w_strb;
logic                       axi_w_last;
logic                       axi_w_valid;
wire                       axi_w_ready;

// AXI4 Write Response Channel
wire [1:0]                axi_b_resp;
wire [AXI_ID_WIDTH-1:0]   axi_b_id;
wire                       axi_b_valid;
logic                      axi_b_ready;

// AXI4 Read Address Channel
logic [AXI_ADDR_WIDTH-1:0] axi_ar_addr;
logic [1:0]                axi_ar_burst;
logic [2:0]                axi_ar_size;
logic [AXI_ID_WIDTH-1:0]   axi_ar_id;
logic [7:0]                axi_ar_len;
logic                      axi_ar_valid;
wire                       axi_ar_ready;

// AXI4 Read Data Channel
wire [AXI_DATA_WIDTH-1:0] axi_r_data;
wire [AXI_ID_WIDTH-1:0]   axi_r_id;
wire [1:0]                axi_r_resp;
wire                       axi_r_last;
wire                       axi_r_valid;
logic                      axi_r_ready;

// Test data generation completion flag


// Test execution completion flag


// Ready negate control parameters
  // Length of ready negate pulse array

// Ready negate pulse arrays for TB controlled channels
// (moved to axi_common_defs.svh)

// Weighted random generation structures
// (moved to axi_common_defs.svh)

// Weighted random generation arrays
// (moved to axi_common_defs.svh)

// Payload structures
// (moved to axi_common_defs.svh)

// Payload arrays
// (moved to axi_common_defs.svh)

// Expected value structures
// (moved to axi_common_defs.svh)

// Expected value arrays
// (moved to axi_common_defs.svh)

// Phase control signals
// (moved to axi_common_defs.svh)





  // Clear signal for phase completion latches

// Phase completion signals






// Phase completion signal latches






// Log control parameters



// Test data generation functions
















// (extract_weights_generic removed to avoid returning int[] which some tools reject)

// Direct bubble weight helper functions (avoid packed arrays)






// Helper functions
















// Weighted random generation functions




// Ready negate pulse array initialization function


// Log output functions




// Array display functions


















// DUT instantiation
axi_simple_dual_port_ram #(
    .MEMORY_SIZE_BYTES(MEMORY_SIZE_BYTES),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH)
) dut (
    .axi_clk(clk),
    .axi_resetn(rst_n),
    .axi_aw_addr(axi_aw_addr),
    .axi_aw_burst(axi_aw_burst),
    .axi_aw_size(axi_aw_size),
    .axi_aw_id(axi_aw_id),
    .axi_aw_len(axi_aw_len),
    .axi_aw_valid(axi_aw_valid),
    .axi_aw_ready(axi_aw_ready),
    .axi_w_data(axi_w_data),
    .axi_w_last(axi_w_last),
    .axi_w_strb(axi_w_strb),
    .axi_w_valid(axi_w_valid),
    .axi_w_ready(axi_w_ready),
    .axi_b_resp(axi_b_resp),
    .axi_b_id(axi_b_id),
    .axi_b_valid(axi_b_valid),
    .axi_b_ready(axi_b_ready),
    .axi_ar_addr(axi_ar_addr),
    .axi_ar_burst(axi_ar_burst),
    .axi_ar_size(axi_ar_size),
    .axi_ar_id(axi_ar_id),
    .axi_ar_len(axi_ar_len),
    .axi_ar_valid(axi_ar_valid),
    .axi_ar_ready(axi_ar_ready),
    .axi_r_data(axi_r_data),
    .axi_r_id(axi_r_id),
    .axi_r_resp(axi_r_resp),
    .axi_r_last(axi_r_last),
    .axi_r_valid(axi_r_valid),
    .axi_r_ready(axi_r_ready)
);


// Time 0 payload and expected value generation
initial begin
    // Generate Write Address Channel payloads
    generate_write_addr_payloads();
    generate_write_addr_payloads_with_stall();
    
    // Generate Write Data Channel payloads
    generate_write_data_payloads();
    generate_write_data_payloads_with_stall();
    
    // Generate Read Address Channel payloads
    generate_read_addr_payloads();
    generate_read_addr_payloads_with_stall();
    
    // Generate Read Data Channel expected values
    generate_read_data_expected();
    
    // Generate Write Response Channel expected values
    generate_write_resp_expected();
    
    // Initialize ready negate pulse arrays
    initialize_ready_negate_pulses();
    
    $display("Payloads and Expected Values Generated:");
    $display("  Write Address - Basic: %0d, Stall: %0d", 
             write_addr_payloads.size(), write_addr_payloads_with_stall.size());
    $display("  Write Data - Basic: %0d, Stall: %0d", 
             write_data_payloads.size(), write_data_payloads_with_stall.size());
    $display("  Read Address - Basic: %0d, Stall: %0d", 
             read_addr_payloads.size(), read_addr_payloads_with_stall.size());
    $display("  Read Data Expected - %0d", read_data_expected.size());
    $display("  Write Response Expected - %0d", write_resp_expected.size());
    
    // Display all generated arrays
    display_all_arrays();
    
    // Display array size verification
    write_debug_log($sformatf("Array Size Verification:"));
    write_debug_log($sformatf("  Write Address Payloads: %0d", write_addr_payloads.size()));
    write_debug_log($sformatf("  Write Data Payloads: %0d (should match total burst transfers)", write_data_payloads.size()));
    write_debug_log($sformatf("  Read Address Payloads: %0d", read_addr_payloads.size()));
    write_debug_log($sformatf("  Read Data Expected: %0d (should match write data count)", read_data_expected.size()));
    write_debug_log($sformatf("  Write Response Expected: %0d", write_resp_expected.size()));
    
    // Set completion flag
    #1;
    generate_stimulus_expected_done = 1'b1;
end

// Test scenario control
initial begin
    
    // Initialize
    current_phase = 8'd0;
    write_addr_phase_start = 1'b0;
    read_addr_phase_start = 1'b0;
    write_data_phase_start = 1'b0;
    read_data_phase_start = 1'b0;
    
    // Wait for stimulus generation completion
    wait(generate_stimulus_expected_done);
    $display("Phase %0d: Stimulus and Expected Values Generation Confirmed", current_phase);
    
    // Wait for reset deassertion
    wait(rst_n);
    $display("Phase %0d: Reset Deassertion Confirmed", current_phase);
    
    // Start first phase
    repeat(2) @(posedge clk);
    #1;
    write_addr_phase_start = 1'b1;
    write_data_phase_start = 1'b1;
    write_resp_phase_start = 1'b1;
    
    @(posedge clk);
    #1;
    write_addr_phase_start = 1'b0;
    write_data_phase_start = 1'b0;
    write_resp_phase_start = 1'b0;
    
    // Wait for first phase completion
    wait(write_addr_phase_done_latched && write_data_phase_done_latched && write_resp_phase_done_latched);
    
    $display("Phase %0d: All Channels Completed", current_phase);
    
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b1;  // Assert clear signal
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b0;  // Deassert clear signal
        
    current_phase = current_phase + 8'd1;
    
    // Phase control loop
    for (int phase = 0; phase < (TOTAL_TEST_COUNT / PHASE_TEST_COUNT) - 1; phase++) begin
        @(posedge clk);
        #1;
        // Start all channels
        write_addr_phase_start = 1'b1;
        read_addr_phase_start = 1'b1;
        write_data_phase_start = 1'b1;
        write_resp_phase_start = 1'b1;
        read_data_phase_start = 1'b1;
        
        @(posedge clk);
        #1;
        write_addr_phase_start = 1'b0;
        read_addr_phase_start = 1'b0;
        write_data_phase_start = 1'b0;
        write_resp_phase_start = 1'b0;
        read_data_phase_start = 1'b0;
        
        // Wait for all channels completion
        wait(write_addr_phase_done_latched && read_addr_phase_done_latched && 
             write_data_phase_done_latched && write_resp_phase_done_latched && read_data_phase_done_latched);
        
        $display("Phase %0d: All Channels Completed", current_phase);
        
        @(posedge clk);
        #1;
        clear_phase_latches = 1'b1;  // Assert clear signal
        @(posedge clk);
        #1;
        clear_phase_latches = 1'b0;  // Deassert clear signal
        
        current_phase = current_phase + 8'd1;
    end
    
    // Final phase
    @(posedge clk);
    #1;
    read_addr_phase_start = 1'b1;
    read_data_phase_start = 1'b1;
    
    @(posedge clk);
    #1;
    read_addr_phase_start = 1'b0;
    read_data_phase_start = 1'b0;
    
    // Wait for final phase completion
    wait(read_addr_phase_done_latched && read_data_phase_done_latched);
    
    $display("Phase %0d: All Channels Completed", current_phase);
    
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b1;  // Assert clear signal
    @(posedge clk);
    #1;
    clear_phase_latches = 1'b0;  // Deassert clear signal
        
        // All phases completed
    $display("All Phases Completed. Test Scenario Finished.");
    test_execution_completed = 1'b1;  // Set test completion flag
    #1 // Wait for test completion log to be written
    $finish;
end

// Phase completion signal latches
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_addr_phase_done_latched <= 1'b0;
        read_addr_phase_done_latched <= 1'b0;
        write_data_phase_done_latched <= 1'b0;
        read_data_phase_done_latched <= 1'b0;
    end else if (clear_phase_latches) begin
        // Clear latched signals when clear signal is asserted
        write_addr_phase_done_latched <= 1'b0;
        read_addr_phase_done_latched <= 1'b0;
        write_data_phase_done_latched <= 1'b0;
        write_resp_phase_done_latched <= 1'b0;
        read_data_phase_done_latched <= 1'b0;
    end else begin
        if (write_addr_phase_done) write_addr_phase_done_latched <= 1'b1;
        if (read_addr_phase_done) read_addr_phase_done_latched <= 1'b1;
        if (write_data_phase_done) write_data_phase_done_latched <= 1'b1;
        if (write_resp_phase_done) write_resp_phase_done_latched <= 1'b1;
        if (read_data_phase_done) read_data_phase_done_latched <= 1'b1;
    end
end

// Write Address Channel Control Circuit
typedef enum logic [1:0] {
    WRITE_ADDR_IDLE,        // 待機状態
    WRITE_ADDR_ACTIVE,      // アクティブ状態（ストール処理も含む）
    WRITE_ADDR_FINISH       // 終了処理状態
} write_addr_state_t;

write_addr_state_t write_addr_state = WRITE_ADDR_IDLE;
logic [7:0] write_addr_phase_counter = 8'd0;
logic write_addr_phase_busy = 1'b0;
int write_addr_array_index = 0;

// Write Address Channel Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_addr_state <= WRITE_ADDR_IDLE;
        write_addr_phase_counter <= 8'd0;
        write_addr_phase_busy <= 1'b0;
        write_addr_phase_done <= 1'b0;
        write_addr_array_index <= 0;
        
        // AXI4 signals
        axi_aw_addr <= '0;
        axi_aw_burst <= '0;
        axi_aw_size <= '0;
        axi_aw_id <= '0;
        axi_aw_len <= '0;
        axi_aw_valid <= 1'b0;
    end else begin
        case (write_addr_state)
            WRITE_ADDR_IDLE: begin
                if (write_addr_phase_start) begin
                    write_addr_state <= WRITE_ADDR_ACTIVE;
                    write_addr_phase_busy <= 1'b1;
                    write_addr_phase_counter <= 8'd0;
                    // write_addr_array_index <= 0;  // 削除: クリアしない
                    write_addr_phase_done <= 1'b0;
                end
            end
            
            WRITE_ADDR_ACTIVE: begin
                // 最優先: Ready信号の判定
                if (axi_aw_ready) begin
                    // 配列の範囲チェック
                    if (write_addr_array_index < write_addr_payloads_with_stall.size()) begin
                        // ペイロードの取得
                        automatic write_addr_payload_t payload = write_addr_payloads_with_stall[write_addr_array_index];
                        
                      
                        // アドレス送信完了の判定（axi_aw_validの時）
                        if (axi_aw_valid) begin
                            // 現在のカウンター値でPhase完了判定
                            if (write_addr_phase_counter < PHASE_TEST_COUNT - 1) begin
                                axi_aw_addr <= payload.addr;
                                axi_aw_burst <= payload.burst;
                                axi_aw_size <= payload.size;
                                axi_aw_id <= payload.id;
                                axi_aw_len <= payload.len;
                                axi_aw_valid <= payload.valid;

                                // Debug output
                                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                    write_debug_log($sformatf("Write Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                        write_addr_array_index, payload.test_count, payload.addr, payload.burst, 
                                        payload.size, payload.id, payload.len, payload.valid));
                                end

                                // 配列インデックスを更新
                                write_addr_array_index <= write_addr_array_index + 1;

                                // Phase継続: カウンターを増加
                                write_addr_phase_counter <= write_addr_phase_counter + 8'd1;
                                write_debug_log($sformatf("Write Addr Phase: Address sent, counter=%0d/%0d", 
                                    write_addr_phase_counter + 1, PHASE_TEST_COUNT));
                            end else begin
                                // Phase完了: 全信号をクリア
                                axi_aw_addr <= '0;
                                axi_aw_burst <= '0;
                                axi_aw_size <= '0;
                                axi_aw_id <= '0;
                                axi_aw_len <= '0;
                                axi_aw_valid <= 1'b0;
                                
                                // 状態遷移
                                write_addr_state <= WRITE_ADDR_FINISH;
                                write_addr_phase_done <= 1'b1;
                                
                                write_debug_log("Write Addr Phase: Phase completed, all signals cleared");
                            end
                        end else begin
                            axi_aw_addr <= payload.addr;
                            axi_aw_burst <= payload.burst;
                            axi_aw_size <= payload.size;
                            axi_aw_id <= payload.id;
                            axi_aw_len <= payload.len;
                            axi_aw_valid <= payload.valid;

                            // Debug output
                            if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                write_debug_log($sformatf("Write Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                    write_addr_array_index, payload.test_count, payload.addr, payload.burst, 
                                    payload.size, payload.id, payload.len, payload.valid));
                            end

                            // 配列インデックスを更新
                            write_addr_array_index <= write_addr_array_index + 1;
                        end
                    end else begin
                        // 配列終了: 全信号をクリアしてPhase完了
                        axi_aw_addr <= '0;
                        axi_aw_burst <= '0;
                        axi_aw_size <= '0;
                        axi_aw_id <= '0;
                        axi_aw_len <= '0;
                        axi_aw_valid <= 1'b0;
                        
                        write_addr_state <= WRITE_ADDR_FINISH;
                        write_addr_phase_done <= 1'b1;
                        
                        write_debug_log("Write Addr Phase: Array end reached, all signals cleared");
                    end
                end
                // axi_aw_ready = 0の場合は何もしない（現在の信号を保持）
            end
            
            WRITE_ADDR_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                write_addr_phase_done <= 1'b0;
                write_addr_phase_busy <= 1'b0;
                write_addr_state <= WRITE_ADDR_IDLE;
            end
        endcase
    end
end

// Read Address Channel Control Circuit
typedef enum logic [1:0] {
    READ_ADDR_IDLE,        // 待機状態
    READ_ADDR_ACTIVE,      // アクティブ状態（ストール処理も含む）
    READ_ADDR_FINISH       // 終了処理状態
} read_addr_state_t;

read_addr_state_t read_addr_state = READ_ADDR_IDLE;
logic [7:0] read_addr_phase_counter = 8'd0;
logic read_addr_phase_busy = 1'b0;
int read_addr_array_index = 0;

// Read Address Channel Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_addr_state <= READ_ADDR_IDLE;
        read_addr_phase_counter <= 8'd0;
        read_addr_phase_busy <= 1'b0;
        read_addr_phase_done <= 1'b0;
        read_addr_array_index <= 0;
        
        // AXI4 signals
        axi_ar_addr <= '0;
        axi_ar_burst <= '0;
        axi_ar_size <= '0;
        axi_ar_id <= '0;
        axi_ar_len <= '0;
        axi_ar_valid <= 1'b0;
    end else begin
        case (read_addr_state)
            READ_ADDR_IDLE: begin
                if (read_addr_phase_start) begin
                    read_addr_state <= READ_ADDR_ACTIVE;
                    read_addr_phase_busy <= 1'b1;
                    read_addr_phase_counter <= 8'd0;
                    // 配列インデックスはクリアしない（連続的に使用）
                    read_addr_phase_done <= 1'b0;
                end
            end
            
            READ_ADDR_ACTIVE: begin
                // 最優先: Ready信号の判定
                if (axi_ar_ready) begin
                    // 配列の範囲チェック
                    if (read_addr_array_index < read_addr_payloads_with_stall.size()) begin
                        // ペイロードの取得
                        automatic read_addr_payload_t payload = read_addr_payloads_with_stall[read_addr_array_index];
                        
                        // アドレス送信完了の判定（axi_ar_validの時）
                        if (axi_ar_valid) begin
                            // 現在のカウンター値でPhase完了判定
                            if (read_addr_phase_counter < PHASE_TEST_COUNT - 1) begin
                                axi_ar_addr <= payload.addr;
                                axi_ar_burst <= payload.burst;
                                axi_ar_size <= payload.size;
                                axi_ar_id <= payload.id;
                                axi_ar_len <= payload.len;
                                axi_ar_valid <= payload.valid;

                                // Debug output
                                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                    write_debug_log($sformatf("Read Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                        read_addr_array_index, payload.test_count, payload.addr, payload.burst, 
                                        payload.size, payload.id, payload.len, payload.valid));
                                end

                                // 配列インデックスを更新
                                read_addr_array_index <= read_addr_array_index + 1;

                                // Phase継続: カウンターを増加
                                read_addr_phase_counter <= read_addr_phase_counter + 8'd1;
                                write_debug_log($sformatf("Read Addr Phase: Address sent, counter=%0d/%0d", 
                                    read_addr_phase_counter + 1, PHASE_TEST_COUNT));
                            end else begin
                                // Phase完了: 全信号をクリア
                                axi_ar_addr <= '0;
                                axi_ar_burst <= '0;
                                axi_ar_size <= '0;
                                axi_ar_id <= '0;
                                axi_ar_len <= '0;
                                axi_ar_valid <= 1'b0;
                                
                                // 状態遷移
                                read_addr_state <= READ_ADDR_FINISH;
                                read_addr_phase_done <= 1'b1;
                                
                                write_debug_log("Read Addr Phase: Phase completed, all signals cleared");
                            end
                        end else begin
                            // 次のペイロードを出力
                            axi_ar_addr <= payload.addr;
                            axi_ar_burst <= payload.burst;
                            axi_ar_size <= payload.size;
                            axi_ar_id <= payload.id;
                            axi_ar_len <= payload.len;
                            axi_ar_valid <= payload.valid;

                            // Debug output
                            if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                write_debug_log($sformatf("Read Addr[%0d]: test_count=%0d, addr=0x%h, burst=%0d, size=%0d, id=%0d, len=%0d, valid=%0d", 
                                    read_addr_array_index, payload.test_count, payload.addr, payload.burst, 
                                    payload.size, payload.id, payload.len, payload.valid));
                            end

                            // 配列インデックスを更新
                            read_addr_array_index <= read_addr_array_index + 1;
                        end
                    end else begin
                        // 配列終了: 全信号をクリアしてPhase完了
                        axi_ar_addr <= '0;
                        axi_ar_burst <= '0;
                        axi_ar_size <= '0;
                        axi_ar_id <= '0;
                        axi_ar_len <= '0;
                        axi_ar_valid <= 1'b0;
                        
                        read_addr_state <= READ_ADDR_FINISH;
                        read_addr_phase_done <= 1'b1;
                        
                        write_debug_log("Read Addr Phase: Array end reached, all signals cleared");
                    end
                end
                // axi_ar_ready = 0の場合は何もしない（現在の信号を保持）
            end
            
            READ_ADDR_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                read_addr_phase_done <= 1'b0;
                read_addr_phase_busy <= 1'b0;
                read_addr_state <= READ_ADDR_IDLE;
            end
        endcase
    end
end

// Write Data Channel Control Circuit
typedef enum logic [1:0] {
    WRITE_DATA_IDLE,        // 待機状態
    WRITE_DATA_ACTIVE,      // アクティブ状態（ストール処理も含む）
    WRITE_DATA_FINISH       // 終了処理状態
} write_data_state_t;

write_data_state_t write_data_state = WRITE_DATA_IDLE;
logic [7:0] write_data_phase_counter = 8'd0;
logic write_data_phase_busy = 1'b0;
int write_data_array_index = 0;

// Write Data Channel Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_data_state <= WRITE_DATA_IDLE;
        write_data_phase_counter <= 8'd0;
        write_data_phase_busy <= 1'b0;
        write_data_phase_done <= 1'b0;
        write_data_array_index <= 0;
        
        // AXI4 signals
        axi_w_data <= '0;
        axi_w_strb <= '0;
        axi_w_last <= 1'b0;
        axi_w_valid <= 1'b0;
    end else begin
        case (write_data_state)
            WRITE_DATA_IDLE: begin
                if (write_data_phase_start) begin
                    write_data_state <= WRITE_DATA_ACTIVE;
                    write_data_phase_busy <= 1'b1;
                    write_data_phase_counter <= 8'd0;
                    // 配列インデックスはクリアしない（連続的に使用）
                    write_data_phase_done <= 1'b0;
                end
            end
            
            WRITE_DATA_ACTIVE: begin
                // 最優先: Ready信号の判定
                if (axi_w_ready) begin
                    // 配列の範囲チェック
                    if (write_data_array_index < write_data_payloads_with_stall.size()) begin
                        // ペイロードの取得（配列インデックス更新前）
                        automatic write_data_payload_t payload = write_data_payloads_with_stall[write_data_array_index];
                        
                        // Phase完了判定（axi_w_lastの時）
                        if (axi_w_last) begin
                            // 現在のカウンター値でPhase完了判定
                            if (write_data_phase_counter < PHASE_TEST_COUNT - 1) begin
                                axi_w_data <= payload.data;
                                axi_w_strb <= payload.strb;
                                axi_w_last <= payload.last;
                                axi_w_valid <= payload.valid;
                                write_data_array_index <= write_data_array_index + 1;

                                // Debug output
                                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                    write_debug_log($sformatf("Write Data[%0d]: test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d", 
                                        write_data_array_index, payload.test_count, payload.data, payload.strb, 
                                        payload.last, payload.valid));
                                end

                                write_data_phase_counter <= write_data_phase_counter + 8'd1;
                                write_debug_log($sformatf("Write Data Phase: Burst completed, counter=%0d/%0d", 
                                    write_data_phase_counter + 1, PHASE_TEST_COUNT));
                            end else begin
                                // Phase完了: 全信号をクリア
                                axi_w_data <= '0;
                                axi_w_strb <= '0;
                                axi_w_last <= 1'b0;
                                axi_w_valid <= 1'b0;
                                
                                // 状態遷移
                                write_data_state <= WRITE_DATA_FINISH;
                                write_data_phase_done <= 1'b1;
                                
                                write_debug_log("Write Data Phase: Phase completed, all signals cleared");
                            end
                        end else begin
                            // 次のペイロードを出力
                            axi_w_data <= payload.data;
                            axi_w_strb <= payload.strb;
                            axi_w_last <= payload.last;
                            axi_w_valid <= payload.valid;

                            // Debug output
                            if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                write_debug_log($sformatf("Write Data[%0d]: test_count=%0d, data=0x%h, strb=0x%h, last=%0d, valid=%0d", 
                                    write_data_array_index, payload.test_count, payload.data, payload.strb, 
                                    payload.last, payload.valid));
                            end

                            write_data_array_index <= write_data_array_index + 1;
                        end
                    end else begin
                        // 配列終了: 全信号をクリアしてPhase完了
                        axi_w_data <= '0;
                        axi_w_strb <= '0;
                        axi_w_last <= 1'b0;
                        axi_w_valid <= 1'b0;
                        
                        write_data_state <= WRITE_DATA_FINISH;
                        write_data_phase_done <= 1'b1;
                        
                        write_debug_log("Write Data Phase: Array end reached, all signals cleared");
                    end
                end
                // axi_w_ready = 0の場合は何もしない（現在の信号を保持）
            end
            
            WRITE_DATA_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                write_data_phase_done <= 1'b0;
                write_data_phase_busy <= 1'b0;
                write_data_state <= WRITE_DATA_IDLE;
            end
        endcase
    end
end

// Read Data Channel Control Circuit
typedef enum logic [1:0] {
    READ_DATA_IDLE,        // 待機状態
    READ_DATA_ACTIVE,      // アクティブ状態（期待値検証も含む）
    READ_DATA_FINISH       // 終了処理状態
} read_data_state_t;

read_data_state_t read_data_state = READ_DATA_IDLE;
logic [7:0] read_data_phase_counter = 8'd0;
logic read_data_phase_busy = 1'b0;
int read_data_array_index = 0;

// Read Data Channel Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_data_state <= READ_DATA_IDLE;
        read_data_phase_counter <= 8'd0;
        read_data_phase_busy <= 1'b0;
        read_data_phase_done <= 1'b0;
        read_data_array_index <= 0;
        
        // AXI4 signals
        // axi_r_ready is controlled by initial value (1'b1)
    end else begin
        case (read_data_state)
            READ_DATA_IDLE: begin
                if (read_data_phase_start) begin
                    read_data_state <= READ_DATA_ACTIVE;
                    read_data_phase_busy <= 1'b1;
                    read_data_phase_counter <= 8'd0;
                    // 配列インデックスはクリアしない（連続的に使用）
                    read_data_phase_done <= 1'b0;
                    // axi_r_ready is controlled by initial value (1'b1)
                end
            end
            
            READ_DATA_ACTIVE: begin
                // 最優先: Valid信号の判定
                if (axi_r_valid && axi_r_ready) begin
                    // 配列の範囲チェック
                    if (read_data_array_index < read_data_expected.size()) begin
                        // 期待値の取得
                        automatic read_data_expected_t expected = read_data_expected[read_data_array_index];
                        
                        // バースト完了の判定（last=1の時）
                        if (axi_r_last) begin
                            // 現在のカウンター値でPhase完了判定
                            if (read_data_phase_counter < PHASE_TEST_COUNT - 1) begin
                                // データ検証（ストローブが有効なバイトのみ）
                                if (!check_read_data(axi_r_data, expected.expected_data, expected.expected_strobe)) begin
                                    $error("Read Data Mismatch at index %0d: Expected 0x%h, Got 0x%h", 
                                        read_data_array_index, expected.expected_data, axi_r_data);
                                    $finish;
                                end
                        
                                // Debug output
                                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                    write_debug_log($sformatf("Read Data[%0d]: test_count=%0d, data=0x%h, expected=0x%h, expected_strobe=0x%h, last=%0d", 
                                        read_data_array_index, expected.test_count, axi_r_data, expected.expected_data, expected.expected_strobe, axi_r_last));
                                end

                                // 配列インデックスを更新
                                read_data_array_index <= read_data_array_index + 1;

                                // Phase継続: カウンターを増加
                                read_data_phase_counter <= read_data_phase_counter + 8'd1;
                                write_debug_log($sformatf("Read Data Phase: Burst completed, counter=%0d/%0d", 
                                    read_data_phase_counter + 1, PHASE_TEST_COUNT));
                            end else begin
                                // Phase完了: 全信号をクリア
                                // axi_r_ready is controlled by initial value (1'b1)

                                // 配列インデックスを更新
                                read_data_array_index <= read_data_array_index + 1;

                                // 状態遷移
                                read_data_state <= READ_DATA_FINISH;
                                read_data_phase_done <= 1'b1;
                                
                                write_debug_log("Read Data Phase: Phase completed, all signals cleared");
                            end
                        end else begin
                            // データ検証（ストローブが有効なバイトのみ）
                            if (!check_read_data(axi_r_data, expected.expected_data, expected.expected_strobe)) begin
                                $error("Read Data Mismatch at index %0d: Expected 0x%h, Got 0x%h", 
                                       read_data_array_index, expected.expected_data, axi_r_data);
                                $finish;
                            end
                        
                            // Debug output
                            if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                                write_debug_log($sformatf("Read Data[%0d]: test_count=%0d, data=0x%h, expected=0x%h, expected_strobe=0x%h, last=%0d", 
                                    read_data_array_index, expected.test_count, axi_r_data, expected.expected_data, expected.expected_strobe, axi_r_last));
                            end

                            // 配列インデックスを更新
                            read_data_array_index <= read_data_array_index + 1;
                        end
                    end else begin
                        // 配列終了: 全信号をクリアしてPhase完了
                        // axi_r_ready is controlled by initial value (1'b1)
                        
                        read_data_state <= READ_DATA_FINISH;
                        read_data_phase_done <= 1'b1;
                        
                        write_debug_log("Read Data Phase: Array end reached, all signals cleared");
                    end
                end
                // axi_r_valid = 0 または axi_r_ready = 0の場合は何もしない（現在の信号を保持）
            end
            
            READ_DATA_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                read_data_phase_done <= 1'b0;
                read_data_phase_busy <= 1'b0;
                read_data_state <= READ_DATA_IDLE;
                // axi_r_ready is controlled by initial value (1'b1)
            end
        endcase
    end
end

// Protocol Verification System
// 1-clock delayed signals for payload hold check
logic [AXI_ADDR_WIDTH-1:0] axi_aw_addr_delayed;
logic [1:0]                axi_aw_burst_delayed;
logic [2:0]                axi_aw_size_delayed;
logic [AXI_ID_WIDTH-1:0]   axi_aw_id_delayed;
logic [7:0]                axi_aw_len_delayed;
logic                      axi_aw_valid_delayed;
logic                      axi_aw_ready_delayed;

logic [AXI_DATA_WIDTH-1:0] axi_w_data_delayed;
logic [AXI_STRB_WIDTH-1:0] axi_w_strb_delayed;
logic                       axi_w_last_delayed;
logic                       axi_w_valid_delayed;
logic                       axi_w_ready_delayed;

logic [AXI_ADDR_WIDTH-1:0] axi_ar_addr_delayed;
logic [1:0]                axi_ar_burst_delayed;
logic [2:0]                axi_ar_size_delayed;
logic [AXI_ID_WIDTH-1:0]   axi_ar_id_delayed;
logic [7:0]                axi_ar_len_delayed;
logic                      axi_ar_valid_delayed;
logic                      axi_ar_ready_delayed;

logic [AXI_DATA_WIDTH-1:0] axi_r_data_delayed;
logic [AXI_ID_WIDTH-1:0]   axi_r_id_delayed;
logic [1:0]                axi_r_resp_delayed;
logic                       axi_r_last_delayed;
logic                       axi_r_valid_delayed;
logic                       axi_r_ready_delayed;

// 1-clock delay circuit
always_ff @(posedge clk) begin
    // Write Address Channel
    axi_aw_addr_delayed <= axi_aw_addr;
    axi_aw_burst_delayed <= axi_aw_burst;
    axi_aw_size_delayed <= axi_aw_size;
    axi_aw_id_delayed <= axi_aw_id;
    axi_aw_len_delayed <= axi_aw_len;
    axi_aw_valid_delayed <= axi_aw_valid;
    axi_aw_ready_delayed <= axi_aw_ready;
    
    // Write Data Channel
    axi_w_data_delayed <= axi_w_data;
    axi_w_strb_delayed <= axi_w_strb;
    axi_w_last_delayed <= axi_w_last;
    axi_w_valid_delayed <= axi_w_valid;
    axi_w_ready_delayed <= axi_w_ready;
    
    // Read Address Channel
    axi_ar_addr_delayed <= axi_ar_addr;
    axi_ar_burst_delayed <= axi_ar_burst;
    axi_ar_size_delayed <= axi_ar_size;
    axi_ar_id_delayed <= axi_ar_id;
    axi_ar_len_delayed <= axi_ar_len;
    axi_ar_valid_delayed <= axi_ar_valid;
    axi_ar_ready_delayed <= axi_ar_ready;
    
    // Read Data Channel
    axi_r_data_delayed <= axi_r_data;
    axi_r_id_delayed <= axi_r_id;
    axi_r_resp_delayed <= axi_r_resp;
    axi_r_last_delayed <= axi_r_last;
    axi_r_valid_delayed <= axi_r_valid;
    axi_r_ready_delayed <= axi_r_ready;
end

// Write Address Channel payload hold check (start monitoring after reset deassertion)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Don't monitor during reset
    end else begin
        if (!axi_aw_ready_delayed) begin
            // Check if payload changed during Ready negated
            if (axi_aw_addr !== axi_aw_addr_delayed) begin
                $error("Write Address Channel: Address changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_aw_addr, axi_aw_addr_delayed);
                $finish;
            end
            if (axi_aw_burst !== axi_aw_burst_delayed) begin
                $error("Write Address Channel: Burst changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_aw_burst, axi_aw_burst_delayed);
                $finish;
            end
            if (axi_aw_size !== axi_aw_size_delayed) begin
                $error("Write Address Channel: Size changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_aw_size, axi_aw_size_delayed);
                $finish;
            end
            if (axi_aw_id !== axi_aw_id_delayed) begin
                $error("Write Address Channel: ID changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_aw_id, axi_aw_id_delayed);
                $finish;
            end
            if (axi_aw_len !== axi_aw_len_delayed) begin
                $error("Write Address Channel: Length changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_aw_len, axi_aw_len_delayed);
                $finish;
            end
            if (axi_aw_valid !== axi_aw_valid_delayed) begin
                $error("Write Address Channel: Valid changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_aw_valid, axi_aw_valid_delayed);
                $finish;
            end
        end
    end
end

// Write Data Channel payload hold check
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Don't monitor during reset
    end else begin
        if (!axi_w_ready_delayed) begin
            if (axi_w_data !== axi_w_data_delayed) begin
                $error("Write Data Channel: Data changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_w_data, axi_w_data_delayed);
                $finish;
            end
            if (axi_w_strb !== axi_w_strb_delayed) begin
                $error("Write Data Channel: Strobe changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_w_strb, axi_w_strb_delayed);
                $finish;
            end
            if (axi_w_last !== axi_w_last_delayed) begin
                $error("Write Data Channel: Last changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_w_last, axi_w_last_delayed);
                $finish;
            end
            if (axi_w_valid !== axi_w_valid_delayed) begin
                $error("Write Data Channel: Valid changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_w_valid, axi_w_valid_delayed);
                $finish;
            end
        end
    end
end

// Read Address Channel payload hold check
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Don't monitor during reset
    end else begin
        if (!axi_ar_ready_delayed) begin
            if (axi_ar_addr !== axi_ar_addr_delayed) begin
                $error("Read Address Channel: Address changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_ar_addr, axi_ar_addr_delayed);
                $finish;
            end
            if (axi_ar_burst !== axi_ar_burst_delayed) begin
                $error("Read Address Channel: Burst changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_ar_burst, axi_ar_burst_delayed);
                $finish;
            end
            if (axi_ar_size !== axi_ar_size_delayed) begin
                $error("Read Address Channel: Size changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_ar_size, axi_ar_size_delayed);
                $finish;
            end
            if (axi_ar_id !== axi_ar_id_delayed) begin
                $error("Read Address Channel: ID changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_ar_id, axi_ar_id_delayed);
                $finish;
            end
            if (axi_ar_len !== axi_ar_len_delayed) begin
                $error("Read Address Channel: Length changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_ar_len, axi_ar_len_delayed);
                $finish;
            end
            if (axi_ar_valid !== axi_ar_valid_delayed) begin
                $error("Read Address Channel: Valid changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_ar_valid, axi_ar_valid_delayed);
                $finish;
            end
        end
    end
end

// Read Data Channel payload hold check
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Don't monitor during reset
    end else begin
        if (!axi_r_ready_delayed) begin
            if (axi_r_data !== axi_r_data_delayed) begin
                $error("Read Data Channel: Data changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_r_data, axi_r_data_delayed);
                $finish;
            end
            if (axi_r_id !== axi_r_id_delayed) begin
                $error("Read Data Channel: ID changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_r_id, axi_r_id_delayed);
                $finish;
            end
            if (axi_r_resp !== axi_r_resp_delayed) begin
                $error("Read Data Channel: Response changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_r_resp, axi_r_resp_delayed);
                $finish;
            end
            if (axi_r_last !== axi_r_last_delayed) begin
                $error("Read Data Channel: Last changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_r_last, axi_r_last_delayed);
                $finish;
            end
            if (axi_r_valid !== axi_r_valid_delayed) begin
                $error("Read Data Channel: Valid changed during Ready negated. Current: %0d, Delayed: %0d", 
                       axi_r_valid, axi_r_valid_delayed);
                $finish;
            end
        end
    end
end

// Test start and completion summary
initial begin
    if (LOG_ENABLE) begin
        // Phase 1: Display test configuration
        write_log("=== AXI4 Testbench Configuration ===");
        write_log("Test Configuration:");
        write_log($sformatf("  - Memory Size: %0d bytes (%0d MB)", MEMORY_SIZE_BYTES, MEMORY_SIZE_BYTES/1024/1024));
        write_log($sformatf("  - Data Width: %0d bits", AXI_DATA_WIDTH));
        write_log($sformatf("  - Total Test Count: %0d", TOTAL_TEST_COUNT));
        write_log($sformatf("  - Phase Test Count: %0d", PHASE_TEST_COUNT));
        write_log($sformatf("  - Number of Phases: %0d", (TOTAL_TEST_COUNT / PHASE_TEST_COUNT)));
        
        // Wait for stimulus generation completion
        wait(generate_stimulus_expected_done);
        
        // Phase 2: Display generated payloads summary
        write_log("=== Generated Payloads Summary ===");
        write_log("Generated Test Data:");
        write_log($sformatf("  - Write Address Payloads: %0d", write_addr_payloads.size()));
        write_log($sformatf("  - Write Address with Stall: %0d", write_addr_payloads_with_stall.size()));
        write_log($sformatf("  - Write Data Payloads: %0d", write_data_payloads.size()));
        write_log($sformatf("  - Write Data with Stall: %0d", write_data_payloads_with_stall.size()));
        write_log($sformatf("  - Read Address Payloads: %0d", read_addr_payloads.size()));
        write_log($sformatf("  - Read Address with Stall: %0d", read_addr_payloads_with_stall.size()));
        write_log($sformatf("  - Read Data Expected: %0d", read_data_expected.size()));
        write_log($sformatf("  - Write Response Expected: %0d", write_resp_expected.size()));
        
        // Wait for test execution completion
        wait(test_execution_completed);
        
        // Phase 3: Display test execution results summary
        write_log("=== Test Execution Results Summary ===");
        write_log("Test Results:");
        write_log($sformatf("  - Total Tests Executed: %0d", TOTAL_TEST_COUNT));
        write_log($sformatf("  - Total Phases Completed: %0d", (TOTAL_TEST_COUNT / PHASE_TEST_COUNT)));
        write_log("  - All Phases: PASS");
        write_log("  - Test Status: COMPLETED SUCCESSFULLY");
        write_log("=== AXI4 Testbench Log End ===");
    end
end

// Ready negate control logic
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ready_negate_index <= 0;
        // axi_aw_ready and axi_w_ready are controlled by DUT (wire signals)
        axi_r_ready <= 1'b1;
        axi_b_ready <= 1'b1;
    end else begin
        // Update ready negate index
        if (ready_negate_index >= READY_NEGATE_ARRAY_LENGTH - 1) begin
            ready_negate_index <= 0;  // Reset to 0 when reaching maximum
        end else begin
            ready_negate_index <= ready_negate_index + 1;
        end
        
        // Control ready signals based on pulse arrays
        // Note: axi_aw_ready and axi_w_ready are controlled by DUT (wire signals)
        //       axi_r_ready and axi_b_ready are controlled by TB for testing purposes
        axi_r_ready <= !axi_r_ready_negate_pulses[ready_negate_index];
        axi_b_ready <= !axi_b_ready_negate_pulses[ready_negate_index];
    end
end

// Logging and monitoring
// Phase execution logging
always @(posedge clk) begin
    if (LOG_ENABLE && write_addr_phase_start) begin
        write_log($sformatf("Phase %0d: Write Address Channel started", current_phase));
    end
    if (LOG_ENABLE && read_addr_phase_start) begin
        write_log($sformatf("Phase %0d: Read Address Channel started", current_phase));
    end
    if (LOG_ENABLE && write_data_phase_start) begin
        write_log($sformatf("Phase %0d: Write Data Channel started", current_phase));
    end
    if (LOG_ENABLE && read_data_phase_start) begin
        write_log($sformatf("Phase %0d: Read Data Channel started", current_phase));
    end
end

// AXI4 transfer logging (debug)
always @(posedge clk) begin
    if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
        // Write Address Channel transfer
        if (axi_aw_valid && axi_aw_ready) begin
            write_debug_log($sformatf("Write Addr Transfer: addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d", 
                axi_aw_addr, axi_aw_burst, size_to_string(axi_aw_size), axi_aw_id, axi_aw_len));
        end
        
        // Write Data Channel transfer
        if (axi_w_valid && axi_w_ready) begin
            write_debug_log($sformatf("Write Data Transfer: data=0x%h, strb=0x%h, last=%0d", 
                axi_w_data, axi_w_strb, axi_w_last));
        end
        
        // Read Address Channel transfer
        if (axi_ar_valid && axi_ar_ready) begin
            write_debug_log($sformatf("Read Addr Transfer: addr=0x%h, burst=%0d, size=%s, id=%0d, len=%0d", 
                axi_ar_addr, axi_ar_burst, size_to_string(axi_ar_size), axi_ar_id, axi_ar_len));
        end
        
        // Read Data Channel transfer
        if (axi_r_valid && axi_r_ready) begin
            write_debug_log($sformatf("Read Data Transfer: data=0x%h, resp=%0d, last=%0d", 
                axi_r_data, axi_r_resp, axi_r_last));
        end
    end
end

// Stall cycle logging (debug)
always @(posedge clk) begin
    if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
        // Write Address Channel stall
        if (axi_aw_valid && !axi_aw_ready) begin
            write_debug_log("Write Addr Channel: Stall detected");
        end
        
        // Write Data Channel stall
        if (axi_w_valid && !axi_w_ready) begin
            write_debug_log("Write Data Channel: Stall detected");
        end
        
        // Read Address Channel stall
        if (axi_ar_valid && !axi_ar_ready) begin
            write_debug_log("Read Addr Channel: Stall detected");
        end
        
        // Read Data Channel stall
        if (axi_r_valid && !axi_r_ready) begin
            write_debug_log("Read Data Channel: Stall detected");
        end
    end
end

// Write Response Channel Control Circuit
typedef enum logic [1:0] {
    WRITE_RESP_IDLE,        // 待機状態
    WRITE_RESP_ACTIVE,      // アクティブ状態（レスポンス検証も含む）
    WRITE_RESP_FINISH       // 終了処理状態
} write_resp_state_t;

write_resp_state_t write_resp_state = WRITE_RESP_IDLE;
logic [7:0] write_resp_phase_counter = 8'd0;
logic write_resp_phase_busy = 1'b0;
int write_resp_array_index = 0;

// Write Response Channel Control
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_resp_state <= WRITE_RESP_IDLE;
        write_resp_phase_counter <= 8'd0;
        write_resp_phase_busy <= 1'b0;
        write_resp_phase_done <= 1'b0;
        write_resp_array_index <= 0;
        
        // AXI4 signals
        // axi_b_ready is controlled by initial value (1'b1)
    end else begin
        case (write_resp_state)
            WRITE_RESP_IDLE: begin
                if (write_resp_phase_start) begin
                    write_resp_state <= WRITE_RESP_ACTIVE;
                    write_resp_phase_busy <= 1'b1;
                    write_resp_phase_counter <= 8'd0;
                    write_resp_array_index <= 0;
                    write_resp_phase_done <= 1'b0;
                    // axi_b_ready is controlled by initial value (1'b1)
                    
                    // Debug output
                    if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                        write_debug_log("Phase 0: Write Response Channel started");
                    end
                end
            end
            
            WRITE_RESP_ACTIVE: begin
                // Debug output for state transition
                if (LOG_ENABLE && DEBUG_LOG_ENABLE && !write_resp_phase_busy) begin
                    write_debug_log("Write Resp Phase: State transition to ACTIVE");
                    write_resp_phase_busy <= 1'b1;
                end
                
                // 最優先: Valid信号の判定
                if (axi_b_valid && axi_b_ready) begin
                    // 期待値の検索（IDベース）
                    automatic int found_index = -1;
                    automatic int i;
                    foreach (write_resp_expected[i]) begin
                        if (write_resp_expected[i].expected_id === axi_b_id) begin
                            found_index = i;
                            break;
                        end
                    end
                    
                    if (found_index >= 0) begin
                        // 期待値の取得
                        automatic write_resp_expected_t expected = write_resp_expected[found_index];
                        
                        // レスポンス検証
                        if (axi_b_resp !== expected.expected_resp) begin
                            $error("Write Response Mismatch: Expected %0d, Got %0d for ID %0d", 
                                   expected.expected_resp, axi_b_resp, axi_b_id);
                            $finish;
                        end
                        
                        // Debug output
                        if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                            write_debug_log($sformatf("Write Response: ID=%0d, Resp=%0d, Expected=%0d", 
                                axi_b_id, axi_b_resp, expected.expected_resp));
                        end
                        
                        // 現在のカウンター値でPhase完了判定
                        if (write_resp_phase_counter < PHASE_TEST_COUNT - 1) begin
                            // Phase継続: カウンターを増加
                            write_resp_phase_counter <= write_resp_phase_counter + 8'd1;
                            write_debug_log($sformatf("Write Resp Phase: Response received, counter=%0d/%0d", 
                                write_resp_phase_counter + 1, PHASE_TEST_COUNT));
                        end else begin
                            // Phase完了: 全信号をクリア
                            // axi_b_ready is controlled by initial value (1'b1)
                            
                            // 状態遷移
                            write_resp_state <= WRITE_RESP_FINISH;
                            write_resp_phase_done <= 1'b1;
                            
                            write_debug_log("Write Resp Phase: Phase completed, all signals cleared");
                        end
                    end else begin
                        $error("Write Response: No expected value found for ID %0d", axi_b_id);
                        $finish;
                    end
                end
                // axi_b_valid = 0 または axi_b_ready = 0の場合は何もしない（現在の信号を保持）
            end
            
            WRITE_RESP_FINISH: begin
                // Finish processing: negate phase_done and return to IDLE
                write_resp_phase_done <= 1'b0;
                write_resp_phase_busy <= 1'b0;
                write_resp_state <= WRITE_RESP_IDLE;
                // axi_b_ready is controlled by initial value (1'b1)
                
                // Debug output
                if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
                    write_debug_log("Write Resp Phase: State transition to FINISH");
                end
            end
        endcase
    end
end

endmodule
