# Project Manas: Custom-Power-Distribution-Board

![KiCad](https://img.shields.io/badge/Designed_in-KiCad_9.0-blue)

A custom high current Power Distribution Board (PDB) designed specifically for a differential drive robot. This board takes a raw battery input and cleanly steps it down into three isolated, logic level power rails (5V, 3.3V, 1.8V) while actively monitoring system wide power consumption in real time.

## Board Renders
><img width="1320" height="727" alt="image" src="https://github.com/user-attachments/assets/e7a16924-3da8-4de8-9d1e-7e7664667b60" />
><img width="1335" height="746" alt="image" src="https://github.com/user-attachments/assets/60dcc3f6-9299-4f64-ae30-8de73d6b40ee" />
><img width="1467" height="837" alt="image" src="https://github.com/user-attachments/assets/fb92a939-6519-4219-bc9d-9347f600ed22" />

## Key Features
* **Active Power Monitoring:** Integrated INA219 High side current and voltage monitor. Measures total current across a shunt resistor and reports data back to the microcontroller using I2C (SDA/SCL).
* **5V/3.3V Rail:** Used TPS54302 step down Buck Converter. Tuned for <10mV ripple using a LC filter. Isolates power for 3.3V logic and sensors
* **1.8V Rail:** Derived from the 3.3V rail using AP2112K-1.8 low dropout regulator (LDO) for sensitive components.
* **Mechanical Realiability:** 2-layer design with top and bottom ground planes for electromagnetic shielding, via stitched thermal relief, dedicated mounting holes for robot chassis.

## System architecture and Calculations
The buck converters were mathematically tuned to achieve an output voltage ripple of under `~10mV`

* **Input Voltage ($V_{in}$):** 12V (Battery)
* **Switching Frequency ($f_{sw}$):** 400kHz
* **Internal Reference Voltage ($V_{ref}$):** 0.596V

### 1. The 5V Rail

#### A. Voltage Step-Down
The TPS54302 steps down the 12V input by rapidly switching on and off. The exact 5V output is maintained by a resistor divider network ($R_3$ and $R_4$) that feeds a scaled down voltage back to the chip's internal reference.
* **Calculated Output ($V_{out}$):**
  $$V_{out} = V_{ref} \cdot \left(1 + \frac{R_{top}}{R_{bot}}\right)$$
  $$V_{out} = 0.596\text{V} \cdot \left(1 + \frac{100\text{k}\Omega}{13.3\text{k}\Omega}\right) \approx \mathbf{5.07\text{V}}$$

#### B. Stage 1: Main LC Filter
The primary inductor ($L_3 = 10\mu\text{H}$) and bulk capacitor ($C_4 = 22\mu\text{F}$) absorb the violent switching pulses to create a stable DC voltage with a slight ripple.
* **Inductor Ripple Current ($\Delta I_L$):**
  $$\Delta I_L = \frac{V_{out} \cdot (V_{in} - V_{out})}{V_{in} \cdot f_{sw} \cdot L_3}$$
  $$\Delta I_L = \frac{5 \cdot (12 - 5)}{12 \cdot 400000 \cdot 10\times 10^{-6}} = \mathbf{0.729\text{A}}$$
* **Stage 1 Voltage Ripple ($\Delta V_{out1}$):**
  $$\Delta V_{out1} = \frac{\Delta I_L}{8 \cdot f_{sw} \cdot C_4}$$
  $$\Delta V_{out1} = \frac{0.729}{8 \cdot 400000 \cdot 22\times 10^{-6}} \approx \mathbf{10.3\text{mV}}$$

#### C. Stage 2: Pi-Filter
To prevent the 10.3mV ripple from interfering with logic thresholds, a secondary low pass filter ($L_2$ Ferrite Bead + $C_5$ $10\mu\text{F}$ Capacitor) physically blocks high frequency switching harmonics.
* **Filter Attenuation Factor ($A$) at 400kHz ($L_{ferrite} \approx 1\mu\text{H}$):**
  $$A = \frac{1}{(2\pi \cdot f_{sw})^2 \cdot L_{ferrite} \cdot C_5}$$
  $$A = \frac{1}{(2\pi \cdot 400000)^2 \cdot 1\times 10^{-6} \cdot 10\times 10^{-6}} \approx \mathbf{0.0158}$$
* **Final 5V Output Ripple ($\Delta V_{total}$):**
  $$\Delta V_{total} = \Delta V_{out1} \cdot A$$
  $$\Delta V_{total} = 10.3\text{mV} \cdot 0.0158 \approx \mathbf{0.16\text{mV}}$$

---

### 2. The 3.3V Sensor Rail

#### A. Voltage Step-Down (Feedback Network)
Similar to the 5V rail, the 3.3V rail uses a distinct resistor divider ($R_5$ and $R_6$) to program the output.
* **Calculated Output ($V_{out}$):**
  $$V_{out} = 0.596\text{V} \cdot \left(1 + \frac{100\text{k}\Omega}{22.1\text{k}\Omega}\right) \approx \mathbf{3.29\text{V}}$$

#### B. Stage 1: Main LC Filter
Tuned specifically for the lower voltage drop, utilizing $L_4 = 6.8\mu\text{H}$ and $C_8 = 22\mu\text{F}$.
* **Inductor Ripple Current ($\Delta I_L$):**
  $$\Delta I_L = \frac{3.3 \cdot (12 - 3.3)}{12 \cdot 400000 \cdot 6.8\times 10^{-6}} = \mathbf{0.879\text{A}}$$
* **Stage 1 Voltage Ripple ($\Delta V_{out1}$):**
  $$\Delta V_{out1} = \frac{0.879}{8 \cdot 400000 \cdot 22\times 10^{-6}} \approx \mathbf{12.5\text{mV}}$$

#### C. Stage 2: Pi-Filter
Utilizing an identical Pi-Filter configuration ($L_5$ Ferrite Bead + $C_9$ $10\mu\text{F}$ Capacitor), the attenuation factor remains identical ($A = 0.0158$).
* **Final 3.3V Output Ripple ($\Delta V_{total}$):**
  $$\Delta V_{total} = 12.5\text{mV} \cdot 0.0158 \approx \mathbf{0.20\text{mV}}$$

---


