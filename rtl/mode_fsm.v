module mode_fsm (
    input  wire clk,
    input  wire rst_n,
    
    // Inputs from other blocks
    input  wire spike_detected,     // From Activity Monitor
    input  wire anomaly_confirmed,  // From FIR Filter (Yes, it's real)
    input  wire is_noise,           // From FIR Filter (No, false alarm)
    input  wire mac_done,           // From MAC Accelerator (Math is finished)
    input  wire tx_done,            // From UART (Message sent successfully)
    
    // Outputs to control power and other blocks
    output reg  en_filter_clk,      // Turns on the FIR Filter clock
    output reg  en_mac_clk,         // Turns on the heavy AI MAC clock
    output reg  tx_start            // Tells the UART to start transmitting
);

    // ----------------------------------------------------
    // State Machine Encoding (Fusion Compiler Friendly)
    // ----------------------------------------------------
    localparam S_IDLE  = 2'b00; // Bypass Mode (Everything sleeping)
    localparam S_CHECK = 2'b01; // Light Mode (Filter checking data)
    localparam S_INFER = 2'b10; // Full Mode (AI doing heavy math)
    localparam S_ALERT = 2'b11; // Output Mode (UART transmitting)

    reg [1:0] current_state, next_state;

    // ----------------------------------------------------
    // 1. Sequential Logic: State Register
    // ----------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // ----------------------------------------------------
    // 2. Combinational Logic: Next State & Outputs
    // ----------------------------------------------------
    always @(*) begin
        // Default Outputs (Everything Off to save power)
        next_state    = current_state;
        en_filter_clk = 1'b0;
        en_mac_clk    = 1'b0;
        tx_start      = 1'b0;

        case (current_state)
            // STATE 0: Sleep / Bypass
            S_IDLE: begin
                if (spike_detected) begin
                    next_state = S_CHECK; // Wake up the filter!
                end
            end

            // STATE 1: Light Processing
            S_CHECK: begin
                en_filter_clk = 1'b1; // Turn on power to the Filter
                
                if (is_noise) begin
                    next_state = S_IDLE;  // False alarm, go back to sleep
                end else if (anomaly_confirmed) begin
                    next_state = S_INFER; // Real anomaly, wake up the AI!
                end
            end

            // STATE 2: Full Inference
            S_INFER: begin
                en_mac_clk = 1'b1; // Turn on power to the 4-Way MAC
                
                if (mac_done) begin
                    next_state = S_ALERT; // Math is done, go send the message
                end
            end

            // STATE 3: Send Alert
            S_ALERT: begin
                tx_start = 1'b1; // Trigger UART
                
                if (tx_done) begin
                    next_state = S_IDLE; // Message sent, go back to sleep
                end
            end
            
            // Safety catch for standard cell synthesis
            default: next_state = S_IDLE;
        endcase
    end

endmodule
