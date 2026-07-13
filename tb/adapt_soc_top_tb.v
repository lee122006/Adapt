`timescale 1ns/1ps

module adapt_soc_top_tb;

    // ---------------------------------------------------------
    // 1. Signals matching the Top Module Ports
    // ---------------------------------------------------------
    reg  clk;
    reg  rst_n;
    reg  spi_sclk;
    reg  spi_cs_n;
    reg  spi_mosi;
    wire spi_miso;
    wire alert_intr;
    wire uart_tx;

    // ---------------------------------------------------------
    // 2. Instantiate the Chip (Device Under Test - DUT)
    // ---------------------------------------------------------
    adapt_soc_top #(
        .DATA_WIDTH(8),
        .ACC_WIDTH(32)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .spi_sclk(spi_sclk),
        .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .alert_intr(alert_intr),
        .uart_tx(uart_tx)
    );

    // ---------------------------------------------------------
    // 3. Generate the 50MHz System Clock (20ns period)
    // ---------------------------------------------------------
    always #10 clk = ~clk;

    // ---------------------------------------------------------
    // 4. SPI Data Injection Task (Simulates the external sensor)
    // ---------------------------------------------------------
    task send_spi_byte(input [7:0] data);
        integer i;
        begin
            spi_cs_n = 0; // Pull Chip Select LOW to start
            #40;
            
            // Shift 8 bits into the chip, MSB first
            for (i = 7; i >= 0; i = i - 1) begin
                spi_mosi = data[i];
                #20 spi_sclk = 1; // Rising edge: Chip reads the data
                #20 spi_sclk = 0; // Falling edge
            end
            
            #40;
            spi_cs_n = 1; // Pull Chip Select HIGH to end transmission
            #100;
        end
    endtask

    // ---------------------------------------------------------
    // 5. Main Simulation Sequence
    // ---------------------------------------------------------
    initial begin
        // Setup waveform dumping for Synopsys Verdi (FSDB format)
        $fsdbDumpfile("adapt_soc_waves.fsdb");
        $fsdbDumpvars(0, adapt_soc_top_tb);

        // Initialize all inputs to 0 / safe states
        clk = 0;
        rst_n = 0;
        spi_sclk = 0;
        spi_cs_n = 1;
        spi_mosi = 0;

        // Apply Reset
        #50 rst_n = 1;
        #100;
        $display("[%0t] SYSTEM READY: Reset released.", $time);

        // --- SCENARIO 1: NORMAL DATA (Should remain asleep) ---
        $display("[%0t] Sending steady background noise...", $time);
        send_spi_byte(8'd10);
        send_spi_byte(8'd11);
        send_spi_byte(8'd10);
        send_spi_byte(8'd12);
        
        #1000; // Wait to observe nothing happens (MAC stays off)

        // --- SCENARIO 2: SENSOR SPIKE (Should trigger AI & UART) ---
        $display("[%0t] INJECTING ANOMALY SPIKE!", $time);
        send_spi_byte(8'd95); // Massive jump in data
        
        // Wait for the UART to finish transmitting. 
        // 115200 baud is slow compared to a 50MHz clock, so we wait a while.
        #150000; 
        
        $display("[%0t] SIMULATION COMPLETE.", $time);
        $finish;
    end

endmodule
