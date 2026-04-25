# Project Manas: Holonomic Drive Motor Controller

![KiCad](https://img.shields.io/badge/Designed_in-KiCad_9.0-blue)
![MCU](https://img.shields.io/badge/MCU-STM32G491RET6-orange)

A compact, highly integrated control board designed specifically for a holonomic drive robot. This custom PCB acts as the central nervous system for motion control, simultaneously driving 4 Brushed DC (BDC) motors with quadrature encoders and 4 Stepper motors. 

Built around the powerful STM32G491 ARM Cortex-M4 microcontroller, it features robust external communication via FDCAN and UART, and is optimized for 2-layer manufacturing.

## Board Renders & Layout
<img width="1315" height="929" alt="image" src="https://github.com/user-attachments/assets/fa8f0d17-b0da-4ab6-a367-4a879c0d5129" />
<img width="1452" height="1001" alt="image" src="https://github.com/user-attachments/assets/dd56e579-7ac6-44aa-899a-ac783c2d8bc3" />
<img width="1478" height="1037" alt="image" src="https://github.com/user-attachments/assets/3371cc4e-0c23-42cd-bda1-992ef2cbe2fd" />

## Key Features
* **Core processing:** STM32G491RET6 microcontroller operating with an external 48MHz crystal oscillator (HSE) for precise timing and CANFD clocking.
* **8-Channel Motor Control:** * **4x BDC Motor Channels:** Outputting PWM, DIR, and GND.
  * **4x Stepper Motor Channels:** Outputting STEP (PWM), SDIR, and GND.
* **Closed-Loop Feedback:** 4x dedicated Encoder inputs providing 5V power, Channel A, Channel B, and GND to track BDC motor odometry.
* **Communication Interfaces:** * **FDCAN:** Integrated TCAN334G transceiver with strictly routed CANH/CANL differential pairs for high-speed, noise-immune system communication.
  * **UART:** Dedicated TX/RX headers (UART4) for debugging or secondary telemetry.
* **Robust Support Circuitry:** Hardware SWD programming header, dedicated RESET button circuit, and a physical SPDT switch for BOOT0 configuration.
* **Form Factor:** Compact footprint utilizing JST XH connectors for all external I/O, designed to standard 2-layer specifications for easy fabrication at Lion Circuits.

## System Architecture

### Power Delivery
The board operates on a 5V logic-level input logic provided by the main system PDB. 
* **5V Rail:** Directly powers the BDC quadrature encoders.
* **3.3V Logic Rail:** An onboard AMS1117-3.3 Low-Dropout (LDO) regulator steps the 5V input down to a clean 3.3V to power the STM32 VDD/VDDA pins and the TCAN334G transceiver. Dedicated 100nF and 4.7µF decoupling capacitors ensure MCU stability.

### I/O & Connector Mapping
All peripheral connections are broken out to securely latching JST XH connectors.

* **Power Input (J1):** `+5V`, `GND`
* **BDC Motors (J5, J7, J9, J13):** `PWM`, `DIR`, `GND`
* **Stepper Motors (J3, J6, J10, J12):** `STEP`, `SDIR`, `GND`
* **Encoders (J2, J8, J11, J14):** `+5V`, `Ch A`, `Ch B`, `GND`
* **Programming (J15):** `+3.3V`, `SWDIO`, `SWCLK`, `GND`
* **FDCAN (J16):** `CANH`, `CANL`, `GND`
* **UART (J17):** `TX`, `RX`, `GND`
* **Expansion GPIO:** 4x broken out male headers for auxiliary sensing.

## Deliverables
This repository contains all necessary files for viewing, editing, and manufacturing the board:
* **`KiCad/`**: Complete KiCad 9.0 project files (Schematic & PCB).
* **`Gerbers/`**: Production-ready Gerber and Drill files formatted for Lion Circuits.
* **`BOM/`**: Complete Bill of Materials including component footprints and designators.
* **`Docs/`**: Schematic PDFs and 3D step files.
