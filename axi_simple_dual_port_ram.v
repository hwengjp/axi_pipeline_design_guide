// Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.

module axi_simple_dual_port_ram #(
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
    reg [AXI_ADDR_WIDTH-1:0] r_t0_addr;        // T0 stage address
    reg [1:0]                 r_t0_burst;       // T0 stage burst type
    reg [AXI_ID_WIDTH-1:0]   r_t0_id;          // T0 stage ID
    reg [7:0]                 r_t0_len;         // T0 stage burst length
    reg                       r_t0_valid;       // T0 stage valid
    reg [7:0]                 r_t0_count;       // T0 stage burst counter
    wire                      r_t0_last;        // T0 stage last signal
    wire                      r_t0_state_ready; // T0 stage ready state

    wire [AXI_DATA_WIDTH-1:0] r_t1_data;        // T1 stage data
    reg [AXI_ID_WIDTH-1:0]   r_t1_id;          // T1 stage ID
    reg                       r_t1_valid;       // T1 stage valid
    reg                       r_t1_last;        // T1 stage last signal

    // Write pipeline internal signals
    reg [AXI_ADDR_WIDTH-1:0] w_t0a_addr;        // T0A stage address
    reg [1:0]                 w_t0a_burst;       // T0A stage burst type
    reg [AXI_ID_WIDTH-1:0]   w_t0a_id;          // T0A stage ID
    reg [7:0]                 w_t0a_len;         // T0A stage burst length
    reg                       w_t0a_valid;       // T0A stage valid
    reg [7:0]                 w_t0a_count;       // T0A stage burst counter
    wire                      w_t0a_last;        // T0A stage last signal
    wire                      w_t0a_state_ready; // T0A stage ready state

    reg [AXI_DATA_WIDTH-1:0] w_t0d_data;        // T0D stage data
    reg [AXI_STRB_WIDTH-1:0] w_t0d_strb;        // T0D stage strobe
    reg                       w_t0d_valid;       // T0D stage valid
    reg                       w_t0d_last;        // T0D stage last

    reg [AXI_ID_WIDTH-1:0]   w_t1_id;           // T1 stage ID
    reg                       w_t1_valid;        // T1 stage valid
    reg                       w_t1_last;         // T1 stage last

    reg [AXI_ID_WIDTH-1:0]   w_t2_id;           // T2 stage ID
    reg                       w_t2_valid;        // T2 stage valid

    // Write pipeline control signals
    wire w_t0a_m_ready;      // T0A merge ready signal
    wire w_t0d_m_ready;      // T0D merge ready signal

    // Memory instance (T1 stage)
    dual_port_ram #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .MEM_DEPTH(MEMORY_SIZE_BYTES / (AXI_DATA_WIDTH/8)),
        .ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) memory_inst (
        .clk(axi_clk),
        .read_addr(r_t0_addr),
        .read_enable(axi_r_ready && r_t0_valid),
        .read_data(r_t1_data),
        .write_addr(w_t0a_addr),
        .write_data(w_t0d_data),
        .write_enable(axi_b_ready && (w_t0a_valid && w_t0d_valid) ? w_t0d_strb : {(AXI_STRB_WIDTH){1'b0}})
    );

    // Read pipeline T0 stage - Address counter and burst control
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            r_t0_addr <= 0;
            r_t0_burst <= 0;
            r_t0_id <= 0;
            r_t0_len <= 0;
            r_t0_valid <= 0;
            r_t0_count <= 8'hFF;
        end else if (axi_r_ready) begin
            case (r_t0_state_ready)
                1'b1: begin // Ready state (Idle or last cycle)
                    if (axi_ar_valid) begin
                        r_t0_addr <= axi_ar_addr;
                        r_t0_burst <= axi_ar_burst;
                        r_t0_id <= axi_ar_id;
                        r_t0_len <= axi_ar_len;
                        r_t0_valid <= 1'b1;
                        r_t0_count <= axi_ar_len;
                    end else begin
                        r_t0_valid <= 1'b0;
                        r_t0_count <= 8'hFF;
                    end
                end
                1'b0: begin // Not ready state (Bursting)
                    r_t0_count <= r_t0_count - 1;
                    case (r_t0_burst)
                        2'b00: begin // FIXED
                            r_t0_addr <= r_t0_addr;  // Address remains fixed
                        end
                        2'b01: begin // INCR
                            r_t0_addr <= r_t0_addr + (AXI_DATA_WIDTH/8);  // Increment by data size
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

    // Read pipeline T1 stage - Memory access
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            r_t1_id <= 0;
            r_t1_valid <= 0;
            r_t1_last <= 0;
        end else if (axi_r_ready) begin
            r_t1_id <= r_t0_id;
            r_t1_valid <= r_t0_valid;
            r_t1_last <= r_t0_last;
        end
    end

    // Control signal generation
    assign r_t0_last = (r_t0_count == 0);
    assign r_t0_state_ready = (r_t0_count == 8'hFF) || (r_t0_count == 0);

    // AXI interface signals
    assign axi_ar_ready = axi_ar_valid && r_t0_state_ready;
    assign axi_r_data = r_t1_data;
    assign axi_r_id = r_t1_id;
    assign axi_r_resp = 2'b00;  // OKAY response
    assign axi_r_last = r_t1_last;
    assign axi_r_valid = r_t1_valid;

    // Write pipeline T0A stage - Address counter and burst control
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            w_t0a_addr <= 0;
            w_t0a_burst <= 0;
            w_t0a_id <= 0;
            w_t0a_len <= 0;
            w_t0a_valid <= 0;
            w_t0a_count <= 8'hFF;
        end else if (axi_b_ready) begin
            if (w_t0a_m_ready) begin
                case (w_t0a_state_ready)
                    1'b1: begin // Ready state (Idle or last cycle)
                        if (axi_aw_valid) begin
                            w_t0a_addr <= axi_aw_addr;
                            w_t0a_burst <= axi_aw_burst;
                            w_t0a_id <= axi_aw_id;
                            w_t0a_len <= axi_aw_len;
                            w_t0a_valid <= 1'b1;
                            w_t0a_count <= axi_aw_len;
                        end else begin
                            w_t0a_valid <= 1'b0;
                            w_t0a_count <= 8'hFF;
                        end
                    end
                    1'b0: begin // Not ready state (Bursting)
                        w_t0a_count <= w_t0a_count - 1;
                        case (w_t0a_burst)
                            2'b00: begin // FIXED
                                w_t0a_addr <= w_t0a_addr;  // Address remains fixed
                            end
                            2'b01: begin // INCR
                                w_t0a_addr <= w_t0a_addr + (AXI_DATA_WIDTH/8);  // Increment by data size
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
        end else if (axi_b_ready) begin
            if (w_t0d_m_ready) begin
                w_t0d_data <= axi_w_data;
                w_t0d_strb <= axi_w_strb;
                w_t0d_valid <= axi_w_valid;
                w_t0d_last <= axi_w_last;
            end
        end
    end

    // Write pipeline T1 stage - Merge control
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            w_t1_id <= 0;
            w_t1_valid <= 0;
            w_t1_last <= 0;
        end else if (axi_b_ready) begin
            w_t1_id <= w_t0a_id;
            w_t1_valid <= (w_t0a_valid && w_t0d_valid);
            w_t1_last <= w_t0a_last;
        end
    end

    // Write pipeline T2 stage - Response generation
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            w_t2_id <= 0;
            w_t2_valid <= 0;
        end else if (axi_b_ready) begin
            if (w_t1_last) begin
                w_t2_id <= w_t1_id;
                w_t2_valid <= w_t1_valid;
            end else begin
                w_t2_id <= 0;
                w_t2_valid <= 0;
            end
        end
    end

    // Write control signal generation
    assign w_t0a_last = (w_t0a_count == 0);
    assign w_t0a_state_ready = (w_t0a_count == 8'hFF) || (w_t0a_count == 0);

    // Write merge ready generation
    assign w_t0a_m_ready = (w_t0d_valid && !w_t0a_valid) || (!w_t0d_valid && !w_t0a_valid) || (w_t0d_valid && w_t0a_valid);
    assign w_t0d_m_ready = (!w_t0d_valid && w_t0a_valid) || (!w_t0d_valid && !w_t0a_valid) || (w_t0d_valid && w_t0a_valid);

    // Write ready signal generation
    assign axi_aw_ready = w_t0a_state_ready && w_t0a_m_ready && axi_b_ready;
    assign axi_w_ready = w_t0d_m_ready && axi_b_ready;

    // Write response signals (AXI4 compliant)
    assign axi_b_id = w_t2_id;
    assign axi_b_resp = 2'b00;  // OKAY response
    assign axi_b_valid = w_t2_valid;

endmodule
