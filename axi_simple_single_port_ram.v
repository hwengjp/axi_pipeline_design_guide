// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.

module axi_simple_single_port_ram #(
    parameter MEMORY_SIZE_BYTES = 4096,               // Memory size in bytes
    parameter AXI_DATA_WIDTH = 64,                    // AXI data width in bits
    parameter AXI_ID_WIDTH = 8,                      // AXI ID width in bits
    parameter AXI_STRB_WIDTH = AXI_DATA_WIDTH/8,     // AXI strobe width (calculated)
    parameter AXI_ADDR_WIDTH = $clog2(MEMORY_SIZE_BYTES)  // AXI address width in bits (auto-calculated)
)(
    // Clock and Reset
    input                   axi_clk,
    input                   axi_resetn,

    // AXI Read Address Channel
    input  [AXI_ADDR_WIDTH-1:0] axi_ar_addr,
    input  [1:0]                axi_ar_burst,
    input  [2:0]                axi_ar_size,      // Unconnected
    input  [AXI_ID_WIDTH-1:0]   axi_ar_id,
    input  [7:0]                axi_ar_len,
    output wire                  axi_ar_ready,
    input                        axi_ar_valid,

    // AXI Read Data Channel
    output wire [AXI_DATA_WIDTH-1:0] axi_r_data,
    output wire [AXI_ID_WIDTH-1:0]   axi_r_id,
    output wire [1:0]                axi_r_resp,
    output wire                      axi_r_last,
    input                            axi_r_ready,
    output wire                      axi_r_valid,

    // AXI Write Address Channel
    input  [AXI_ADDR_WIDTH-1:0] axi_aw_addr,
    input  [1:0]                axi_aw_burst,
    input  [2:0]                axi_aw_size,      // Unconnected
    input  [AXI_ID_WIDTH-1:0]   axi_aw_id,
    input  [7:0]                axi_aw_len,
    output wire                  axi_aw_ready,
    input                        axi_aw_valid,

    // AXI Write Data Channel
    input  [AXI_DATA_WIDTH-1:0] axi_w_data,
    input                        axi_w_last,
    input  [AXI_STRB_WIDTH-1:0] axi_w_strb,
    output wire                  axi_w_ready,
    input                        axi_w_valid,

    // AXI Write Response Channel
    output wire [AXI_ID_WIDTH-1:0] axi_b_id,
    output wire [1:0]              axi_b_resp,
    input                          axi_b_ready,
    output wire                    axi_b_valid
);

    // Read pipeline internal signals
    reg [AXI_ADDR_WIDTH-1:0] r_t0_addr;        // T0 stage address register (full byte address)
    reg [1:0]                 r_t0_burst;       // T0 stage burst type
    reg [AXI_ID_WIDTH-1:0]   r_t0_id;          // T0 stage ID
    reg                       r_t0_valid;       // T0 stage valid
    reg [7:0]                 r_t0_count;       // T0 stage burst counter
    reg                       r_t0_idle;        // T0 stage idle flag
    wire                      r_t0_last;        // T0 stage last signal
    wire                      r_t0_state_ready; // T0 stage ready state

    // Read T1 stage signals
    reg [AXI_ID_WIDTH-1:0]   r_t1_id;          // T1 stage ID
    reg                       r_t1_valid;       // T1 stage valid
    reg                       r_t1_last;        // T1 stage last signal
    reg [AXI_ADDR_WIDTH-1:0] r_t1_addr;        // T1 stage address (full byte address)

    // Read T2 stage signals
    reg [AXI_ID_WIDTH-1:0]   r_t2_id;          // T2 stage ID
    reg                       r_t2_valid;       // T2 stage valid
    reg                       r_t2_last;        // T2 stage last signal

    // Write T1 stage signals
    reg [AXI_ADDR_WIDTH-1:0] w_t1_addr;        // T1 stage address (full byte address)
    reg [AXI_DATA_WIDTH-1:0] w_t1_data;        // T1 stage data
    reg [AXI_STRB_WIDTH-1:0] w_t1_strb;        // T1 stage strobe
    reg [AXI_ID_WIDTH-1:0]   w_t1_id;          // T1 stage ID
    reg                       w_t1_valid;       // T1 stage valid
    reg                       w_t1_last;        // T1 stage last

    // Write T2 stage signals
    reg [AXI_ADDR_WIDTH-1:0] w_t2_addr;        // T2 stage address
    reg [AXI_DATA_WIDTH-1:0] w_t2_data;        // T2 stage data
    reg                       w_t2_last;        // T2 stage last signal
    reg [AXI_ID_WIDTH-1:0]   w_t2_id;          // T2 stage ID
    reg                       w_t2_valid;       // T2 stage valid

    // Write T3 stage signals
    reg [AXI_ID_WIDTH-1:0]   w_t3_id;          // T3 stage ID (transaction ID)
    reg                       w_t3_valid;       // T3 stage valid signal
    reg                       w_t3_last;        // T3 stage last signal

    // Write pipeline internal signals
    reg [AXI_ADDR_WIDTH-1:0] w_t0a_addr;        // T0A stage address register (full byte address)
    reg [1:0]                 w_t0a_burst;       // T0A stage burst type
    reg [AXI_ID_WIDTH-1:0]   w_t0a_id;          // T0A stage ID
    reg                       w_t0a_valid;       // T0A stage valid
    reg [7:0]                 w_t0a_count;       // T0A stage burst counter
    reg                       w_t0a_idle;        // T0A stage idle flag
    wire                      w_t0a_last;        // T0A stage last signal
    wire                      w_t0a_state_ready; // T0A stage ready state

    reg [AXI_DATA_WIDTH-1:0] w_t0d_data;        // T0D stage data
    reg [AXI_STRB_WIDTH-1:0] w_t0d_strb;        // T0D stage strobe
    reg                       w_t0d_valid;       // T0D stage valid
    reg                       w_t0d_last;        // T0D stage last

    // T1 stage control signals
    wire                      t1_r_ready;       // T1 stage Read ready signal
    wire                      t1_w_ready;       // T1 stage Write ready signal

    // Write pipeline control signals
    wire w_t0a_m_ready;      // T0A merge ready signal
    wire w_t0d_m_ready;      // T0D merge ready signal

    // Memory size calculation
    localparam MEMORY_SIZE_WORDS = MEMORY_SIZE_BYTES / (AXI_DATA_WIDTH/8);
    
    // State definitions (based on burst_rw_pipeline.v)
    localparam STATE_IDLE           = 3'b000;  // Idle state - waiting for read/write requests
    localparam STATE_R_NLAST        = 3'b001;  // Read state - not last transfer in burst
    localparam STATE_R_LAST         = 3'b010;  // Read state - last transfer in burst
    localparam STATE_W_NLAST        = 3'b011;  // Write state - not last transfer in burst
    localparam STATE_W_LAST         = 3'b100;  // Write state - last transfer in burst
    
    // State management (T1 stage control)
    reg [2:0]                      t1_current_state;  // Current state
    reg [2:0]                      t1_next_state;     // Next state for combinational logic
    
    // Memory access control signals
    wire [$clog2(MEMORY_SIZE_WORDS)-1:0] mem_addr;   // Memory address (word address)
    wire                           mem_read_en;       // Memory read enable
    wire [AXI_STRB_WIDTH-1:0]     mem_write_en;      // Memory write enable (byte strobe)
    wire [AXI_DATA_WIDTH-1:0]     mem_read_data;     // Memory read data (to T2 stage)
    
    // Memory access control assignments
    assign mem_addr = ((t1_current_state==STATE_R_NLAST || t1_current_state==STATE_R_LAST) && r_t1_valid) ? 
                      (r_t1_addr >> $clog2(AXI_DATA_WIDTH/8)) : 
                      ((t1_current_state==STATE_W_NLAST || t1_current_state==STATE_W_LAST) && w_t1_valid) ? 
                      (w_t1_addr >> $clog2(AXI_DATA_WIDTH/8)) : 
                      '0;
    assign mem_read_en = (t1_current_state==STATE_R_NLAST || t1_current_state==STATE_R_LAST) && axi_r_ready && r_t1_valid;
    assign mem_write_en = ((t1_current_state==STATE_W_NLAST || t1_current_state==STATE_W_LAST) && axi_b_ready && w_t1_valid) ? w_t1_strb : '0;

    // Memory access conflict detection
    // synthesis translate_off
    always @(posedge axi_clk) begin
        if (mem_read_en && mem_write_en) begin
            $error("Memory Access Conflict: Read and Write enabled simultaneously at time %0t", $time);
            $error("Read enable: %b, Write enable: %b", mem_read_en, mem_write_en);
            $error("Current state: %b, T1 state: %b", t1_current_state, t1_next_state);
            $finish;
        end
    end
    // synthesis translate_on

    // Memory instance (T1 stage)
    single_port_ram #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .MEM_DEPTH(MEMORY_SIZE_WORDS),
        .ADDR_WIDTH($clog2(MEMORY_SIZE_WORDS))
    ) memory_inst (
        .clk(axi_clk),
        .addr(mem_addr),
        .read_enable(mem_read_en),
        .read_data(mem_read_data),
        .write_data(w_t1_data),
        .write_enable(mem_write_en)
    );

    // Next state logic - completely matching burst_rw_pipeline.v
    always @(*) begin
        case (t1_current_state)
            STATE_IDLE: begin
                // IDLE state transitions with priority order
                if (axi_b_ready && (w_t0a_valid && w_t0d_valid)) begin
                    // Write priority: axi_b_ready && (w_t0a_valid && w_t0d_valid)
                    t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
                end else if (axi_r_ready && r_t0_valid) begin
                    // Read execution: axi_r_ready && r_t0_valid
                    t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
                end else begin
                    // No execution - stay in idle
                    t1_next_state = t1_current_state;
                end
            end

            STATE_R_NLAST, STATE_R_LAST: begin
                // READ states transitions - axi_r_ready controls state changes
                if (axi_r_ready) begin
                    // axi_r_ready is HIGH - evaluate state transitions
                    if (axi_b_ready && (w_t0a_valid && w_t0d_valid)) begin
                        // Write request - priority to write
                        t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
                    end else if (r_t0_valid) begin
                        // Continue reading: r_t0_valid
                        t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
                    end else begin
                        // No valid read request - return to idle
                        t1_next_state = STATE_IDLE;
                    end
                end else begin
                    // axi_r_ready is LOW - hold current state
                    t1_next_state = t1_current_state;
                end
            end

            STATE_W_NLAST, STATE_W_LAST: begin
                // WRITE states transitions - axi_b_ready controls state changes
                if (axi_b_ready) begin
                    // axi_b_ready is HIGH - evaluate state transitions
                    if (axi_r_ready && r_t0_valid) begin
                        // Read request - priority to read
                        t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
                    end else if ((w_t0a_valid && w_t0d_valid)) begin
                        // Continue writing: (w_t0a_valid && w_t0d_valid)
                        t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
                    end else begin
                        // No valid write request - return to idle
                        t1_next_state = STATE_IDLE;
                    end
                end else begin
                    // axi_b_ready is LOW - hold current state
                    t1_next_state = t1_current_state;
                end
            end

            default: t1_next_state = 3'bx;
        endcase
    end

    // State transition logic
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            t1_current_state <= STATE_IDLE;
        end else begin
            t1_current_state <= t1_next_state;
        end
    end

    // Read T1 stage - Memory access control
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            r_t1_id <= 0;
            r_t1_valid <= 0;
            r_t1_last <= 0;
            r_t1_addr <= 0;
        end else if (axi_r_ready && t1_r_ready) begin
            r_t1_id <= r_t0_id;
            r_t1_valid <= r_t0_valid;
            r_t1_last <= r_t0_last;
            r_t1_addr <= r_t0_addr;
        end
    end

    // Write T1 stage - Merge control
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            w_t1_id <= 0;
            w_t1_valid <= 0;
            w_t1_last <= 0;
            w_t1_addr <= 0;
            w_t1_data <= 0;
            w_t1_strb <= 0;
        end else if (axi_b_ready && t1_w_ready) begin
            w_t1_id <= w_t0a_id;
            w_t1_valid <= (w_t0a_valid && w_t0d_valid);
            w_t1_last <= w_t0a_last;
            w_t1_addr <= w_t0a_addr;
            w_t1_data <= w_t0d_data;
            w_t1_strb <= w_t0d_strb;
        end
    end

    // Read pipeline T0 stage - Address counter and burst control
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            r_t0_addr <= 0;
            r_t0_burst <= 0;
            r_t0_id <= 0;
            r_t0_valid <= 0;
            r_t0_count <= 0;
            r_t0_idle <= 1'b1;
        end else if (axi_r_ready && t1_r_ready) begin
            case (r_t0_state_ready)
                1'b1: begin // Ready state (Idle or last cycle)
                    if (axi_ar_valid) begin
                        r_t0_count <= axi_ar_len;  // Load burst length
                        r_t0_addr <= axi_ar_addr;  // Load start address
                        r_t0_valid <= 1'b1;        // Set valid
                        r_t0_burst <= axi_ar_burst; // Load burst type
                        r_t0_id <= axi_ar_id;       // Load ID
                        r_t0_idle <= 1'b0;          // Clear idle flag
                    end else begin
                        r_t0_valid <= 1'b0;
                        r_t0_count <= 0;
                        r_t0_idle <= 1'b1;          // Set idle flag
                    end
                end
                1'b0: begin // Not ready state (Bursting)
                    r_t0_count <= r_t0_count - 1;
                    case (r_t0_burst)
                        2'b00: begin // FIXED
                            r_t0_addr <= r_t0_addr;  // Address remains fixed
                        end
                        2'b01: begin // INCR
                            r_t0_addr <= r_t0_addr + (AXI_DATA_WIDTH/8);  // Increment by data size (bytes)
                        end
                        2'b10: begin // WRAP
                            // Calculate wrap boundary
                            if (r_t0_count == 0) begin
                                // Reset to start address for next burst
                                r_t0_addr <= axi_ar_addr;
                            end else begin
                                r_t0_addr <= r_t0_addr + (AXI_DATA_WIDTH/8);
                            end
                        end
                        default: begin
                            r_t0_addr <= r_t0_addr + (AXI_DATA_WIDTH/8);  // Default to INCR
                        end
                    endcase
                end
            endcase
        end
    end

    // Read T2 stage - Memory access (based on burst_rw_pipeline.v)
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            r_t2_id <= 0;
            r_t2_valid <= 0;
            r_t2_last <= 0;
        end else if (axi_r_ready) begin
            if (t1_current_state==STATE_R_NLAST || t1_current_state==STATE_R_LAST) begin
                // Memory access with enable control
                r_t2_id <= r_t1_id;                                   // Forward T1 ID
                r_t2_valid <= r_t1_valid;                              // Forward T1 valid signal
                r_t2_last <= r_t1_last;                                // Forward T1 last signal
            end else begin
                r_t2_id <= 0;
                r_t2_valid <= 1'b0;
                r_t2_last <= 1'b0;
            end
        end
    end

    // Read T0 stage control signals
    assign r_t0_last = !r_t0_idle && (r_t0_count == 8'h00);
    assign r_t0_state_ready = r_t0_idle || (!r_t0_idle && (r_t0_count == 8'h00));
    
    // Priority arbitration logic
    assign t1_r_ready = t1_next_state == STATE_IDLE || t1_next_state == STATE_R_NLAST || t1_next_state == STATE_R_LAST;
    assign t1_w_ready = t1_next_state == STATE_IDLE || t1_next_state == STATE_W_NLAST || t1_next_state == STATE_W_LAST;

    // AXI Read interface signals
    assign axi_ar_ready = r_t0_state_ready && t1_r_ready && axi_r_ready;
    assign axi_r_data = mem_read_data;
    assign axi_r_id = r_t2_id;
    assign axi_r_resp = 2'b00;  // OKAY response
    assign axi_r_last = r_t2_last;
    assign axi_r_valid = r_t2_valid;

    // Write pipeline T0A stage - Address counter and burst control
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            w_t0a_addr <= 0;
            w_t0a_burst <= 0;
            w_t0a_id <= 0;
            w_t0a_valid <= 0;
            w_t0a_count <= 0;
            w_t0a_idle <= 1'b1;
        end else if (axi_b_ready && t1_w_ready) begin
            if (w_t0a_m_ready) begin
                case (w_t0a_state_ready)
                    1'b1: begin // Ready state (Idle or last cycle)
                        if (axi_aw_valid) begin
                            w_t0a_addr <= axi_aw_addr;  // Load start address
                            w_t0a_burst <= axi_aw_burst;  // Load burst type
                            w_t0a_id <= axi_aw_id;        // Load ID
                            w_t0a_valid <= 1'b1;          // Set valid
                            w_t0a_count <= axi_aw_len;    // Load burst length
                            w_t0a_idle <= 1'b0;           // Clear idle flag
                        end else begin
                            w_t0a_valid <= 1'b0;
                            w_t0a_count <= 0;
                            w_t0a_idle <= 1'b1;           // Set idle flag
                        end
                    end
                    1'b0: begin // Not ready state (Bursting)
                        w_t0a_count <= w_t0a_count - 1;
                        case (w_t0a_burst)
                            2'b00: begin // FIXED
                                w_t0a_addr <= w_t0a_addr;  // Address remains fixed
                            end
                            2'b01: begin // INCR
                                w_t0a_addr <= w_t0a_addr + (AXI_DATA_WIDTH/8);  // Increment by data size (bytes)
                            end
                            2'b10: begin // WRAP
                                // Calculate wrap boundary
                                if (w_t0a_count == 0) begin
                                    // Reset to start address for next burst
                                    w_t0a_addr <= axi_aw_addr;
                                end else begin
                                    w_t0a_addr <= w_t0a_addr + (AXI_DATA_WIDTH/8);
                                end
                            end
                            default: begin
                                w_t0a_addr <= w_t0a_addr + (AXI_DATA_WIDTH/8);  // Default to INCR
                            end
                        endcase
                    end
                endcase
            end
        end
    end

    // Write pipeline T0D stage - Data pipeline
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            w_t0d_data <= 0;
            w_t0d_strb <= 0;
            w_t0d_valid <= 0;
            w_t0d_last <= 0;
        end else if (axi_b_ready && t1_w_ready) begin
            if (w_t0d_m_ready) begin
                w_t0d_data <= axi_w_data;
                w_t0d_strb <= axi_w_strb;
                w_t0d_valid <= axi_w_valid;
                w_t0d_last <= axi_w_last;
            end
        end
    end

    // Write T2 stage - Memory access and response generation (matching burst_rw_pipeline.v)
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            w_t2_id <= 0;
            w_t2_valid <= 0;
            w_t2_addr <= 0;
            w_t2_data <= 0;
            w_t2_last <= 0;
        end else if (axi_b_ready) begin
            if (t1_current_state==STATE_W_NLAST || t1_current_state==STATE_W_LAST) begin
                w_t2_id <= w_t1_id;                         // Forward T1 ID
                w_t2_valid <= w_t1_valid;                    // Forward T1 valid signal
                w_t2_addr <= w_t1_addr;                      // Forward T1 address
                w_t2_data <= w_t1_data;                      // Forward T1 data
                w_t2_last <= w_t1_last;                      // Forward T1 last signal
            end else begin
                w_t2_id <= 0;
                w_t2_valid <= 0;
                w_t2_addr <= 0;
                w_t2_data <= 0;
                w_t2_last <= 0;
            end
        end
    end

    // Write T3 stage - Response generation (AXI4 compliant)
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            w_t3_id <= 0;
            w_t3_valid <= 0;
            w_t3_last <= 0;
        end else if (axi_b_ready) begin
            w_t3_id <= w_t2_id;                             // Forward T2 ID
            w_t3_valid <= w_t2_valid;                       // Forward T2 valid signal
            w_t3_last <= w_t2_last;                          // Forward T2 last signal
        end
    end

    // Write T0A stage control signals
    assign w_t0a_last = !w_t0a_idle && (w_t0a_count == 8'h00);
    assign w_t0a_state_ready = w_t0a_idle || (!w_t0a_idle && (w_t0a_count == 8'h00));
    
    // Write merge ready generation
    assign w_t0a_m_ready = (w_t0d_valid && !w_t0a_valid) || (!w_t0d_valid && !w_t0a_valid) || (w_t0d_valid && w_t0a_valid);
    assign w_t0d_m_ready = (!w_t0d_valid && w_t0a_valid) || (!w_t0d_valid && !w_t0a_valid) || (w_t0d_valid && w_t0a_valid);

    // AXI Write interface signals
    assign axi_aw_ready = w_t0a_state_ready && w_t0a_m_ready && t1_w_ready && axi_b_ready;
    assign axi_w_ready = w_t0d_m_ready && t1_w_ready && axi_b_ready;

    // AXI Write response signals
    assign axi_b_id = w_t3_id;
    assign axi_b_resp = 2'b00;  // OKAY response
    assign axi_b_valid = w_t3_valid;

endmodule
