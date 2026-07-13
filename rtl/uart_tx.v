module uart_tx #(
    parameter CLKS_PER_BIT = 434 // 50MHz Clock / 115200 Baud Rate = 434
)(
    input  wire clk,
    input  wire rst_n,
    input  wire tx_start,   // From FSM
    
    output reg  tx_pin,     // Physical wire to the outside world
    output reg  tx_done     // Tells FSM the message was sent
);

    // State Machine for UART
    localparam S_IDLE  = 3'b000;
    localparam S_START = 3'b001;
    localparam S_DATA  = 3'b010;
    localparam S_STOP  = 3'b011;
    
    reg [2:0] state;
    reg [8:0] clock_count;
    reg [2:0] bit_index;
    reg [7:0] tx_data; // The alert message

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            tx_pin      <= 1'b1; // UART idle state is HIGH
            tx_done     <= 1'b0;
            clock_count <= 0;
            bit_index   <= 0;
            tx_data     <= 8'hAA; // Example Alert Byte (10101010)
        end else begin
            tx_done <= 1'b0; // Default pulse low
            
            case (state)
                S_IDLE: begin
                    tx_pin      <= 1'b1;
                    clock_count <= 0;
                    bit_index   <= 0;
                    if (tx_start) begin
                        state <= S_START;
                    end
                end
                
                S_START: begin
                    tx_pin <= 1'b0; // Start bit is LOW
                    if (clock_count < CLKS_PER_BIT - 1) begin
                        clock_count <= clock_count + 1'b1;
                    end else begin
                        clock_count <= 0;
                        state       <= S_DATA;
                    end
                end
                
                S_DATA: begin
                    tx_pin <= tx_data[bit_index];
                    if (clock_count < CLKS_PER_BIT - 1) begin
                        clock_count <= clock_count + 1'b1;
                    end else begin
                        clock_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            state <= S_STOP;
                        end
                    end
                end
                
                S_STOP: begin
                    tx_pin <= 1'b1; // Stop bit is HIGH
                    if (clock_count < CLKS_PER_BIT - 1) begin
                        clock_count <= clock_count + 1'b1;
                    end else begin
                        tx_done <= 1'b1; // Tell FSM we finished!
                        state   <= S_IDLE;
                    end
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
