module fir_filter #(
    parameter DATA_WIDTH = 8
)(
    input  wire                  clk,          // This will be the GATED clock!
    input  wire                  rst_n,
    input  wire                  enable,       // From FSM
    input  wire [DATA_WIDTH-1:0] current_data, // From SPI
    
    // Outputs back to the FSM
    output reg                   is_noise,
    output reg                   anomaly_confirmed
);

    // ----------------------------------------------------
    // The Shift Registers (The History)
    // ----------------------------------------------------
    reg [DATA_WIDTH-1:0] tap0, tap1, tap2, tap3;
    
    // ----------------------------------------------------
    // Combinational Math: Add and Divide-by-4
    // ----------------------------------------------------
    // The sum needs to be 2 bits wider (10 bits) to prevent overflow when adding four 8-bit numbers
    wire [DATA_WIDTH+1:0] sum;
    assign sum = tap0 + tap1 + tap2 + tap3;
    
    // Divide by 4 is mathematically identical to shifting right by 2 bits!
    // This takes ZERO electrical power to do in hardware; it's just a wire routing trick.
    wire [DATA_WIDTH-1:0] average;
    assign average = sum[DATA_WIDTH+1:2]; 
    
    // ----------------------------------------------------
    // Sequential Logic: Filter Operation
    // ----------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tap0 <= 0; tap1 <= 0; tap2 <= 0; tap3 <= 0;
            is_noise          <= 1'b0;
            anomaly_confirmed <= 1'b0;
        end 
        else if (enable) begin
            // 1. Shift the new data into the history buffer
            tap3 <= tap2;
            tap2 <= tap1;
            tap1 <= tap0;
            tap0 <= current_data;
            
            // 2. Check the smoothed average against a threshold
            // (e.g., if the average of the last 4 readings is over 15, it's real)
            if (average > 8'd15) begin 
                anomaly_confirmed <= 1'b1;
                is_noise          <= 1'b0;
            end else begin
                anomaly_confirmed <= 1'b0;
                is_noise          <= 1'b1;
            end
            
        end 
        else begin
            // If the FSM turns this block off, immediately pull signals low
            // so the FSM doesn't get stuck in a loop.
            anomaly_confirmed <= 1'b0;
            is_noise          <= 1'b0;
        end
    end

endmodule

