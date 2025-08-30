//=============================================================================
// AXI Width Converter - Parametrized Implementation
//=============================================================================
// This module provides parametrized AXI bus width conversion for:
// Source widths: 8bit, 16bit, 32bit
// Target widths: 16bit, 32bit, 64bit
// 
// Key Features:
// - Parametrized source and target widths
// - Automatic STROBE position calculation
// - Data alignment and positioning
// - Address cycle preservation
// - SIZE value preservation
//=============================================================================

module axi_narrow_to_wide #(
    parameter int unsigned SOURCE_WIDTH = 64,    // Source bus width in bits
    parameter int unsigned TARGET_WIDTH = 128,   // Target bus width in bits
    
    // Derived parameters
    parameter int unsigned SOURCE_BYTES = SOURCE_WIDTH / 8,
    parameter int unsigned TARGET_BYTES = TARGET_WIDTH / 8,
    parameter int unsigned SOURCE_ADDR_BITS = $clog2(SOURCE_BYTES),
    parameter int unsigned TARGET_ADDR_BITS = $clog2(TARGET_BYTES)
) (
    input  logic                    aclk,
    input  logic                    aresetn,
    
    // Upstream AXI interface (narrower bus)
    // Write Address Channel
    input  logic [31:0]             u_axi_awaddr,
    input  logic [2:0]              u_axi_awsize,
    input  logic [7:0]              u_axi_awlen,
    input  logic [1:0]              u_axi_awburst,
    input  logic                    u_axi_awvalid,
    output logic                    u_axi_awready,
    
    // Write Data Channel
    input  logic [SOURCE_WIDTH-1:0] u_axi_wdata,
    input  logic [SOURCE_BYTES-1:0] u_axi_wstrb,
    input  logic                    u_axi_wvalid,
    output logic                    u_axi_wready,
    input  logic                    u_axi_wlast,
    
    // Write Response Channel
    output logic [1:0]              u_axi_bresp,
    output logic                    u_axi_bvalid,
    input  logic                    u_axi_bready,
    
    // Read Address Channel
    input  logic [31:0]             u_axi_araddr,
    input  logic [2:0]              u_axi_arsize,
    input  logic [7:0]              u_axi_arlen,
    input  logic [1:0]              u_axi_arburst,
    input  logic                    u_axi_arvalid,
    output logic                    u_axi_arready,
    
    // Read Data Channel
    output logic [SOURCE_WIDTH-1:0] u_axi_rdata,
    output logic [1:0]              u_axi_rresp,
    output logic                    u_axi_rvalid,
    input  logic                    u_axi_rready,
    output logic                    u_axi_rlast,
    
    // Downstream AXI interface (wider bus)
    // Write Address Channel
    output logic [31:0]             d_axi_awaddr,
    output logic [2:0]              d_axi_awsize,
    output logic [7:0]              d_axi_awlen,
    output logic [1:0]              d_axi_awburst,
    output logic                    d_axi_awvalid,
    input  logic                    d_axi_awready,
    
    // Write Data Channel
    output logic [TARGET_WIDTH-1:0] d_axi_wdata,
    output logic [TARGET_BYTES-1:0] d_axi_wstrb,
    output logic                    d_axi_wvalid,
    input  logic                    d_axi_wready,
    output logic                    d_axi_wlast,
    
    // Write Response Channel
    input  logic [1:0]              d_axi_bresp,
    input  logic                    d_axi_bvalid,
    output logic                    d_axi_bready,
    
    // Read Address Channel
    output logic [31:0]             d_axi_araddr,
    output logic [2:0]              d_axi_arsize,
    output logic [7:0]              d_axi_arlen,
    output logic [1:0]              d_axi_arburst,
    output logic                    d_axi_arvalid,
    input  logic                    d_axi_arready,
    
    // Read Data Channel
    input  logic [TARGET_WIDTH-1:0] d_axi_rdata,
    input  logic [1:0]              d_axi_rresp,
    input  logic                    d_axi_rvalid,
    output logic                    d_axi_rready,
    input  logic                    d_axi_rlast
);

    //=============================================================================
    // Parameter validation
    //=============================================================================
    // synthesis translate_off
    initial begin
        // Check source width constraints
        if (SOURCE_WIDTH != 8 && SOURCE_WIDTH != 16 && SOURCE_WIDTH != 32 && 
            SOURCE_WIDTH != 64 && SOURCE_WIDTH != 128 && SOURCE_WIDTH != 256 && 
            SOURCE_WIDTH != 512) begin
            $error("SOURCE_WIDTH must be 8, 16, 32, 64, 128, 256, or 512. Current value: %0d", SOURCE_WIDTH);
            $finish;
        end
        
        // Check target width constraints
        if (TARGET_WIDTH != 16 && TARGET_WIDTH != 32 && TARGET_WIDTH != 64 && 
            TARGET_WIDTH != 128 && TARGET_WIDTH != 256 && TARGET_WIDTH != 512 && 
            TARGET_WIDTH != 1024) begin
            $error("TARGET_WIDTH must be 16, 32, 64, 128, 256, 512, or 1024. Current value: %0d", TARGET_WIDTH);
            $finish;
        end
        
        // Check width increase constraint
        if (TARGET_WIDTH <= SOURCE_WIDTH) begin
            $error("TARGET_WIDTH must be greater than SOURCE_WIDTH. Source: %0d, Target: %0d", 
                   SOURCE_WIDTH, TARGET_WIDTH);
            $finish;
        end
        
        $info("AXI Width Converter: %0dbit -> %0dbit", SOURCE_WIDTH, TARGET_WIDTH);
    end
    // synthesis translate_on

    //=============================================================================
    // Address and control signal handling
    //=============================================================================
    // Write Address and control signals are passed through unchanged
    assign d_axi_awaddr  = u_axi_awaddr;
    assign d_axi_awsize  = u_axi_awsize;
    assign d_axi_awlen   = u_axi_awlen;
    assign d_axi_awburst = u_axi_awburst;
    assign d_axi_awvalid = u_axi_awvalid;
    assign u_axi_awready = d_axi_awready;
    assign d_axi_wlast   = u_axi_wlast;
    assign d_axi_bready  = u_axi_bready;
    assign u_axi_bresp   = d_axi_bresp;
    assign u_axi_bvalid  = d_axi_bvalid;
    
    // Read Address and control signals are passed through unchanged
    assign d_axi_araddr  = u_axi_araddr;
    assign d_axi_arsize  = u_axi_arsize;
    assign d_axi_arlen   = u_axi_arlen;
    assign d_axi_arburst = u_axi_arburst;
    assign d_axi_arvalid = u_axi_arvalid;
    assign u_axi_arready = d_axi_arready;
    assign d_axi_rready  = u_axi_rready;
    assign u_axi_rresp   = d_axi_rresp;
    assign u_axi_rvalid  = d_axi_rvalid;
    assign u_axi_rlast   = d_axi_rlast;



    //=============================================================================
    // STROBE and data positioning logic
    //=============================================================================
    // STROBE position is calculated using the general rule:
    // STROBE位置 = アドレスの下位(log2(バス幅バイト数) - SIZE)ビットで決定
    
    logic [TARGET_BYTES-1:0] calculated_strobe;
    
    always_comb begin
        // Default values
        d_axi_wdata = '0;
        calculated_strobe = '0;
        
        // Calculate target data position based on address alignment
        int unsigned target_offset;
        target_offset = u_axi_awaddr[TARGET_ADDR_BITS-1:0];
        
        // STROBE and data positioning based on SIZE
        case (u_axi_awsize)
            3'b000: begin  // 1 byte transfer
                // STROBE position: log2(TARGET_BYTES) - 0 = log2(TARGET_BYTES) bits
                int unsigned strobe_bits = TARGET_ADDR_BITS;
                int unsigned strobe_offset = u_axi_awaddr[strobe_bits-1:0];
                calculated_strobe[strobe_offset] = 1'b1;
                
                // Data positioning
                d_axi_wdata[target_offset*8 +: 8] = u_axi_wdata[7:0];
            end
            
            3'b001: begin  // 2 byte transfer
                // STROBE position: log2(TARGET_BYTES) - 1 bits
                int unsigned strobe_bits = TARGET_ADDR_BITS - 1;
                int unsigned strobe_offset = u_axi_awaddr[strobe_bits-1:0] * 2;
                calculated_strobe[strobe_offset +: 2] = 2'b11;
                
                // Data positioning
                d_axi_wdata[target_offset*8 +: 16] = u_axi_wdata[15:0];
            end
            
            3'b010: begin  // 4 byte transfer
                // STROBE position: log2(TARGET_BYTES) - 2 bits
                int unsigned strobe_bits = TARGET_ADDR_BITS - 2;
                int unsigned strobe_offset = u_axi_awaddr[strobe_bits-1:0] * 4;
                calculated_strobe[strobe_offset +: 4] = 4'b1111;
                
                // Data positioning
                d_axi_wdata[target_offset*8 +: 32] = u_axi_wdata[31:0];
            end
            
            3'b011: begin  // 8 byte transfer
                // STROBE position: log2(TARGET_BYTES) - 3 bits
                int unsigned strobe_bits = TARGET_ADDR_BITS - 3;
                int unsigned strobe_offset = u_axi_awaddr[strobe_bits-1:0] * 8;
                calculated_strobe[strobe_offset +: 8] = 8'hFF;
                
                // Data positioning
                d_axi_wdata[target_offset*8 +: 64] = u_axi_wdata[63:0];
            end
            
            3'b100: begin  // 16 byte transfer
                // STROBE position: log2(TARGET_BYTES) - 4 bits
                int unsigned strobe_bits = TARGET_ADDR_BITS - 4;
                int unsigned strobe_offset = u_axi_awaddr[strobe_bits-1:0] * 16;
                calculated_strobe[strobe_offset +: 16] = 16'hFFFF;
                
                // Data positioning
                d_axi_wdata[target_offset*8 +: 128] = u_axi_wdata[127:0];
            end
            
            3'b101: begin  // 32 byte transfer
                // STROBE position: log2(TARGET_BYTES) - 5 bits
                int unsigned strobe_bits = TARGET_ADDR_BITS - 5;
                int unsigned strobe_offset = u_axi_awaddr[strobe_bits-1:0] * 32;
                calculated_strobe[strobe_offset +: 32] = 32'hFFFF_FFFF;
                
                // Data positioning
                d_axi_wdata[target_offset*8 +: 256] = u_axi_wdata[255:0];
            end
            
            3'b110: begin  // 64 byte transfer
                // STROBE position: log2(TARGET_BYTES) - 6 bits
                int unsigned strobe_bits = TARGET_ADDR_BITS - 6;
                int unsigned strobe_offset = u_axi_awaddr[strobe_bits-1:0] * 64;
                calculated_strobe[strobe_offset +: 64] = 64'hFFFF_FFFF_FFFF_FFFF;
                
                // Data positioning
                d_axi_wdata[target_offset*8 +: 512] = u_axi_wdata[511:0];
            end
            
            default: begin
                // For unsupported sizes, zero the data and STROBE
                calculated_strobe = '0;
                d_axi_wdata = '0;
            end
        endcase
        
        // Apply calculated STROBE
        d_axi_wstrb = calculated_strobe;
    end

    //=============================================================================
    // Read data width conversion logic
    //=============================================================================
    // Read data from wider downstream bus to narrower upstream bus
    always_comb begin
        // Default values
        u_axi_rdata = '0;
        
        // Calculate source data position based on address alignment
        int unsigned source_offset;
        source_offset = u_axi_araddr[TARGET_ADDR_BITS-1:0];
        
        // Extract data from downstream bus based on upstream width
        u_axi_rdata = d_axi_rdata[source_offset*8 +: SOURCE_WIDTH];
    end

    //=============================================================================
    // Handshake logic
    //=============================================================================
    // Write data handshake
    assign d_axi_wvalid = u_axi_wvalid;
    assign u_axi_wready = d_axi_wready;

    //=============================================================================
    // Assertions for verification
    //=============================================================================
    // synthesis translate_off
    always @(posedge aclk) begin
        // Write transaction validation
        if (u_axi_wvalid && u_axi_wready) begin
            // Check that SIZE value is valid for source width
            if (u_axi_awsize > $clog2(SOURCE_BYTES)) begin
                $error("Invalid SIZE value %0d for source width %0d", u_axi_awsize, SOURCE_WIDTH);
            end
            
            // Check address alignment
            if (u_axi_awaddr[u_axi_awsize-1:0] != '0) begin
                $error("Address 0x%x not aligned for SIZE %0d", u_axi_awaddr, u_axi_awsize);
            end
            
            // Additional checks for large data widths
            if (SOURCE_WIDTH >= 256 && u_axi_awsize > 5) begin
                $error("SIZE value %0d too large for source width %0d", u_axi_awsize, SOURCE_WIDTH);
            end
            
            if (TARGET_WIDTH >= 512 && u_axi_awsize > 6) begin
                $error("SIZE value %0d too large for target width %0d", u_axi_awsize, TARGET_WIDTH);
            end
        end
        
        // Read transaction validation
        if (u_axi_arvalid && u_axi_arready) begin
            // Check that SIZE value is valid for source width
            if (u_axi_arsize > $clog2(SOURCE_BYTES)) begin
                $error("Invalid SIZE value %0d for source width %0d", u_axi_arsize, SOURCE_WIDTH);
            end
            
            // Check address alignment
            if (u_axi_araddr[u_axi_arsize-1:0] != '0) begin
                $error("Address 0x%x not aligned for SIZE %0d", u_axi_araddr, u_axi_arsize);
            end
            
            // Additional checks for large data widths
            if (SOURCE_WIDTH >= 256 && u_axi_arsize > 5) begin
                $error("SIZE value %0d too large for source width %0d", u_axi_arsize, SOURCE_WIDTH);
            end
            
            if (TARGET_WIDTH >= 512 && u_axi_arsize > 6) begin
                $error("SIZE value %0d too large for target width %0d", u_axi_arsize, TARGET_WIDTH);
            end
        end
    end
    // synthesis translate_on

endmodule








