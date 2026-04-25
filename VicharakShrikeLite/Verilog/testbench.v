`timescale 1ns / 1ps
`include "main.v"
module tb_main;

    // 1. Declare inputs as 'reg'
    reg clk;
    reg rst;
    reg rp2040_sck;
    reg rp2040_mosi;
    reg rp2040_cs_n;
    reg motor_rx; // NEW: The incoming wire from the motor

    // 2. Declare outputs as 'wire'
    wire rp2040_miso; // NEW: The outgoing wire back to the RP2040
    wire motor_tx;

    // 3. Instantiate the Top-Level Bridge (DUT)
    laptop_to_uart_bridge uut (
        .clk(clk),
        .rst(rst),
        .rp2040_sck(rp2040_sck),
        .rp2040_mosi(rp2040_mosi),
        .rp2040_cs_n(rp2040_cs_n),
        .rp2040_miso(rp2040_miso),
        .motor_tx(motor_tx),
        .motor_rx(motor_rx)
    );

    // 4. Generate a 50MHz Clock (20ns period)
    always #10 clk = ~clk;

    // 5. TASK: Simulate the RP2040 (Full-Duplex SPI)
    task spi_transfer;
        input [7:0] tx_data;
        integer i;
        begin
            rp2040_cs_n = 0;
            #100; 
            
            for (i = 7; i >= 0; i = i - 1) begin
                rp2040_mosi = tx_data[i]; 
                #40; 
                rp2040_sck = 1;        // Rising edge
                #40; 
                rp2040_sck = 0;        // Falling edge (MISO changes here)
                #20;
            end
            
            #100;
            rp2040_cs_n = 1;
        end
    endtask

    // 6. TASK: Simulate the Motor Controller sending UART
    // 50MHz / 115200 Baud = 434 clocks per bit.
    // 434 clocks * 20ns per clock = 8680ns delay per bit.
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            // Start Bit (Low)
            motor_rx = 0;
            #8680; 
            
            // 8 Data Bits (LSB first for UART)
            for (i = 0; i < 8; i = i + 1) begin
                motor_rx = data[i];
                #8680;
            end
            
            // Stop Bit (High)
            motor_rx = 1;
            #8680;
        end
    endtask

    // 7. The Main Test Sequence
    initial begin
        $dumpfile("bridge_wave.vcd");
        $dumpvars(0, tb_main);

        // Initialize
        clk = 0;
        rst = 1;             
        rp2040_sck = 0;      
        rp2040_mosi = 0;
        rp2040_cs_n = 1;     
        motor_rx = 1; // UART lines idle HIGH

        #100; rst = 0; #100;

        // ==========================================
        // TEST 1: Forward Path (Laptop -> Motor)
        // ==========================================
        $display("Testing Forward Path...");
        spi_transfer(8'hA5); // Send 10100101
        
        // Wait for UART to finish transmitting
        #100000;

        // ==========================================
        // TEST 2: Reverse Path (Motor -> Laptop)
        // ==========================================
        $display("Testing Reverse Path...");
        // 1. Motor sends a byte (e.g., 8'h3C or 00111100) to the FPGA
        send_uart_byte(8'h3C);
        
        // Give the FPGA a moment to process the stop bit
        #1000;
        
        // 2. RP2040 checks the mailbox by sending a dummy byte (8'h00)
        // While sending 00, it will clock out the 3C that the FPGA just caught!
        spi_transfer(8'h00);

        #5000;
        $finish;
    end

endmodule
