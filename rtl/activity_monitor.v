module activity_monitor #(
    parameter DATA_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Interface from the SPI Slave
    input  wire                  data_valid,    // Goes HIGH for 1 cycle when new SPI data is ready
    input  wire [DATA_WIDTH-1:0] current_data,  // The new sensor reading
    
    // Configuration
    input  wire [DATA_WIDTH-1:0] threshold,     // The limit before waking up the AI
    
    // Output to the FSM
    output reg                   spike_detected
);

    // Internal register to remember the last sensor reading
    reg [DATA_WIDTH-1:0] prev_data;

    // Combinational logic to calculate absolute difference safely
    wire [DATA_WIDTH-1:0] abs_diff;
    assign abs_diff = (current_data > prev_data) ? (current_data - prev_data) : (prev_data - current_data);

    // Sequential Logic: Triggered only on the rising edge of the clock
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // On reset, clear everything to 0
            prev_data      <= {DATA_WIDTH{1'b0}};
            spike_detected <= 1'b0;
        end 
        else if (data_valid) begin
            // 1. Check if the difference exceeds our limit
            if (abs_diff > threshold) begin
                spike_detected <= 1'b1; // FIRE THE WAKE-UP ALARM!
            end else begin
                spike_detected <= 1'b0; // Signal is stable, stay asleep.
            end
            
            // 2. Remember today's data for tomorrow's comparison
            prev_data <= current_data;
        end 
        else begin
            // If no new data came in, pull the alarm pin low so it's just a 1-cycle pulse
            spike_detected <= 1'b0;
        end
    end

endmodule
