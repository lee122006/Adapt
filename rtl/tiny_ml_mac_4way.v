module tiny_ml_mac_4way #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  enable,      // From your Mode FSM
    
    // 4 Parallel Data Inputs (X)
    input  wire [DATA_WIDTH-1:0] x0, x1, x2, x3,
    
    // 4 Parallel Weight Inputs (W)
    input  wire [DATA_WIDTH-1:0] w0, w1, w2, w3,
    
    // Outputs
    output reg  [ACC_WIDTH-1:0]  accumulator,
    output reg                   mac_done     // Tells FSM we finished!
);

    // ----------------------------------------------------
    // Combinational Logic (The Multipliers)
    // ----------------------------------------------------
    // We use wires and 'assign' so the multiplication happens instantly 
    // without waiting for a clock edge. ZERO-SPARSITY CHECK is done here.
    wire [DATA_WIDTH*2-1:0] mult_res_0;
    wire [DATA_WIDTH*2-1:0] mult_res_1;
    wire [DATA_WIDTH*2-1:0] mult_res_2;
    wire [DATA_WIDTH*2-1:0] mult_res_3;

    assign mult_res_0 = (x0 == 0 || w0 == 0) ? { (DATA_WIDTH*2){1'b0} } : (x0 * w0);
    assign mult_res_1 = (x1 == 0 || w1 == 0) ? { (DATA_WIDTH*2){1'b0} } : (x1 * w1);
    assign mult_res_2 = (x2 == 0 || w2 == 0) ? { (DATA_WIDTH*2){1'b0} } : (x2 * w2);
    assign mult_res_3 = (x3 == 0 || w3 == 0) ? { (DATA_WIDTH*2){1'b0} } : (x3 * w3);

    // ----------------------------------------------------
    // Sequential Logic (The Accumulator Registers)
    // ----------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= {ACC_WIDTH{1'b0}};
            mac_done    <= 1'b0;
        end else if (enable) begin
            // PARALLEL ACCUMULATION
            // Add the combinational multiplier results to the running total
            accumulator <= accumulator + mult_res_0 + mult_res_1 + mult_res_2 + mult_res_3;
            
            // Pulse mac_done so FSM can move to the next state
            mac_done <= 1'b1;
        end else begin
            mac_done <= 1'b0;
        end
    end

endmodule
