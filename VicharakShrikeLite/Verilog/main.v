(* top *) module laptop_to_uart_bridge (
    (* iopad_external_pin *) input wire clk,
    (* iopad_external_pin *) input wire rst,
    
    (* iopad_external_pin *) input wire rp2040_sck,
    (* iopad_external_pin *) input wire rp2040_mosi,
    (* iopad_external_pin *) input wire rp2040_cs_n,
    (* iopad_external_pin *) output wire rp2040_miso, // NEW: The FPGA's SPI Mouth
    
    (* iopad_external_pin *) output wire motor_tx,
    (* iopad_external_pin *) input wire  motor_rx   // NEW: The FPGA's UART Ears
);

    // Internal Wires
    wire [7:0] spi_to_uart_byte;
    wire       spi_to_uart_ready;
    wire       uart_is_active;
    
    wire [7:0] uart_to_spi_byte;
    wire       uart_rx_done;

    // The Upgraded SPI Slave (Now Full-Duplex!)
    spi_slave spi_transceiver (
        .clk(clk),
        .rst(rst),
        .sck(rp2040_sck),
        .mosi(rp2040_mosi),
        .miso(rp2040_miso),       // Connected to new MISO port
        .cs_n(rp2040_cs_n),
        .tx_byte(uart_to_spi_byte), // Data coming from the motor
        .rx_byte(spi_to_uart_byte), // Data going to the motor
        .byte_ready(spi_to_uart_ready)
    );

    // The UART Transmitter (Pitcher)
    uart_tx #(.CLKS_PER_BIT(434)) motor_uart_out (
        .clk(clk),
        .reset(rst),
        .tx_start(spi_to_uart_ready),  
        .tx_byte(spi_to_uart_byte),    
        .tx_serial(motor_tx),            
        .tx_active(uart_is_active)
    );

    // The NEW UART Receiver (Catcher)
    uart_rx #(.CLKS_PER_BIT(434)) motor_uart_in (
        .clk(clk),
        .reset(rst),
        .rx_serial(motor_rx),
        .rx_byte(uart_to_spi_byte),
        .rx_done(uart_rx_done)
    );

endmodule


// ==========================================
// UPGRADED FULL-DUPLEX SPI SLAVE
// ==========================================
module spi_slave (
    input wire clk,
    input wire sck,
    input wire rst,
    input wire mosi,
    input wire cs_n,
    input wire [7:0] tx_byte,   // Data to send to RP2040
    output wire miso,           // Data wire to RP2040
    output reg [7:0] rx_byte,   // Data received from RP2040
    output reg byte_ready
);
    reg [2:0] sck_sync;
    reg [1:0] mosi_sync;
    reg [1:0] cs_n_sync;
    
    always @(posedge clk) begin
        sck_sync <= {sck_sync[1:0], sck};
        mosi_sync <= {mosi_sync[0], mosi};
        cs_n_sync <= {cs_n_sync[0], cs_n};
    end
    
    wire sck_rising_edge = (sck_sync[2:1]==2'b01);
    wire sck_falling_edge = (sck_sync[2:1]==2'b10);
    wire cs_active = ~cs_n_sync[1];
    
    reg [2:0] bit_count;
    reg [7:0] rx_shift_reg;
    reg [7:0] tx_shift_reg;
    
    // MISO Output Logic (Send data out on falling edge)
    assign miso = cs_active ? tx_shift_reg[7] : 1'b0;
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            bit_count <= 0;
            rx_shift_reg <= 8'b0;
            tx_shift_reg <= 8'b0;
            byte_ready <= 0;
            rx_byte <= 8'b0;
        end else begin
            byte_ready <= 0;
            
            if(!cs_active) begin
                bit_count <= 0;
                tx_shift_reg <= tx_byte; // Load fresh data from UART when idle
            end else begin
                // Read from MOSI on Rising Edge
                if(sck_rising_edge) begin
                    rx_shift_reg <= {rx_shift_reg[6:0], mosi_sync[1]};
                    bit_count <= bit_count + 1;
                    if(bit_count == 3'b111) begin
                        rx_byte <= {rx_shift_reg[6:0], mosi_sync[1]};
                        byte_ready <= 1;
                    end
                end
                // Write to MISO on Falling Edge
                else if (sck_falling_edge) begin
                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                end
            end
        end
    end
endmodule


// ==========================================
// EXISTING UART TRANSMITTER
// ==========================================
module uart_tx #(parameter CLKS_PER_BIT = 434) (
    input wire clk,
    input wire reset,
    input wire tx_start,
    input wire [7:0] tx_byte,
    output reg tx_serial,
    output reg tx_active
);
    localparam IDLE=2'b00, START=2'b01, DATA=2'b10, STOP=2'b11;
    reg [1:0] state = IDLE;
    reg [15:0] clk_count = 0;
    reg [2:0] bit_idx = 0;
    reg [7:0] tx_data_reg = 0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            tx_serial <= 1'b1;
            tx_active <= 0;
            clk_count <= 0;
            bit_idx <= 0;
            tx_data_reg <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx_serial <= 1'b1;
                    if (tx_start) begin
                        tx_active <= 1;
                        tx_data_reg <= tx_byte;
                        state <= START;
                    end else tx_active <= 0;
                end
                START: begin
                    tx_serial <= 1'b0;
                    if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                    else begin clk_count <= 0; state <= DATA; bit_idx <= 0; end
                end
                DATA: begin
                    tx_serial <= tx_data_reg[bit_idx];
                    if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        if (bit_idx < 7) bit_idx <= bit_idx + 1;
                        else state <= STOP;
                    end
                end
                STOP: begin
                    tx_serial <= 1'b1;
                    if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                    else begin clk_count <= 0; state <= IDLE; end
                end
            endcase
        end
    end
endmodule


// ==========================================
// NEW UART RECEIVER
// ==========================================
module uart_rx #(parameter CLKS_PER_BIT = 434) (
    input wire clk,
    input wire reset,
    input wire rx_serial,
    output reg [7:0] rx_byte,
    output reg rx_done
);
    localparam IDLE=2'b00, START=2'b01, DATA=2'b10, STOP=2'b11;
    
    // Safety Synchronizer (Prevents metastability from external raw signals)
    reg rx_sync_1 = 1'b1;
    reg rx_sync_2 = 1'b1;
    always @(posedge clk) begin
        rx_sync_1 <= rx_serial;
        rx_sync_2 <= rx_sync_1;
    end
    
    wire rx_safe = rx_sync_2;

    reg [1:0] state = IDLE;
    reg [15:0] clk_count = 0;
    reg [2:0] bit_idx = 0;
    reg [7:0] rx_data_reg = 0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            clk_count <= 0;
            bit_idx <= 0;
            rx_data_reg <= 8'b0;
            rx_byte <= 8'b0;
            rx_done <= 0;
        end else begin
            rx_done <= 0;
            case (state)
                IDLE: begin
                    clk_count <= 0;
                    if (rx_safe == 1'b0) state <= START; // Drop detected, go to START
                end
                START: begin
                    // Wait for HALF a bit period to sample the exact middle of the start bit
                    if (clk_count == (CLKS_PER_BIT / 2)) begin
                        if (rx_safe == 1'b0) begin // Verify it's still low (not a noise spike)
                            clk_count <= 0;
                            state <= DATA;
                            bit_idx <= 0;
                        end else state <= IDLE; // False alarm, go back
                    end else clk_count <= clk_count + 1;
                end
                DATA: begin
                    // Wait a FULL bit period to read the next bit
                    if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                    else begin
                        clk_count <= 0;
                        rx_data_reg[bit_idx] <= rx_safe; // Store the bit
                        if (bit_idx < 7) bit_idx <= bit_idx + 1;
                        else state <= STOP;
                    end
                end
                STOP: begin
                    // Wait a FULL bit period for the stop bit
                    if (clk_count < CLKS_PER_BIT - 1) clk_count <= clk_count + 1;
                    else begin
                        rx_done <= 1;            // Signal that data is ready
                        rx_byte <= rx_data_reg;  // Output the complete byte
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
