# PHY Algorithm Design & Algorithm-to-Firmware Implementation

This repository presents a wireless PHY/modem algorithm design portfolio focused on OFDM synchronization, 8×8 MIMO-OFDM link-level simulation, and algorithm-to-firmware implementation.

The project demonstrates the full engineering chain from MATLAB-based PHY algorithm modeling to embedded C fixed-point implementation and C++17 firmware-style software design. The portfolio is organized into three connected projects:

1. **OFDM Synchronization Module**
   Timing synchronization, coarse CFO estimation, fine CFO estimation, pilot-aided phase tracking, BER/EVM evaluation, and synchronization impact analysis.

2. **8×8 MIMO-OFDM Link-Level Simulator**
   Channel estimation, LS and Wiener MMSE estimation, ZF/MMSE MIMO equalization, adaptive modulation and coding, convolutional coding/Viterbi decoding, BER, EVM, SINR, throughput, and capacity analysis.

3. **RF Transceiver Algorithm-to-Firmware Implementation**
   Embedded C and C++17 implementation concepts including Q15 fixed-point arithmetic, packed register-map abstraction, RF control state machine, PA/DPD behavioral modeling, channel-estimation implementation, CMake build system, and unit testing.

## Technical Scope

This repository focuses on:

* OFDM receiver synchronization
* Timing offset estimation
* Carrier frequency offset estimation and correction
* Pilot-aided residual CFO/phase tracking
* 8×8 MIMO-OFDM link-level simulation
* 3GPP-inspired multipath channel modeling
* LS and Wiener MMSE channel estimation
* ZF and MMSE MIMO equalization
* Adaptive modulation and coding
* BER, EVM, SINR, throughput, and capacity analysis
* Q15 fixed-point implementation
* Algorithm-to-C/C++ translation
* Register-map abstraction
* RF control state-machine design
* Unit-test-based firmware validation

## Repository Structure

```text
ofdm-synchronization-module/
mimo-ofdm-8x8-link-level-simulator/
rf-transceiver-algorithm-to-firmware/
```

Each project folder contains its own README, source code, algorithm explanation, results summary, and figures.

## Purpose

The purpose of this repository is to demonstrate practical wireless system engineering capability across algorithm design, simulation, implementation, and verification. The work is suitable for portfolio demonstration for roles such as Wireless System Engineer, PHY Algorithm Engineer, RF/PHY System Engineer, Modem Algorithm Engineer, and Algorithm-to-Firmware Engineer.

## Disclaimer

This repository is an educational and portfolio-oriented project. It does not contain confidential company information, proprietary specifications, internal product data, customer data, or company-owned implementation details. All examples are generalized and created for public learning, interview preparation, and engineering portfolio demonstration.
