module adapt_soc_top #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    // Global Clock and Reset
    input  wire clk,
    input  wire rst_n,

    // Sensor Ingress (SPI)
    input  wire spi_sclk,
    input  wire spi_cs_n,
    input  wire spi_mosi,
    output wire spi_miso,  // Unused for now, tied to 0

    // System Egress (Alert & UART)
    output wire alert_intr,
    output wire uart_tx
);

    // =========================================================================
    // INTERNAL WIRES (The "cables" connecting the blocks together)
    // =========================================================================
    
    // SPI to Activity Monitor Wires
    wire [DATA_WIDTH-1:0] sensor_data;
    wire                  sensor_data_valid;
    
    // Activity Monitor to FSM Wires
    wire                  spike_detected;
    
    // FSM to Datapath Wires (Enable Signals)
    wire                  en_filter_clk;
    wire                  en_mac_clk;
    wire                  tx_start;

    // Filter to FSM Wires
    wire                  is_noise;
    wire                  anomaly_confirmed;

    // MAC to FSM Wires
    wire                  mac_done;
    wire [ACC_WIDTH-1:0]  mac_result;

    // UART to FSM Wires
    wire                  tx_done;

    // Gated Clocks (The power-saving wires!)
    wire                  gated_filter_clk;
    wire                  gated_mac_clk;

    // Tie off unused outputs for Synthesis safety
    assign spi_miso = 1'b0; 
    assign alert_intr = anomaly_confirmed; // Direct hardware interrupt flag

    // =========================================================================
    // BLOCK INSTANTIATIONS (Plugging the chips into the motherboard)
    // =========================================================================

    // 1. SPI Slave (The Camera Lens)
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_spi_ingress (
        .clk        (clk),
        .rst_n      (rst_n),
        .spi_sclk   (spi_sclk),
        .spi_cs_n   (spi_cs_n),
        .spi_mosi   (spi_mosi),
        .data_out   (sensor_data),
        .data_valid (sensor_data_valid)
    );

    // 2. Activity Monitor (The Motion Sensor)
    activity_monitor #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_activity_monitor (
        .clk            (clk),
        .rst_n          (rst_n),
        .data_valid     (sensor_data_valid),
        .current_data   (sensor_data),
        .threshold      (8'd10), // Example: Wake up if data changes by 10
        .spike_detected (spike_detected)
    );

    // 3. Mode Selection FSM (The Brain)
    mode_fsm u_mode_fsm (
        .clk               (clk),
        .rst_n             (rst_n),
        .spike_detected    (spike_detected),
        .anomaly_confirmed (anomaly_confirmed),
        .is_noise          (is_noise),
        .mac_done          (mac_done),
        .tx_done           (tx_done),
        .en_filter_clk     (en_filter_clk),
        .en_mac_clk        (en_mac_clk),
        .tx_start          (tx_start)
    );

    // 4. Clock Gating Cells (The Power Switches)
    // In actual Synopsys, you map these to foundry ICG cells. We use basic AND logic for RTL.
    assign gated_filter_clk = clk & en_filter_clk;
    assign gated_mac_clk    = clk & en_mac_clk;

    // 5. 4-Way TinyML MAC Accelerator (The Engine)
    // Notice we feed it the 'gated_mac_clk' instead of the main 'clk'!
    tiny_ml_mac_4way #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_mac_accelerator (
        .clk         (gated_mac_clk), // <-- THIS SAVES YOUR POWER!
        .rst_n       (rst_n),
        .enable      (en_mac_clk),
        .x0          (sensor_data), // Example: feeding current data to x0
        .x1          (8'd0),        // In a real system, you'd buffer past 4 samples
        .x2          (8'd0),
        .x3          (8'd0),
        .w0          (8'd2),        // Hardcoded weights for synthesis testing
        .w1          (8'd1),
        .w2          (8'd0),
        .w3          (8'd3),
        .accumulator (mac_result)
    );

    // NOTE: u_fir_filter and u_uart_tx are omitted here for brevity, 
    // but they plug in exactly the same way!

endmodule
