import machine
import shrike
import sys
import select
import time

# 1. Flash the FPGA
print("Flashing FPGA...")
shrike.flash("FPGA_bitstream_MCU.bin")

# 2. Setup the FPGA Clock (50MHz PWM on Pin 15 -> FPGA Pad 17)
print("Starting FPGA Clock...")
fpga_clk = machine.PWM(machine.Pin(15))
fpga_clk.freq(50_000_000)
fpga_clk.duty_u16(32768)

# 3. Trigger the Hardware Reset (Pin 14 -> FPGA Pad 18)
print("Resetting FPGA Logic...")
fpga_rst = machine.Pin(14, machine.Pin.OUT)
fpga_rst.value(1)
time.sleep(0.1)
fpga_rst.value(0)

# 4. Setup the FULL-DUPLEX SPI connection
# SCK = Pin 2, MOSI = Pin 3, MISO = Pin 0 (Mapped to FPGA Pad 6)
spi = machine.SPI(0, baudrate=5_000_000, sck=machine.Pin(2), mosi=machine.Pin(3), miso=machine.Pin(0))

cs_n = machine.Pin(1, machine.Pin.OUT)
cs_n.value(1)

# 5. Setup USB Serial Polling
poll_obj = select.poll()
poll_obj.register(sys.stdin, select.POLLIN)

print("--- FULL-DUPLEX BRIDGE ACTIVE ---")
print("Type in the Thonny Shell to send. Motor replies will appear below!")

# We use this to prevent printing the same exact byte millions of times
last_received_byte = b'\x00'

# 6. The Infinite Two-Way Loop
while True:
    # --- PART A: LAPTOP TO MOTOR (FORWARD PATH) ---
    poll_results = poll_obj.poll(0) 
    
    if poll_results:
        laptop_byte = sys.stdin.buffer.read(1)
        if laptop_byte:
            print(f"[Laptop -> Motor]: {laptop_byte}")
            cs_n.value(0)
            spi.write(laptop_byte)
            cs_n.value(1)
            time.sleep_us(100) # Wait for UART to finish
            
            # Briefly clear the memory so we don't accidentally read our own echo
            last_received_byte = b'\x00' 

    # --- PART B: MOTOR TO LAPTOP (REVERSE PATH) ---
    # We send a "dummy" byte (0x00) just to generate the clock ticks 
    # needed to pull the data out of the FPGA's MISO line.
    cs_n.value(0)
    fpga_response = spi.read(1, 0x00) 
    cs_n.value(1)
    
    # Check if the FPGA caught a new valid byte from the motor
    if fpga_response != b'\x00' and fpga_response != last_received_byte:
        print(f"[Motor -> Laptop]: {fpga_response}")
        last_received_byte = fpga_response # Remember it so we don't spam the console
            
    # Give the RP2040 CPU time to breathe
    time.sleep(0.01)
