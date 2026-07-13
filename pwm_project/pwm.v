module pwm_controller (
    input clk,
    input rst,
    input [7:0] duty_cycle, // How long the pulse stays HIGH (0-255)
    output reg pwm_out
);
    reg [7:0] counter;

    always @(posedge clk) begin
        if (rst) begin
            counter <= 8'b0;
            pwm_out <= 1'b0;
        end else begin
            counter <= counter + 1; // The counter just keeps spinning
            // If counter is less than duty_cycle, keep output HIGH
            pwm_out <= (counter < duty_cycle); 
        end
    end
endmodule

