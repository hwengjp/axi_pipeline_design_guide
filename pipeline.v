// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

module pipeline #(
    parameter DATA_WIDTH = 32,
    parameter PIPELINE_STAGES = 4
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Upstream Interface (Input)
    input  wire [DATA_WIDTH-1:0]    u_data,
    input  wire                     u_valid,
    output wire                     u_ready,
    
    // Downstream Interface (Output)
    output wire [DATA_WIDTH-1:0]    d_data,
    output wire                     d_valid,
    input  wire                     d_ready
);

    // Internal signals for pipeline stages
    reg [DATA_WIDTH-1:0]   t_data [PIPELINE_STAGES-1:0]; // t_data[0]=T0, t_data[1]=T1, ..., t_data[PIPELINE_STAGES-1]=T(PIPELINE_STAGES-1)
    reg                    t_valid[PIPELINE_STAGES-1:0]; // t_valid[0]=T0, t_valid[1]=T1, ..., t_valid[PIPELINE_STAGES-1]=T(PIPELINE_STAGES-1)
    
    // Ready signal (common to all FFs)
    wire ready;
    
    // Assign ready signal
    assign ready = d_ready;
    
    // Pipeline stages T0->T1->...->T(PIPELINE_STAGES-1)
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < PIPELINE_STAGES; i = i + 1) begin
                t_data[i]  <= {DATA_WIDTH{1'b0}};
                t_valid[i] <= 1'b0;
            end
        end else if (ready) begin
            t_data[0]  <= u_data;
            t_valid[0] <= u_valid;
            for (i = 1; i < PIPELINE_STAGES; i = i + 1) begin
                t_data[i]  <= t_data[i-1];
                t_valid[i] <= t_valid[i-1];
            end
        end
    end
    
    // Output assignments
    assign d_data  = t_data[PIPELINE_STAGES-1];
    assign d_valid = t_valid[PIPELINE_STAGES-1];
    assign u_ready = ready;

endmodule 