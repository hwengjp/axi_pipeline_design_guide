// Licensed under the Apache License, Version 2.0 - see https://www.apache.org/licenses/LICENSE-2.0 for details.

module axi_dual_width_dual_port_ram #(
    parameter MEMORY_SIZE_BYTES = 4096,               // Memory size in bytes
    parameter READ_DATA_WIDTH = 64,                   // Read data width in bits
    parameter WRITE_DATA_WIDTH = 128,                 // Write data width in bits
    parameter AXI_ID_WIDTH = 8,                      // AXI ID width in bits
    parameter READ_STRB_WIDTH = READ_DATA_WIDTH/8,   // Read strobe width (calculated)
    parameter WRITE_STRB_WIDTH = WRITE_DATA_WIDTH/8, // Write strobe width (calculated)
    parameter AXI_ADDR_WIDTH = $clog2(MEMORY_SIZE_BYTES), // AXI address width in bits (auto-calculated)
    parameter MEMORY_SIZE_WORDS = MEMORY_SIZE_BYTES / (WRITE_DATA_WIDTH/8), // Memory size in words (auto-calculated)
    parameter MEMORY_ADDR_WIDTH = $clog2(MEMORY_SIZE_WORDS), // Memory address width in bits (auto-calculated)
    parameter READ_ADDR_SHIFT_WIDTH = $clog2(READ_DATA_WIDTH/8),  // Read address shift width
    parameter WRITE_ADDR_SHIFT_WIDTH = $clog2(WRITE_DATA_WIDTH/8) // Write address shift width
)(
    // Clock and Reset
    input                   axi_clk,
    input                   axi_resetn,

    // AXI Read Address Channel
    input  [AXI_ADDR_WIDTH-1:0] axi_ar_addr,
    input  [1:0]                axi_ar_burst,
    input  [2:0]                axi_ar_size,
    input  [AXI_ID_WIDTH-1:0]   axi_ar_id,
    input  [7:0]                axi_ar_len,
    output wire                  axi_ar_ready,
    input                        axi_ar_valid,

    // AXI Read Data Channel
    output wire [READ_DATA_WIDTH-1:0] axi_r_data,
    output wire [AXI_ID_WIDTH-1:0]   axi_r_id,
    output wire [1:0]                axi_r_resp,
    output wire                      axi_r_last,
    input                            axi_r_ready,
    output wire                      axi_r_valid,

    // AXI Write Address Channel
    input  [AXI_ADDR_WIDTH-1:0] axi_aw_addr,
    input  [1:0]                axi_aw_burst,
    input  [2:0]                axi_aw_size,
    input  [AXI_ID_WIDTH-1:0]   axi_aw_id,
    input  [7:0]                axi_aw_len,
    output wire                  axi_aw_ready,
    input                        axi_aw_valid,

    // AXI Write Data Channel
    input  [WRITE_DATA_WIDTH-1:0] axi_w_data,
    input                         axi_w_last,
    input  [WRITE_STRB_WIDTH-1:0] axi_w_strb,
    output wire                   axi_w_ready,
    input                         axi_w_valid,

    // AXI Write Response Channel
    output wire [AXI_ID_WIDTH-1:0] axi_b_id,
    output wire [1:0]              axi_b_resp,
    input                          axi_b_ready,
    output wire                    axi_b_valid
);

    // Read pipeline internal signals
    reg [AXI_ADDR_WIDTH-1:0] r_t0_addr;        // T0 stage address register
    wire [MEMORY_ADDR_WIDTH-1:0] r_t0_mem_addr;  // T0 stage memory address
    reg [1:0]                 r_t0_burst;       // T0 stage burst type
    reg [2:0]                 r_t0_size;        // T0 stage SIZE signal
    reg [AXI_ID_WIDTH-1:0]   r_t0_id;          // T0 stage ID
    reg                       r_t0_valid;       // T0 stage valid
    reg [7:0]                 r_t0_count;       // T0 stage burst counter
    reg                       r_t0_idle;        // T0 stage idle flag
    wire                      r_t0_last;        // T0 stage last signal
    wire                      r_t0_state_ready; // T0 stage ready state
    reg [AXI_ADDR_WIDTH-1:0] r_t0_start_addr;  // Store start address
    reg [7:0]                 r_t0_len;         // Store LEN value

    wire [READ_DATA_WIDTH-1:0] r_t1_data;        // T1 stage data
    reg [AXI_ID_WIDTH-1:0]   r_t1_id;          // T1 stage ID
    reg                       r_t1_valid;       // T1 stage valid
    reg                       r_t1_last;        // T1 stage last signal

    // Write pipeline internal signals
    reg [AXI_ADDR_WIDTH-1:0] w_t0a_addr;        // T0A stage address register
    wire [MEMORY_ADDR_WIDTH-1:0] w_t0a_mem_addr;  // T0A stage memory address
    reg [1:0]                 w_t0a_burst;       // T0A stage burst type
    reg [2:0]                 w_t0a_size;        // T0A stage SIZE signal
    reg [AXI_ID_WIDTH-1:0]   w_t0a_id;          // T0A stage ID
    reg                       w_t0a_valid;       // T0A stage valid
    reg [7:0]                 w_t0a_count;       // T0A stage burst counter
    reg                       w_t0a_idle;        // T0A stage idle flag
    wire                      w_t0a_last;        // T0A stage last signal
    wire                      w_t0a_state_ready; // T0A stage ready state
    reg [AXI_ADDR_WIDTH-1:0] w_t0a_start_addr;  // Store start address
    reg [7:0]                 w_t0a_len;         // Store LEN value

    reg [WRITE_DATA_WIDTH-1:0] w_t0d_data;        // T0D stage data
    reg [WRITE_STRB_WIDTH-1:0] w_t0d_strb;        // T0D stage strobe
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

    // T0 stage address assignments - Convert byte address to word address
    assign r_t0_mem_addr = r_t0_addr >> READ_ADDR_SHIFT_WIDTH;
    assign w_t0a_mem_addr = w_t0a_addr >> WRITE_ADDR_SHIFT_WIDTH;

    // Memory instance (T1 stage)
    dual_width_dual_port_ram #(
        .READ_DATA_WIDTH(READ_DATA_WIDTH),
        .WRITE_DATA_WIDTH(WRITE_DATA_WIDTH),
        .MEM_DEPTH(MEMORY_SIZE_WORDS),
        .READ_ADDR_WIDTH(MEMORY_ADDR_WIDTH),
        .WRITE_ADDR_WIDTH(MEMORY_ADDR_WIDTH)
    ) memory_inst (
        .clk(axi_clk),
        .read_addr(r_t0_mem_addr),
        .read_enable(axi_r_ready && r_t0_valid),
        .read_data(r_t1_data),
        .write_addr(w_t0a_mem_addr),
        .write_data(w_t0d_data),
        .write_enable(axi_b_ready && (w_t0a_valid && w_t0d_valid) ? w_t0d_strb : {(WRITE_STRB_WIDTH){1'b0}})
    );
    
    // Read pipeline T0 stage - Address counter and burst control
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            // Reset all registers
            r_t0_addr <= '0;
            r_t0_burst <= '0;
            r_t0_size <= '0;
            r_t0_id <= '0;
            r_t0_valid <= 1'b0;
            r_t0_count <= '0;
            r_t0_idle <= 1'b1;
            r_t0_start_addr <= '0;
            r_t0_len <= '0;
        end else if (axi_r_ready) begin
            case (r_t0_state_ready)
                1'b1: begin // Ready state (Idle or last cycle)
                    if (axi_ar_valid) begin
                        // Latch new address transaction
                        r_t0_start_addr <= axi_ar_addr;
                        r_t0_addr <= axi_ar_addr;
                        r_t0_burst <= axi_ar_burst;
                        r_t0_size <= axi_ar_size;
                        r_t0_id <= axi_ar_id;
                        r_t0_valid <= 1'b1;
                        r_t0_count <= axi_ar_len;
                        r_t0_idle <= 1'b0;
                        r_t0_len <= axi_ar_len;
                    end else begin
                        // Clear valid signal and set idle
                        r_t0_valid <= 1'b0;
                        r_t0_count <= '0;
                        r_t0_idle <= 1'b1;
                    end
                end
                1'b0: begin // Not ready state (Bursting)
                    r_t0_count <= r_t0_count - 1'b1;
                    case (r_t0_burst)
                        2'b00: begin // FIXED burst
                            r_t0_addr <= r_t0_addr;  // Address remains fixed
                        end
                        2'b01: begin // INCR burst
                            r_t0_addr <= r_t0_addr + read_size_to_bytes(r_t0_size);
                        end
                        2'b10: begin // WRAP burst
                            r_t0_addr <= calculate_wrap_address_bit_mask(r_t0_start_addr, r_t0_len, r_t0_count, r_t0_size);
                            // synthesis translate_off
                            if (calculate_wrap_address_bit_mask(r_t0_start_addr, r_t0_len, r_t0_count, r_t0_size) != 
                                calculate_wrap_address(r_t0_start_addr, r_t0_len, r_t0_count, r_t0_size)) begin
                                $error("WRAP address mismatch in READ pipeline: BitMask=0x%x, Legacy=0x%x", 
                                       calculate_wrap_address_bit_mask(r_t0_start_addr, r_t0_len, r_t0_count, r_t0_size),
                                       calculate_wrap_address(r_t0_start_addr, r_t0_len, r_t0_count, r_t0_size));
                                $finish;
                            end
                            // synthesis translate_on
                        end
                        default: begin // Default to INCR behavior
                            r_t0_addr <= r_t0_addr + read_size_to_bytes(r_t0_size);
                        end
                    endcase
                end
            endcase
        end
    end

    // Read pipeline T1 stage - Memory access
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            r_t1_id <= '0;
            r_t1_valid <= 1'b0;
            r_t1_last <= 1'b0;
        end else if (axi_r_ready) begin
            r_t1_id <= r_t0_id;
            r_t1_valid <= r_t0_valid;
            r_t1_last <= r_t0_last;
        end
    end

    // Control signal generation
    assign r_t0_last = !r_t0_idle && (r_t0_count == 0);
    assign r_t0_state_ready = r_t0_idle || (!r_t0_idle && (r_t0_count == 0));

    // AXI interface signals
    assign axi_ar_ready = axi_r_ready && r_t0_state_ready;
    assign axi_r_data = r_t1_data;
    assign axi_r_id = r_t1_id;
    assign axi_r_resp = 2'b00;  // OKAY response
    assign axi_r_last = r_t1_last;
    assign axi_r_valid = r_t1_valid;

    // Write pipeline T0A stage - Address counter and burst control
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            // Reset all registers
            w_t0a_addr <= '0;
            w_t0a_burst <= '0;
            w_t0a_size <= '0;
            w_t0a_id <= '0;
            w_t0a_valid <= 1'b0;
            w_t0a_count <= '0;
            w_t0a_idle <= 1'b1;
            w_t0a_start_addr <= '0;
            w_t0a_len <= '0;
        end else if (axi_b_ready) begin
            if (w_t0a_m_ready) begin
                case (w_t0a_state_ready)
                    1'b1: begin // Ready state (Idle or last cycle)
                        if (axi_aw_valid) begin
                            // Latch new address transaction
                            w_t0a_start_addr <= axi_aw_addr;
                            w_t0a_addr <= axi_aw_addr;
                            w_t0a_burst <= axi_aw_burst;
                            w_t0a_size <= axi_aw_size;
                            w_t0a_id <= axi_aw_id;
                            w_t0a_valid <= 1'b1;
                            w_t0a_count <= axi_aw_len;
                            w_t0a_idle <= 1'b0;
                            w_t0a_len <= axi_aw_len;
                        end else begin
                            // Clear valid signal and set idle
                            w_t0a_valid <= 1'b0;
                            w_t0a_count <= '0;
                            w_t0a_idle <= 1'b1;
                        end
                    end
                    1'b0: begin // Not ready state (Bursting)
                        w_t0a_count <= w_t0a_count - 1;
                        case (w_t0a_burst)
                            2'b00: begin // FIXED burst
                                w_t0a_addr <= w_t0a_start_addr;  // Address remains fixed
                            end
                            2'b01: begin // INCR burst
                                w_t0a_addr <= w_t0a_addr + write_size_to_bytes(w_t0a_size);
                            end
                            2'b10: begin // WRAP burst
                                w_t0a_addr <= calculate_wrap_address_bit_mask(w_t0a_start_addr, w_t0a_len, w_t0a_count, w_t0a_size);
                                // synthesis translate_off
                                if (calculate_wrap_address_bit_mask(w_t0a_start_addr, w_t0a_len, w_t0a_count, w_t0a_size) != 
                                    calculate_wrap_address(w_t0a_start_addr, w_t0a_len, w_t0a_count, w_t0a_size)) begin
                                    $error("WRAP address mismatch in WRITE pipeline: BitMask=0x%x, Legacy=0x%x", 
                                           calculate_wrap_address_bit_mask(w_t0a_start_addr, w_t0a_len, w_t0a_count, w_t0a_size),
                                           calculate_wrap_address(w_t0a_start_addr, w_t0a_len, w_t0a_count, w_t0a_size));
                                    $finish;
                                end
                                // synthesis translate_on
                            end
                            default: begin // Default to INCR behavior
                                w_t0a_addr <= w_t0a_start_addr + write_size_to_bytes(w_t0a_size);
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
            w_t0d_data <= '0;
            w_t0d_strb <= '0;
            w_t0d_valid <= 1'b0;
            w_t0d_last <= 1'b0;
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
            w_t1_id <= '0;
            w_t1_valid <= 1'b0;
            w_t1_last <= 1'b0;
        end else if (axi_b_ready) begin
            w_t1_id <= w_t0a_id;
            w_t1_valid <= (w_t0a_valid && w_t0d_valid);
            w_t1_last <= w_t0a_last;
        end
    end

    // Write pipeline T2 stage - Response generation
    always @(posedge axi_clk or negedge axi_resetn) begin
        if (!axi_resetn) begin
            w_t2_id <= '0;
            w_t2_valid <= 1'b0;
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
    assign w_t0a_last = !w_t0a_idle && (w_t0a_count == 0);
    assign w_t0a_state_ready = w_t0a_idle || (!w_t0a_idle && (w_t0a_count == 0));

    // Write merge ready generation
    assign w_t0a_m_ready = (w_t0d_valid && !w_t0a_valid) || (!w_t0d_valid && !w_t0a_valid) || (w_t0d_valid && w_t0a_valid);
    assign w_t0d_m_ready = (!w_t0d_valid && w_t0a_valid) || (!w_t0d_valid && !w_t0a_valid) || (w_t0d_valid && w_t0a_valid);

    // Utility function: Convert SIZE to bytes for read operations
    function automatic int read_size_to_bytes(input logic [2:0] size);
        return (1 << size);
    endfunction

    // Utility function: Convert SIZE to bytes for write operations
    function automatic int write_size_to_bytes(input logic [2:0] size);
        return (1 << size);
    endfunction

    // Function: Create WRAP bit mask for address calculation (synthesis-friendly)
    function automatic logic [AXI_ADDR_WIDTH-1:0] create_wrap_bit_mask(
        input logic [2:0] size,
        input logic [7:0] len
    );
        int changing_bits;
        logic [AXI_ADDR_WIDTH-1:0] bit_mask;
        
        // Calculate changing bits: SIZE + log2(LEN + 1)
        // WRAP burst LEN is limited to 2, 4, 8, 16 (1, 3, 7, 15)
        // log2(LEN + 1) values: log2(2)=1, log2(4)=2, log2(8)=3, log2(16)=4
        case (len)
            8'd1:  changing_bits = size + 1;  // LEN=1 (2 transfers): log2(2)=1
            8'd3:  changing_bits = size + 2;  // LEN=3 (4 transfers): log2(4)=2
            8'd7:  changing_bits = size + 3;  // LEN=7 (8 transfers): log2(8)=3
            8'd15: changing_bits = size + 4;  // LEN=15 (16 transfers): log2(16)=4
            default: begin
                // synthesis translate_off
                $error("Invalid WRAP burst LEN: %0d. Only LEN=1,3,7,15 are supported for WRAP bursts.", len);
                $finish;
                // synthesis translate_on
                changing_bits = size + 1; // This line will never be reached in simulation
            end
        endcase
        
        // Create bit mask: (1 << changing_bits) - 1
        bit_mask = (1 << changing_bits) - 1;
        
        return bit_mask;
    endfunction

    // Function: Calculate WRAP address using bit mask method
    function automatic logic [AXI_ADDR_WIDTH-1:0] calculate_wrap_address_bit_mask(
        input logic [AXI_ADDR_WIDTH-1:0] start_addr,
        input logic [7:0] len,
        input logic [7:0] count,
        input logic [2:0] size
    );
        logic [AXI_ADDR_WIDTH-1:0] bit_mask;
        logic [AXI_ADDR_WIDTH-1:0] upper_bits;
        logic [AXI_ADDR_WIDTH-1:0] lower_bits;
        logic [AXI_ADDR_WIDTH-1:0] calculated_addr;
        logic [AXI_ADDR_WIDTH-1:0] wrapped_addr;
        
        // Create bit mask for changing bits
        bit_mask = create_wrap_bit_mask(size, len);
        
        // Extract upper bits (unchanged part)
        upper_bits = start_addr & ~bit_mask;
        
        // Calculate address with transfer offset
        calculated_addr = start_addr + ((len - count + 1'b1) * read_size_to_bytes(size));
        
        // Extract lower bits (changing part) and apply mask
        lower_bits = calculated_addr & bit_mask;
        
        // Combine upper and lower bits
        wrapped_addr = upper_bits | lower_bits;
        
        return wrapped_addr;
    endfunction

    // Function: Calculate WRAP address according to AXI4 specification (legacy method for verification)
    function automatic logic [AXI_ADDR_WIDTH-1:0] calculate_wrap_address(
        input logic [AXI_ADDR_WIDTH-1:0] start_addr,
        input logic [7:0] len,
        input logic [7:0] count,
        input logic [2:0] size
    );
        logic [AXI_ADDR_WIDTH-1:0] wrap_boundary;
        logic [AXI_ADDR_WIDTH-1:0] boundary_start;
        logic [7:0] current_transfer;
        logic [AXI_ADDR_WIDTH-1:0] transfer_offset;
        logic [AXI_ADDR_WIDTH-1:0] absolute_addr;
        logic [AXI_ADDR_WIDTH-1:0] relative_offset;
        logic [AXI_ADDR_WIDTH-1:0] wrapped_addr;
        
        // Calculate current transfer number (1-based)
        current_transfer = (len - count + 1'b1);
        
        // Calculate wrap boundary
        wrap_boundary = read_size_to_bytes(size) * (len + 1);
        
        // Calculate boundary start address
        boundary_start = (start_addr / wrap_boundary) * wrap_boundary;
        
        // Calculate transfer offset
        transfer_offset = current_transfer * read_size_to_bytes(size);
        
        // Calculate absolute address
        absolute_addr = start_addr + transfer_offset;
        
        // Calculate relative offset from boundary
        relative_offset = absolute_addr - boundary_start;
        
        // Calculate final wrapped address
        wrapped_addr = boundary_start + (relative_offset % wrap_boundary);
        
        return wrapped_addr;
    endfunction

    // Write ready signal generation
    assign axi_aw_ready = w_t0a_state_ready && w_t0a_m_ready && axi_b_ready;
    assign axi_w_ready = w_t0d_m_ready && axi_b_ready;

    // Write response signals
    assign axi_b_id = w_t2_id;
    assign axi_b_resp = 2'b00;  // OKAY response
    assign axi_b_valid = w_t2_valid;



endmodule
