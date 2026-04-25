# Project Manas: Custom-Power-Distribution-Board

![KiCad](https://img.shields.io/badge/Designed_in-KiCad_9.0-blue)

A custom high current Power Distribution Board (PDB) designed specifically for a differential drive robot. This board takes a raw battery input and cleanly steps it down into three isolated, logic level power rails (5V, 3.3V, 1.8V) while actively monitoring system wide power consumption in real time.

## Board Renders
<img width="1367" height="1021" alt="image" src="https://github.com/user-attachments/assets/01aa3568-f8e7-490f-b162-226bb0ca5581" />
<img width="1146" height="926" alt="image" src="https://github.com/user-attachments/assets/99cf9ab5-415e-4aaa-aafe-cb3bd210aba3" />

## Key Features
* **Active Power Monitoring:** Integrated INA219 High side current and voltage monitor. Measures total current across a shunt resistor and reports data back to the microcontroller using I2C (SDA/SCL).
* **5V/3.3V Rail:** Used TPS54302 step down Buck Converter. Isolates power for 3.3V logic and sensors.
* **1.8V Rail:** Derived from the 3.3V rail using AP2112K-1.8 low dropout regulator (LDO) for sensitive components.
* **Mechanical Reliability:** 2-layer design with top and bottom ground planes for electromagnetic shielding, via stitched solid pours.

## System Architecture and Calculations

* **Input Voltage ($V_{in}$):** 12V (Battery Nominal), up to 16.8V (4S LiPo Max)
* **Switching Frequency ($f_{sw}$):** 400kHz
* **Internal Reference Voltage ($V_{ref}$):** 0.596V

### 1. Battery Voltage Sensing (V-Sense)
A voltage divider scales the main battery voltage down to a safe level for a standard 3.3V ADC.
* **Resistors:** R10 = 10kΩ, R1 = 2.2kΩ
* **Divider Ratio:**
  $$V_{ADC} = V_{BATT} \cdot \left(\frac{2.2}{10 + 2.2}\right) \approx V_{BATT} \cdot 0.1803$$
* **Calculated Thresholds:**
  * **@ 16.8V (4S LiPo Max):** 16.8V * 0.1803 = **3.03V** *(Safely below 3.3V limit)*
  * **@ 14.4V (Nominal):** 14.4V * 0.1803 = **2.59V**
  * **@ 12.0V (Discharged):** 12.0V * 0.1803 = **2.16V**

### 2. The 5V Rail
The TPS54302 steps down the 12V input by rapidly switching on and off. The exact 5V output is maintained by a resistor divider network (R3 and R4) that feeds a scaled-down voltage back to the chip's internal reference.
* **Calculated Output ($V_{out}$):**
  $$V_{out} = V_{ref} \cdot \left(1 + \frac{R_{top}}{R_{bot}}\right)$$
  $$V_{out} = 0.596 \cdot \left(1 + \frac{100}{13.3}\right) \approx 5.07\text{V}$$
* **Output Current Limit:** 3.0A (Maximum rating of the TPS54302)
* **Max Estimated Input Current:** ~1.39A *(Assuming a 12V input supplying 15W output at 90% converter efficiency)*

### 3. The 3.3V Sensor Rail
Similar to the 5V rail, the 3.3V rail uses a distinct resistor divider (R5 and R6) to program the output.
* **Calculated Output ($V_{out}$):**
  $$V_{out} = 0.596 \cdot \left(1 + \frac{100}{22.1}\right) \approx 3.29\text{V}$$
* **Output Current Limit:** 3.0A
* **Max Estimated Input Current:** ~0.92A *(Assuming a 12V input supplying 9.9W output at 90% converter efficiency)*

### 4. 1.8V Linear Regulator (AP2112K-1.8)
* **Input Voltage:** 3.3V (Fed directly from the 3.3V Buck rail)
* **Output Voltage:** 1.8V (Fixed)
* **Max Output Current:** 600mA

### 5. Power Monitor (INA219)
The INA219 monitors the total battery current utilizing a precision shunt resistor.
* **Shunt Resistor (R11):** 3mΩ (0.003Ω)
* **Max Measurable Voltage Drop:** ±320mV (Limit of the INA219 PGA)
* **Max Measurable Current:**
  $$I_{max} = \frac{320\text{mV}}{3\text{m}\Omega} = 106.67\text{A}$$
