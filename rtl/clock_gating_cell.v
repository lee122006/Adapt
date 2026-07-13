module clock_gating_cell (
    input  wire clk_in,    // The main, always-running system clock
    input  wire enable,    // The ON/OFF signal from your Mode FSM
    output wire clk_out    // The safe, gated clock going to your MAC/Filter
);

    // Internal latch to hold the enable signal safely
    reg enable_latch;

    // ----------------------------------------------------
    // The Glitch-Free Latch
    // ----------------------------------------------------
    // This latch only updates when the clock is LOW (0).
    // This guarantees the enable signal never changes while the clock is HIGH (1).
    always @(clk_in or enable) begin
        if (!clk_in) begin
            enable_latch <= enable;
        end
    end

    // ----------------------------------------------------
    // The Safe AND Gate
    // ----------------------------------------------------
    // Now we safely AND the latched enable with the original clock.
    assign clk_out = clk_in & enable_latch;

endmodule
