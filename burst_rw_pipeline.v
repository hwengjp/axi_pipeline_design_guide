// Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.

module burst_rw_pipeline #(
    parameter DATA_WIDTH = 32,        // Data width in bits
    parameter ADDR_WIDTH = 32,        // Address width in bits
    parameter MAX_BURST_LENGTH = 4    // Maximum burst length
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Read Upstream Interface (Input)
    input  wire [ADDR_WIDTH-1:0]   u_r_addr,
    input  wire [7:0]              u_r_length,  // Burst length - 1
    input  wire                     u_r_valid,
    output wire                     u_r_ready,
    
    // Write Upstream Address Interface (Input)
    input  wire [ADDR_WIDTH-1:0]   u_w_addr,
    input  wire [7:0]              u_w_length,  // Burst length - 1
    input  wire                     u_w_addr_valid,
    output wire                     u_w_addr_ready,
    
    // Write Upstream Data Interface (Input)
    input  wire [DATA_WIDTH-1:0]   u_w_data,
    input  wire                     u_w_data_valid,
    output wire                     u_w_data_ready,
    
    // Read Downstream Interface (Output)
    output wire [DATA_WIDTH-1:0]   d_r_data,
    output wire                     d_r_valid,
    output wire                     d_r_last,
    input  wire                     d_r_ready,
    
    // Write Downstream Response Interface (Output)
    output wire [ADDR_WIDTH-1:0]   d_w_response,
    output wire                     d_w_valid,
    input  wire                     d_w_ready
);

    // State definitions
    localparam STATE_IDLE           = 3'b000;
    localparam STATE_R_NLAST        = 3'b001;
    localparam STATE_R_LAST         = 3'b010;
    localparam STATE_W_NLAST        = 3'b011;
    localparam STATE_W_LAST         = 3'b100;

    // State management (T1 stage control)
    reg [2:0]                      t1_current_state;  // Current state
    reg [2:0]                      t1_next_state;     // Next state for combinational logic
    
    // Read T0 stage internal signals
    reg [7:0]                      r_t0_count;        // Burst counter (0xFF = idle, 0x00 = last)
    reg [ADDR_WIDTH-1:0]           r_t0_mem_addr;    // Current memory address
    wire                            r_t0_mem_read_en; // Memory read enable signal
    reg                             r_t0_valid;       // T0 stage valid signal
    wire                            r_t0_last;        // Last burst cycle indicator
    wire                            r_t0_state_ready; // T0 stage ready signal
    
    // Read T1 stage internal signals
    reg [ADDR_WIDTH-1:0]           r_t1_addr;        // T1 stage address output
    reg                             r_t1_valid;       // T1 stage valid signal
    reg                             r_t1_last;        // T1 stage last signal
    
    // Read T2 stage internal signals
    reg [DATA_WIDTH-1:0]           r_t2_data;        // T2 stage data output
    reg                             r_t2_valid;       // T2 stage valid signal
    reg                             r_t2_last;        // T2 stage last signal
    
    // Write T0A stage internal signals
    reg [7:0]                      w_t0a_count;      // Burst counter (0xFF = idle, 0x00 = last)
    reg [ADDR_WIDTH-1:0]           w_t0a_mem_addr;  // Current memory address
    reg                             w_t0a_valid;     // T0A stage valid signal
    wire                            w_t0a_last;      // Last burst cycle indicator
    wire                            w_t0a_state_ready; // T0A stage ready signal
    
    // Write T0D stage internal signals
    reg [DATA_WIDTH-1:0]           w_t0d_data;      // T0D stage data output
    reg                             w_t0d_valid;     // T0D stage data valid signal
    
    // Write T1 stage internal signals
    reg [ADDR_WIDTH-1:0]           w_t1_addr;       // T1 stage address output
    reg [DATA_WIDTH-1:0]           w_t1_data;       // T1 stage data output
    wire                            w_t1_we;         // T1 stage write enable
    reg                             w_t1_valid;      // T1 stage valid signal
    reg                             w_t1_last;       // T1 stage last signal
    
    // Write T2 stage internal signals
    reg [ADDR_WIDTH-1:0]           w_t2_addr;       // T2 stage address output
    reg [DATA_WIDTH-1:0]           w_t2_data;       // T2 stage data output
    wire                            w_t2_we;         // T2 stage write enable
    reg                             w_t2_valid;      // T2 stage valid signal
    reg                             w_t2_last;       // T2 stage last signal
    
    // Write T3 stage internal signals
    reg [ADDR_WIDTH-1:0]           w_t3_response;   // T3 stage response output
    reg                             w_t3_valid;      // T3 stage valid signal
    reg                             w_t3_last;       // T3 stage last signal
    
    // Merge control signals
    wire                            w_t0a_m_ready;   // T0A merge ready signal
    wire                            w_t0d_m_ready;   // T0D merge ready signal
    
    // Priority arbitration signals
    wire                            t1_r_ready;      // T1 Read ready signal
    wire                            t1_w_ready;      // T1 Write ready signal
    
    // Downstream interface assignments
    assign d_r_data  = r_t2_data;
    assign d_r_valid = r_t2_valid;
    assign d_r_last  = r_t2_last;
    
    assign d_w_response = w_t3_response;
    assign d_w_valid = w_t3_valid;
    
    // T1 and T2 write enable assignment
    assign w_t1_we = w_t1_valid;
    assign w_t2_we = w_t2_valid;
    
    // Read T0 stage control signals
    assign r_t0_state_ready = (r_t0_count == 8'hFF) || (r_t0_count == 8'h00); // Ready when idle or last cycle
    assign r_t0_last = (r_t0_count == 8'h00);        // Last cycle when counter reaches 0
    assign r_t0_mem_read_en = (r_t0_count != 8'hFF); // Enable memory read when not idle
    
    // Write T0A stage control signals
    assign w_t0a_state_ready = (w_t0a_count == 8'hFF) || (w_t0a_count == 8'h00); // Ready when idle or last cycle
    assign w_t0a_last = (w_t0a_count == 8'h00);      // Last cycle when counter reaches 0
    
    // Priority arbitration logic
    assign t1_r_ready =
    t1_next_state == STATE_IDLE ||
    t1_next_state == STATE_R_NLAST ||
    t1_next_state == STATE_R_LAST;

    assign t1_w_ready =
    t1_next_state == STATE_IDLE ||
    t1_next_state == STATE_W_NLAST ||
    t1_next_state == STATE_W_LAST;

    // Ready signal assignments
    assign u_r_ready = r_t0_state_ready && t1_r_ready && d_r_ready;           // Read upstream ready
    assign u_w_addr_ready = w_t0a_state_ready && w_t0a_m_ready && t1_w_ready && d_w_ready; // Write address upstream ready
    assign u_w_data_ready = w_t0d_m_ready && t1_w_ready && d_w_ready;         // Write data upstream ready
    
    // Merge ready generation for Write pipeline
    assign w_t0a_m_ready = (w_t0d_valid && !w_t0a_valid) || (!w_t0d_valid && !w_t0a_valid) || (w_t0d_valid && w_t0a_valid);
    assign w_t0d_m_ready = (!w_t0d_valid && w_t0a_valid) || (!w_t0d_valid && !w_t0a_valid) || (w_t0d_valid && w_t0a_valid);
    

    // State transition logic - split into logical groups
    always @(*) begin
        case (t1_current_state)
            STATE_IDLE: begin
                // IDLE state transitions with priority order
                if (d_w_ready && (w_t0a_valid && w_t0d_valid)) begin
                    // Write priority: d_w_ready && (w_t0a_valid && w_t0d_valid)
                    t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
                end else if (d_r_ready && r_t0_valid) begin
                    // Read execution: d_r_ready && r_t0_valid
                    t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
                end else begin
                    // No execution - stay in idle
                    t1_next_state = t1_current_state;
                end
            end

            STATE_R_NLAST, STATE_R_LAST: begin
                // READ states transitions - d_r_ready controls state changes
                if (d_r_ready) begin
                    // d_r_ready is HIGH - evaluate state transitions
                    if (d_w_ready && (w_t0a_valid && w_t0d_valid)) begin
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
                    // d_r_ready is LOW - hold current state
                    t1_next_state = t1_current_state;
                end
            end

            STATE_W_NLAST, STATE_W_LAST: begin
                // WRITE states transitions - d_w_ready controls state changes
                if (d_w_ready) begin
                    // d_w_ready is HIGH - evaluate state transitions
                    if (d_r_ready && r_t0_valid) begin
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
                    // d_w_ready is LOW - hold current state
                    t1_next_state = t1_current_state;
                end
            end

            default: t1_next_state = 3'bx;
        endcase
    end    

    // Current state management logic (T1 stage)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t1_current_state <= STATE_IDLE; // Initialize to Idle
        end else begin
            t1_current_state <= t1_next_state;
        end
    end
    
    // Read T0 stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_t0_count <= 8'hFF;                        // Initialize to idle state
            r_t0_mem_addr <= {ADDR_WIDTH{1'b0}};        // Initialize address to 0
            r_t0_valid <= 1'b0;                         // Initialize valid to 0
        end else if (d_r_ready && t1_r_ready) begin
            case (r_t0_state_ready)
                1'b1: begin // Ready state (Idle or last cycle)
                    r_t0_count <= u_r_valid ? u_r_length : 8'hFF;  // Load burst length or stay idle
                    r_t0_mem_addr <= u_r_addr;                     // Load start address
                    r_t0_valid <= u_r_valid;                       // Set valid based on upstream
                end
                1'b0: begin // Not ready state (Bursting)
                    r_t0_count <= r_t0_count - 8'h01;             // Decrement burst counter
                    r_t0_mem_addr <= r_t0_mem_addr + 1;            // Increment memory address
                    r_t0_valid <= 1'b1;                            // Keep valid during burst
                end
            endcase
        end
    end
    
    // Read T1 stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_t1_addr <= {ADDR_WIDTH{1'b0}};              // Initialize address to 0
            r_t1_valid <= 1'b0;                            // Initialize valid to 0
            r_t1_last <= 1'b0;                             // Initialize last to 0
        end else if (d_r_ready && t1_r_ready) begin
            // Forward T0 signals to T1 stage
            r_t1_addr <= r_t0_mem_addr;                            // Forward T0 address
            r_t1_valid <= r_t0_valid;                              // Forward T0 valid signal
            r_t1_last <= r_t0_last;                                // Forward T0 last signal
        end
    end
    
    // Read T2 stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_t2_data <= {DATA_WIDTH{1'b0}};              // Initialize data to 0
            r_t2_valid <= 1'b0;                            // Initialize valid to 0
            r_t2_last <= 1'b0;                             // Initialize last to 0
        end else if (d_r_ready) begin
            if (t1_current_state==STATE_R_NLAST || t1_current_state==STATE_R_LAST) begin
                // Memory access with enable control
                r_t2_data <= (r_t1_valid) ? r_t1_addr : r_t2_data;     // Update data when valid, hold when not
                r_t2_valid <= r_t1_valid;                              // Forward T1 valid signal
                r_t2_last <= r_t1_last;                                // Forward T1 last signal
            end else begin
                r_t2_data <= r_t2_data;
                r_t2_valid <= 1'b0;
                r_t2_last <= 1'b0;
            end
        end
    end
    
    // Write T0A stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_t0a_count <= 8'hFF;                        // Initialize to idle state
            w_t0a_mem_addr <= {ADDR_WIDTH{1'b0}};        // Initialize address to 0
            w_t0a_valid <= 1'b0;                         // Initialize valid to 0
        end else if (d_w_ready && t1_w_ready) begin
            if (w_t0a_m_ready) begin
                case (w_t0a_state_ready)
                    1'b1: begin // Ready state (Idle or last cycle)
                        w_t0a_count <= u_w_length;          // Load burst length
                        w_t0a_mem_addr <= u_w_addr;         // Load start address
                        w_t0a_valid <= u_w_addr_valid;      // Set valid based on upstream
                    end
                    1'b0: begin // Not ready state (Bursting)
                        w_t0a_count <= w_t0a_count - 8'h01; // Decrement burst counter
                        w_t0a_mem_addr <= w_t0a_mem_addr + 1; // Increment memory address
                        w_t0a_valid <= 1'b1;              // Keep valid during burst
                    end
                endcase
            end
        end
    end
    
    // Write T0D stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_t0d_data <= {DATA_WIDTH{1'b0}};             // Initialize data to 0
            w_t0d_valid <= 1'b0;                          // Initialize valid to 0
        end else if (d_w_ready && t1_w_ready) begin
            if (w_t0d_m_ready) begin
                w_t0d_data <= u_w_data;                     // Update data from upstream
                w_t0d_valid <= u_w_data_valid;              // Set valid based on upstream
            end
        end
    end
    
    // Write T1 stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_t1_addr <= {ADDR_WIDTH{1'b0}};              // Initialize address to 0
            w_t1_data <= {DATA_WIDTH{1'b0}};              // Initialize data to 0
            w_t1_valid <= 1'b0;                           // Initialize valid to 0
            w_t1_last <= 1'b0;                            // Initialize last to 0
        end else if (d_w_ready && t1_w_ready) begin
            w_t1_addr <= w_t0a_mem_addr;                    // Forward T0A address
            w_t1_data <= w_t0d_data;                        // Forward T0D data
            w_t1_valid <= (w_t0a_valid && w_t0d_valid);     // Valid when both T0A and T0D are valid
            w_t1_last <= w_t0a_last;                        // Forward T0A last signal
        end
    end
    
    // Write T2 stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_t2_addr <= {ADDR_WIDTH{1'b0}};              // Initialize address to 0
            w_t2_data <= {DATA_WIDTH{1'b0}};              // Initialize data to 0
            w_t2_valid <= 1'b0;                           // Initialize valid to 0
            w_t2_last <= 1'b0;                            // Initialize last to 0
        end else if (d_w_ready) begin
            if (t1_current_state==STATE_W_NLAST || t1_current_state==STATE_W_LAST) begin
                w_t2_addr <= w_t1_addr;                         // Forward T1 address
                w_t2_data <= w_t1_data;                         // Forward T1 data
                w_t2_valid <= w_t1_valid;                       // Forward T1 valid signal
                w_t2_last <= w_t1_last;                         // Forward T1 last signal
            end else begin
                w_t2_addr <= w_t2_addr;
                w_t2_data <= w_t2_data;
                w_t2_valid <= 1'b0;
                w_t2_last <= 1'b0;
            end
        end
    end
    
    // Write T3 stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_t3_response <= {ADDR_WIDTH{1'b0}};           // Initialize response to 0
            w_t3_valid <= 1'b0;                           // Initialize valid to 0
            w_t3_last <= 1'b0;                            // Initialize last to 0
        end else if (d_w_ready) begin
            w_t3_valid <= w_t2_valid;                       // Forward T2 valid signal
            w_t3_last <= w_t2_last;                         // Forward T2 last signal
            w_t3_response <= ((w_t2_addr == w_t2_data) && w_t2_we) ? w_t2_addr : {ADDR_WIDTH{1'bx}}; // Generate response based on condition
        end
    end

endmodule
