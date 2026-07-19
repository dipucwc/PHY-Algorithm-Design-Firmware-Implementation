# PHY Algorithm Design & Algorithm-to-Firmware Implementation

![Repository Status](https://img.shields.io/badge/status-ongoing-yellow)
![MATLAB](https://img.shields.io/badge/MATLAB-PHY%20Reference%20Models-blue)
![Python](https://img.shields.io/badge/Python-Cross--Verification-blue)
![C](https://img.shields.io/badge/C-Fixed--Point%20Implementation-green)
![C++](https://img.shields.io/badge/C%2B%2B17-Firmware%20Architecture-green)
![Domain](https://img.shields.io/badge/domain-Wireless%20PHY%20%2F%20DSP-orange)

## Overview

This repository presents an ongoing engineering portfolio focused on **wireless PHY/modem algorithm design, link-level simulation, algorithm verification, and algorithm-to-firmware implementation**.

The repository demonstrates the complete development path from mathematical modeling and floating-point simulation to implementation-oriented C/C++ design:

```text
Wireless-System Requirement
        |
        v
PHY Algorithm Definition
        |
        v
Mathematical Modeling
        |
        v
MATLAB / Python Reference Model
        |
        v
Link-Level Simulation
        |
        v
Performance Verification
        |
        v
Fixed-Point Analysis
        |
        v
Embedded C / C++ Translation
        |
        v
Unit Testing and Firmware Validation
```

The portfolio is organized into three connected but technically distinct projects:

1. A scalable **8×8 and 16×16 MIMO-OFDM PHY simulator**
2. An **RF transceiver algorithm-to-firmware implementation**
3. A focused **OFDM synchronization module**

Together, these projects cover important modem-development areas including:

- synchronization;
- channel estimation;
- MIMO signal processing;
- equalization;
- soft demapping and channel decoding;
- link adaptation;
- fixed-point implementation;
- firmware-oriented software design;
- verification and performance analysis.

> **Development status:** This repository is under active development. Source code, verification tests, figures, documentation, and performance results will be updated as each project progresses.

---

## Repository Objectives

The main objectives of this repository are to demonstrate the ability to:

- Convert wireless-system requirements into PHY algorithm specifications
- Derive mathematical models for transmitter, channel, and receiver processing
- Develop reproducible MATLAB and Python reference implementations
- Evaluate algorithms using BER, BLER, EVM, SINR, NMSE, throughput, and capacity
- Compare alternative receiver algorithms under identical simulation conditions
- Analyze floating-point and fixed-point implementation trade-offs
- Translate selected signal-processing algorithms into embedded C and C++
- Design firmware-oriented modules, state machines, and register interfaces
- Build repeatable unit tests and verification gates
- Document engineering assumptions, limitations, and technical conclusions

---

# Portfolio Projects

## 01 — Scalable 8×8 and 16×16 MIMO-OFDM PHY Simulator

**Folder:**

```text
01-mimo-ofdm-8x8-16x16-phy-simulator/
```

This project develops a configurable link-level simulator for **8×8 and 16×16 MIMO-OFDM systems**.

The purpose is to demonstrate complete PHY/modem receiver processing rather than only one isolated algorithm.

### Main Processing Chain

```text
Information Bits
    |
    v
Channel Encoding
    |
    v
QAM Modulation
    |
    v
Spatial-Layer Mapping
    |
    v
MIMO-OFDM Modulation
    |
    v
Frequency-Selective MIMO Channel
    |
    v
Timing and CFO Synchronization
    |
    v
OFDM Demodulation
    |
    v
Channel Estimation
    |
    v
ZF / MMSE Equalization
    |
    v
Hard / Soft Demapping
    |
    v
Hard / Soft Viterbi Decoding
    |
    v
Link Adaptation and Performance Evaluation
```

### Planned Technical Features

- Configurable 8×8 and 16×16 antenna configurations
- Configurable number of spatial layers
- QPSK, 16-QAM, and 64-QAM
- OFDM modulation and demodulation
- Timing and carrier-frequency-offset impairments
- Pilot-aided channel estimation
- Perfect-CSI reference
- Least-squares channel estimation
- LMMSE or Wiener-MMSE channel estimation
- ZF equalization
- MMSE equalization
- Gain-corrected or unbiased MMSE processing
- Per-layer post-equalization SINR
- Convolutional coding
- Hard-input Viterbi decoding
- Soft-input Viterbi decoding
- Quantized soft-decision analysis
- Adaptive modulation and coding
- BER, BLER, EVM, SINR, throughput, goodput, and capacity
- Spatial-correlation and channel-conditioning analysis
- Reproducible Monte Carlo simulation

### Hard- and Soft-Decision Viterbi Comparison

One important study in this project compares:

1. Uncoded detection
2. Hard-input Viterbi decoding
3. Quantized soft-input Viterbi decoding
4. Floating-point soft-input Viterbi decoding

The hard-decoding path passes only binary decisions to the decoder:

```text
Equalized Symbols
    |
    v
Hard QAM Decisions
    |
    v
Binary Coded Bits
    |
    v
Hard-Input Viterbi Decoder
```

The soft-decoding path preserves bit-confidence information:

```text
Equalized Symbols
    |
    v
Post-Equalization Noise/SINR Estimation
    |
    v
LLR Calculation
    |
    v
Soft-Input Viterbi Decoder
```

The comparison will evaluate:

- coding gain;
- BER and BLER;
- LLR scaling;
- LLR quantization;
- decoder runtime;
- memory requirements;
- performance-versus-complexity trade-offs.

### Link Adaptation

Link adaptation will use estimated channel quality or post-equalization SINR to select an appropriate modulation and coding configuration.

A conceptual processing flow is:

```text
Estimated Post-Equalization SINR
        |
        v
Channel-Quality Mapping
        |
        v
MCS Selection
        |
        +------ QPSK
        +------ 16-QAM
        +------ 64-QAM
        |
        v
BLER and Goodput Evaluation
```

A fixed modulation selected directly from the configured SNR will be treated only as an initial baseline. The final implementation will use receiver-estimated link quality.

### Main Results Planned

- BER versus SNR
- BLER versus SNR
- EVM versus SNR
- Channel-estimation NMSE versus SNR
- ZF versus MMSE equalization
- Hard versus soft Viterbi decoding
- LLR-bit-width versus decoding performance
- Per-layer SINR distribution
- Selected MCS versus channel quality
- Throughput and goodput versus SNR
- Capacity versus SNR
- 8×8 versus 16×16 complexity
- Spatial-correlation impact
- Channel-condition-number impact

### Project Positioning

This project is a general **MIMO-OFDM PHY/modem algorithm simulator**.

It should not be described as a complete 5G NR PDSCH implementation because the convolutional-coding and Viterbi-decoding study is included as a general modem-algorithm comparison. Separate NR-oriented projects can use standardized NR data-channel coding such as LDPC.

---

## 02 — RF Transceiver Algorithm-to-Firmware Implementation

**Folder:**

```text
02-rf-transceiver-algorithm-to-firmware/
```

This project studies how floating-point RF/PHY algorithms can be translated into firmware-oriented C and C++ implementations.

It focuses on the gap between a verified MATLAB or Python algorithm and an implementation that must operate under practical embedded constraints.

### Main Engineering Areas

- Algorithm partitioning
- Floating-point-to-fixed-point conversion
- Q-format selection
- Q15 arithmetic
- Saturation and overflow handling
- Quantization-error analysis
- Fixed-point complex arithmetic
- Embedded C module design
- C++17 firmware architecture
- Hardware register-map abstraction
- Packed data structures
- State-machine-based RF control
- PA and DPD behavioral models
- Channel-estimation implementation concepts
- Runtime configuration
- CMake-based build organization
- Unit testing
- Numerical comparison against reference models

### Algorithm-to-Firmware Workflow

```text
MATLAB / Python Reference Algorithm
        |
        v
Input and Output Range Analysis
        |
        v
Fixed-Point Format Selection
        |
        v
Quantization and Saturation Rules
        |
        v
Embedded C Implementation
        |
        v
C++ Firmware Integration
        |
        v
Register and State-Machine Interface
        |
        v
Unit and Regression Testing
        |
        v
Reference-versus-Firmware Comparison
```

### Q15 Fixed-Point Representation

A signed Q15 value uses one sign bit and fifteen fractional bits.

The real value represented by an integer \(q\) is

\[
x = \frac{q}{2^{15}}.
\]

The approximate representable range is

\[
-1 \leq x \leq 1-2^{-15}.
\]

A Q15 multiplication requires a wider intermediate result:

```c
int16_t q15_multiply(int16_t a, int16_t b)
{
    int32_t product = (int32_t)a * (int32_t)b;
    return (int16_t)(product >> 15);
}
```

The full project will additionally include:

- rounding;
- saturation;
- overflow detection;
- scaling control;
- reference-value comparison.

### Firmware-Oriented Components

The project is expected to contain components such as:

- RF-control state machine
- DPD parameter-selection logic
- PA and DPD behavioral models
- Fixed-point channel-estimation functions
- Fixed-point interpolation
- Fixed-point equalization concepts
- Packed register structures
- Register read/write abstraction
- Configuration validation
- Error and status reporting
- Unit-test executable
- CMake build configuration

### RF Control State Machine

A representative state sequence is:

```text
INIT
  |
  v
LOAD_CONFIGURATION
  |
  v
MEASURE
  |
  v
SELECT_PARAMETERS
  |
  v
APPLY_CONFIGURATION
  |
  v
VALIDATE
  |
  +------ PASS ------> DONE
  |
  +------ FAIL ------> RETUNE
```

### PA and DPD Behavioral Modeling

The project will include implementation-oriented models for:

- nonlinear PA amplitude compression;
- AM/AM behavior;
- polynomial predistortion;
- digital back-off;
- EVM comparison;
- adjacent-channel distortion estimation.

These models are educational behavioral models and are not based on confidential product implementations.

### Verification Focus

The implementation will be checked using:

- floating-point reference vectors;
- fixed-point output vectors;
- maximum absolute error;
- RMS error;
- saturation-event count;
- register-map size verification;
- state-transition tests;
- invalid-input tests;
- deterministic regression tests;
- build and compiler-warning checks.

---

## 03 — OFDM Synchronization Module

**Folder:**

```text
03-ofdm-synchronization-module/
```

This project provides a focused study of synchronization algorithms used before normal OFDM channel estimation, equalization, and symbol detection.

The initial implementation uses a repeated Schmidl–Cox preamble for joint timing and coarse CFO estimation, followed by pilot-aided fine residual-CFO estimation.

### Main Synchronization Chain

```text
Received Time-Domain Samples
        |
        v
Repeated-Preamble Correlation
        |
        v
Timing Metric
        |
        v
Frame-Start Estimation
        |
        v
Coarse CFO Estimation
        |
        v
Time-Domain CFO Correction
        |
        v
CP Removal and FFT
        |
        v
Pilot-Based Fine CFO Estimation
        |
        v
Residual Phase Correction
        |
        v
BER / EVM / RMSE Analysis
```

### Technical Scope

- Schmidl–Cox preamble generation
- Timing-correlation metric
- Energy-normalized timing detection
- Timing-plateau analysis
- Frame-start detection
- Coarse normalized-CFO estimation
- Positive and negative CFO verification
- CFO phase-wrapping analysis
- Time-domain CFO compensation
- Pilot-aided fine-CFO estimation
- Residual phase tracking
- AWGN and multipath evaluation
- Timing RMSE
- CFO RMSE
- Detection probability
- Missed-detection probability
- False-alarm probability
- BER and EVM impact
- Fixed-point implementation planning

### Project Positioning

This project currently implements a **generic OFDM synchronization method**.

It is not presented as a complete 5G NR synchronization implementation.

A complete NR synchronization project would additionally require:

- synchronization signal block processing;
- PSS detection;
- SSS detection;
- physical-cell-identity detection;
- PBCH and PBCH-DMRS processing;
- SS/PBCH timing;
- NR numerology;
- beam-sweeping and beam-selection considerations.

The focused synchronization project is intentionally retained separately from the complete MIMO-OFDM simulator. In the full simulator, synchronization is one integrated receiver block. In this project, synchronization algorithms are investigated in greater depth.

---

# Relationship Between the Projects

The three projects are connected but do not have the same purpose.

| Project | Main purpose | Main implementation level |
|---|---|---|
| 01 — MIMO-OFDM PHY Simulator | Complete modem and link-level processing | MATLAB/Python system simulation |
| 02 — Algorithm-to-Firmware | Translation into implementation-oriented software | Embedded C and C++17 |
| 03 — OFDM Synchronization | Detailed synchronization-algorithm analysis | MATLAB/Python algorithm study |

The relationship can be represented as:

```text
03 — Synchronization Algorithm Study
                |
                v
01 — Complete MIMO-OFDM PHY Simulator
                |
                v
02 — Algorithm-to-Firmware Translation
```

Project 03 develops and verifies synchronization algorithms in isolation.

Project 01 integrates synchronization with channel estimation, MIMO equalization, decoding, and link adaptation.

Project 02 translates selected algorithms and control functions into fixed-point and firmware-oriented implementations.

---

# Technical Scope

This repository covers the following engineering topics.

## OFDM Processing

- QAM mapping and demapping
- IFFT and FFT processing
- Cyclic-prefix insertion and removal
- Resource and pilot mapping
- Timing-offset modeling
- CFO modeling
- Sampling and phase-error concepts
- Frequency-selective channel response

## Synchronization

- Frame-start detection
- Symbol-timing estimation
- Coarse CFO estimation
- Fine residual-CFO estimation
- CFO correction
- Phase tracking
- Synchronization-failure detection
- Timing and CFO RMSE

## Channel Estimation

- Perfect-CSI reference
- LS estimation
- Frequency interpolation
- LMMSE estimation
- Wiener-filter-based estimation
- Pilot-density analysis
- Channel-estimation NMSE

## MIMO Processing

- 8×8 and 16×16 MIMO
- Configurable spatial layers
- Spatial multiplexing
- MIMO channel matrices
- Channel singular values
- Condition-number analysis
- Spatial correlation
- Per-layer SINR
- Capacity analysis

## Equalization

- Zero-Forcing equalization
- MMSE equalization
- Gain correction
- Noise enhancement
- Residual inter-layer interference
- EVM and SINR comparison

## Channel Coding and Decoding

- Convolutional encoding
- Hard-input Viterbi decoding
- Soft-input Viterbi decoding
- LLR generation
- Post-equalization LLR scaling
- Quantized soft metrics
- Coding-gain analysis
- Runtime and memory trade-offs

## Link Adaptation

- Channel-quality estimation
- Post-equalization SINR
- MCS selection
- QPSK, 16-QAM, and 64-QAM
- Coding-rate selection
- BLER-target-based adaptation
- Throughput and goodput

## Firmware and Fixed Point

- Q-format selection
- Q15 arithmetic
- Fixed-point complex operations
- Scaling and saturation
- Register-map abstraction
- Embedded state machines
- C/C++ module design
- CMake
- Unit testing
- Reference-vector validation

---

# Performance Metrics

The projects use or plan to use the following metrics:

- Bit error rate
- Block or frame error rate
- Error vector magnitude
- Channel-estimation NMSE
- Timing-estimation error
- Timing RMSE
- CFO-estimation error
- CFO RMSE
- Post-equalization SINR
- Throughput
- Goodput
- Spectral efficiency
- MIMO capacity
- Synchronization-detection probability
- Runtime
- Memory use
- Quantization error
- Saturation count

For BER and BLER simulations, the result files will record:

- total transmitted information bits;
- total bit errors;
- total transmitted blocks;
- total failed blocks;
- number of Monte Carlo trials;
- configuration;
- random seed;
- confidence intervals where appropriate.

When no errors are observed, results will be reported as:

```text
Zero errors observed over N evaluated bits or blocks
```

rather than claiming that the true error probability is exactly zero.

---

# Verification Methodology

The repository follows a verification-first development approach.

## Reference Verification

- Constellation-power verification
- Modulation and demodulation round trip
- OFDM modulation and demodulation round trip
- Channel impulse-response verification
- Noise-power calibration
- Timing-estimator sign and offset checks
- CFO-estimator sign checks
- CFO compensation checks
- Channel-estimation noiseless tests
- Equalizer noiseless tests
- Encoder and decoder round trip
- Reproducibility checks

## Fair Algorithm Comparison

Algorithms will be compared using identical:

- source bits;
- modulation symbols;
- channel realization;
- synchronization impairments;
- pilot symbols;
- noise samples;
- random seeds;
- SNR definition;
- normalization;
- stopping criteria.

Only the algorithm under investigation will be changed.

For example, hard- and soft-input Viterbi decoding will use the same equalized symbols. This isolates the value of the reliability information supplied to the decoder.

## MATLAB–Python Verification

Where both implementations are available, MATLAB and Python will use:

- shared configuration parameters;
- identical mathematical definitions;
- deterministic seeds;
- shared input vectors where required;
- intermediate-value comparison;
- common metric definitions;
- numerical tolerances.

## Reference-versus-Firmware Verification

Fixed-point C/C++ implementations will be checked against floating-point reference outputs using:

- sample-level comparison;
- tolerance-based tests;
- RMS error;
- maximum absolute error;
- overflow and saturation monitoring;
- deterministic regression vectors.

---

# Repository Structure

```text
PHY-Algorithm-Design-Firmware-Implementation/
|
├── README.md
|
├── 01-mimo-ofdm-8x8-16x16-phy-simulator/
│   ├── README.md
│   ├── matlab/
│   ├── python/
│   ├── cpp/
│   ├── configs/
│   ├── tests/
│   ├── results/
│   ├── figures/
│   └── docs/
|
├── 02-rf-transceiver-algorithm-to-firmware/
│   ├── README.md
│   ├── embedded-c/
│   ├── cpp17/
│   ├── fixed-point/
│   ├── reference-vectors/
│   ├── tests/
│   ├── results/
│   └── docs/
|
└── 03-ofdm-synchronization-module/
    ├── README.md
    ├── matlab/
    ├── python/
    ├── cpp/
    ├── configs/
    ├── tests/
    ├── results/
    ├── figures/
    └── docs/
```

The internal folder structure may be refined as the projects are modularized.

Each project folder will contain its own:

- technical overview;
- mathematical model;
- algorithm workflow;
- source code;
- configuration files;
- verification tests;
- simulation results;
- figures;
- development roadmap;
- limitations;
- running instructions.

---

# Project Status

| Project | Current status | Next major work |
|---|---|---|
| 01 — 8×8/16×16 MIMO-OFDM PHY Simulator | Ongoing | Modular simulator, hard/soft Viterbi comparison, AMC verification |
| 02 — RF Transceiver Algorithm-to-Firmware | Ongoing | Fixed-point validation, C/C++ integration, extended unit tests |
| 03 — OFDM Synchronization Module | Ongoing | Modular MATLAB implementation, RMSE analysis, verification gates |

## Repository-Level Development Status

| Work area | Status |
|---|---|
| Repository organization | Complete |
| Project definitions | Complete |
| Mathematical-model documentation | In progress |
| MATLAB reference implementations | In progress |
| Python reference implementations | Planned / in progress |
| Hard- and soft-decoding comparison | Planned |
| Fixed-point analysis | In progress |
| Embedded C implementation | In progress |
| C++17 firmware structure | In progress |
| Verification tests | In progress |
| Final simulation figures | Planned |
| MATLAB–Python cross-verification | Planned |
| Technical reports | Planned |

No preliminary result will be presented as a final verified result until it is reproduced by the released implementation and stored result files.

---

# Development Roadmap

## Phase 1 — Repository and Model Definition

- [x] Define the three-project portfolio structure
- [x] Separate system-level, focused-algorithm, and firmware projects
- [x] Define the primary technical scope
- [x] Add project-specific README files
- [ ] Complete mathematical-model documentation

## Phase 2 — MATLAB Reference Models

- [ ] Complete modular synchronization implementation
- [ ] Complete configurable 8×8 and 16×16 MIMO simulation
- [ ] Complete LS and LMMSE channel estimation
- [ ] Complete ZF and MMSE equalization
- [ ] Complete hard-input Viterbi path
- [ ] Complete soft-input Viterbi path
- [ ] Add SINR-based link adaptation

## Phase 3 — Verification

- [ ] Add deterministic random-seed handling
- [ ] Add algorithm unit tests
- [ ] Add noiseless verification gates
- [ ] Add SNR and noise-power checks
- [ ] Add positive and negative CFO tests
- [ ] Add decoder-input-sign tests
- [ ] Add result reproducibility tests
- [ ] Add statistical confidence reporting

## Phase 4 — Python Cross-Verification

- [ ] Mirror the MATLAB signal chain
- [ ] Share configuration files
- [ ] Compare intermediate arrays
- [ ] Compare final metrics
- [ ] Record numerical tolerances
- [ ] Publish cross-verification logs

## Phase 5 — Fixed-Point and Firmware Implementation

- [ ] Define numerical ranges
- [ ] Select Q formats
- [ ] Add quantized LLR analysis
- [ ] Implement selected algorithms in embedded C
- [ ] Develop C++17 firmware modules
- [ ] Add register-map abstraction
- [ ] Add state-machine validation
- [ ] Add CMake and CTest integration
- [ ] Compare firmware and reference outputs

## Phase 6 — Documentation and Release

- [ ] Add final figures
- [ ] Add raw CSV/MAT results
- [ ] Add implementation notes
- [ ] Add complexity analysis
- [ ] Add technical reports
- [ ] Add stable release tags
- [ ] Add project license

---

# Skills Demonstrated

This repository is designed to demonstrate practical capability in:

## Wireless and PHY Algorithms

- OFDM
- MIMO
- Synchronization
- Channel estimation
- Equalization
- Channel coding
- Soft demapping
- Link adaptation
- Performance analysis

## Mathematical and Simulation Work

- Signal modeling
- Complex baseband processing
- Probability and noise modeling
- Monte Carlo simulation
- Matrix operations
- Numerical validation
- Algorithm comparison
- Reproducible experiments

## Implementation

- MATLAB
- Python
- Embedded C
- C++17
- Fixed-point arithmetic
- CMake
- Unit testing
- Modular software architecture

## Engineering Workflow

- Requirement interpretation
- Algorithm specification
- Verification planning
- Interface definition
- Performance-versus-complexity analysis
- Floating-point-to-fixed-point translation
- Firmware-oriented design
- Technical documentation

---

# Relevance to Engineering Roles

The repository is intended as portfolio evidence for positions such as:

- Wireless System Engineer
- PHY Algorithm Engineer
- Modem Algorithm Engineer
- DSP Engineer
- Baseband Engineer
- RF/PHY System Engineer
- Wireless Simulation Engineer
- Algorithm Implementation Engineer
- Embedded DSP Engineer
- Algorithm-to-Firmware Engineer

It is particularly relevant to roles requiring experience in:

- synchronization;
- channel estimation;
- MIMO;
- equalization;
- link adaptation;
- MATLAB/Python modeling;
- C/C++ implementation;
- fixed-point analysis;
- firmware and hardware collaboration.

---

# Tools and Technologies

| Area | Tools and technologies |
|---|---|
| PHY reference modeling | MATLAB |
| Independent verification | Python, NumPy, SciPy |
| Data and result handling | MAT, CSV, JSON |
| Embedded implementation | C |
| Firmware architecture | C++17 |
| Build system | CMake |
| Testing | MATLAB tests, Python tests, C/C++ unit tests, CTest |
| Version control | Git and GitHub |
| Documentation | Markdown, technical reports, diagrams |
| Performance analysis | BER, BLER, EVM, SINR, NMSE, throughput, capacity |

---

# Important Technical Clarifications

## Generic OFDM Versus Complete 5G NR

The repository contains several algorithms that are relevant to modern OFDM-based wireless systems. However, a generic OFDM implementation is not automatically a complete 5G NR implementation.

For example:

- Schmidl–Cox synchronization is used as a generic OFDM synchronization study.
- Convolutional coding and Viterbi decoding are used to study hard- and soft-decoder behavior.
- A complete NR PDSCH data chain would require NR-specific resource mapping, reference signals, LDPC coding, rate matching, and other standardized procedures.

The repository therefore avoids describing generic algorithms as complete 5G NR implementations unless the required standardized processing is actually included.

## Educational Models Versus Product Implementations

PA, DPD, RF control, register, and firmware examples are simplified public engineering models created for learning and portfolio demonstration.

They are not copies of commercial radio-product implementations.

---

# Documentation Principles

The repository follows these documentation rules:

- Clearly state whether a feature is implemented, in progress, or planned
- Separate measured results from expected behavior
- Avoid unsupported performance claims
- Document signal normalization and SNR definitions
- Explain every major algorithm mathematically
- Describe important variables and assumptions
- Preserve reproducibility using saved configurations and seeds
- Include verification tests before accepting final results
- Report limitations and known gaps
- Keep public portfolio material independent of confidential work

---

# Disclaimer

This repository is an independent educational and portfolio-oriented engineering project.

It does not contain:

- confidential employer information;
- proprietary company specifications;
- internal source code;
- internal hardware descriptions;
- customer information;
- product-specific register definitions;
- non-public measurement data;
- restricted documentation.

All algorithms, models, interfaces, test data, and implementation examples are generalized and created for public learning, technical demonstration, interview preparation, and engineering portfolio development.

References to wireless standards, technologies, employers, or commercial systems are included only to explain general engineering context and do not imply access to or reproduction of proprietary implementations.

---

# Author

**Md Moklesur Rahman**

Wireless/RF/PHY System Engineer focused on:

- 5G/6G wireless systems
- RF and PHY algorithm specification
- OFDM and massive MIMO
- Synchronization and timing
- Channel estimation and equalization
- Beamforming and beamforming calibration
- MATLAB and Python simulation
- C/C++ implementation concepts
- Embedded RF calibration and validation workflows

---

# License

A formal license will be added before the first stable public release.

Until a license is included, the repository should be treated as publicly viewable portfolio material without an implied right to copy, modify, redistribute, or reuse the source code.
