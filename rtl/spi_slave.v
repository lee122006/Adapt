module spi_slave #(
    parameter DATA_WIDTH = 8
)(
    input  wire                  clk,       // Main system clock (e.g., 50MHz)
    input  wire                  rst_n,     // Asynchronous active-low reset
    
    // SPI Physical Pins
    input  wire                  spi_sclk,  // Clock from the external sensor
    input  wire                  spi_cs_n,  // Chip Select (Active Low)
    input  wire                  spi_mosi,  // Master Out Slave In (The actual data bits)
    
    // Internal Output to your Activity Monitor
    output reg  [DATA_WIDTH-1:0] data_out,  // The packaged 8-bit number
    output reg                   data_valid // 1-cycle pulse saying "Read this!"
);

    // ----------------------------------------------------
    // 1. Synchronizers (Anti-Metastability)
    // ----------------------------------------------------
    reg [2:0] sclk_sync;
    reg [1:0] cs_n_sync;
    reg [1:0] mosi_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync <= 3'b000;
            cs_n_sync <= 2'b11;  // CS is active low, so default is HIGH
            mosi_sync <= 2'b00;
        end else begin
            sclk_sync <= {sclk_sync[1:0], spi_sclk};
            cs_n_sync <= {cs_n_sync[0], spi_cs_n};
            mosi_sync <= {mosi_sync[0], spi_mosi};
        end
    end

    // Detect the rising edge of the SPI Clock
    wire sclk_rising_edge = (sclk_sync[2:1] == 2'b01);

    // ----------------------------------------------------
    // 2. The Shift Register & Bit Counter
    // ----------------------------------------------------
    reg [2:0] bit_counter;       // Counts from 0 to 7
    reg [DATA_WIDTH-1:0] shift_reg; // Temporary box holding the bits

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_counter <= 3'd0;
            shift_reg   <= {DATA_WIDTH{1'b0}};
            data_out    <= {DATA_WIDTH{1'b0}};
            data_valid  <= 1'b0;
        end else begin
            // Default state: Keep valid pulse low
            data_valid <= 1'b0;

            // If Chip Select is LOW, the sensor is talking to us
            if (cs_n_sync[1] == 1'b0) begin
                
                // On every SPI clock rising edge, grab one bit of data
                if (sclk_rising_edge) begin
                    shift_reg <= {shift_reg[DATA_WIDTH-2:0], mosi_sync[1]}; // Shift left
                    bit_counter <= bit_counter + 1'b1;

                    // Did we just receive the 8th bit?
                    if (bit_counter == 3'd7) begin
                        data_out   <= {shift_reg[DATA_WIDTH-2:0], mosi_sync[1]}; 
                        data_valid <= 1'b1; // Pulse HIGH to wake up Activity Monitor!
                    end
                end
                
            end else begin
                // If CS goes HIGH, the transmission is over. Reset the counter.
                bit_counter <= 3'd0;
            end
        end
    end

endmodule
