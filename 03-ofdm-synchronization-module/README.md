# OFDM Synchronization Module

![Project Status](https://img.shields.io/badge/status-ongoing-yellow)
![Primary Language](https://img.shields.io/badge/MATLAB-primary-blue)
![Python](https://img.shields.io/badge/Python-planned-lightgrey)
![C/C++](https://img.shields.io/badge/C%2FC%2B%2B-planned-lightgrey)
![Domain](https://img.shields.io/badge/domain-OFDM%20PHY%20Synchronization-green)

## Project Overview

This ongoing project develops and evaluates a complete synchronization chain for an OFDM physical-layer receiver.

The project focuses on the receiver operations that must be completed before reliable OFDM demodulation, channel estimation, equalization, and data detection can be performed:

- OFDM frame-start detection
- Symbol-timing-offset estimation
- Coarse carrier-frequency-offset estimation
- Fine residual-CFO estimation
- Time-domain CFO compensation
- FFT-window alignment
- Synchronization-performance verification
- BER and EVM comparison before and after synchronization

The initial implementation uses a Schmidl–Cox repeated-preamble method for joint timing and coarse CFO estimation. A pilot-based fine-CFO estimator is then applied to reduce the remaining phase rotation between consecutive OFDM symbols.

The project is intended to demonstrate hands-on PHY/modem algorithm design, mathematical modeling, MATLAB implementation, Monte Carlo simulation, performance analysis, and future algorithm-to-firmware translation.

> **Project status:** The project is under active development. Algorithms, source-code organization, verification tests, figures, and technical documentation will be updated as implementation and validation progress.

---

## Project Scope

The synchronization receiver is organized as:

```text
Received Time-Domain Samples
        |
        v
Schmidl-Cox Timing Metric
        |
        v
Frame-Start / Symbol-Timing Estimation
        |
        v
Coarse CFO Estimation
        |
        v
Time-Domain Coarse CFO Compensation
        |
        v
Cyclic-Prefix Removal and FFT
        |
        v
Pilot-Based Fine CFO Estimation
        |
        v
Residual CFO Compensation
        |
        v
Channel Estimation and Equalization
        |
        v
Symbol Detection
        |
        v
BER, EVM, Timing RMSE, and CFO RMSE
```

The primary comparisons are:

1. Perfect synchronization reference
2. Receiver without synchronization correction
3. Timing and coarse-CFO correction only
4. Timing, coarse-CFO, and fine-CFO correction
5. Performance under AWGN and multipath fading

---

## Motivation

OFDM depends on orthogonality between closely spaced subcarriers. Timing and frequency errors disturb this orthogonality and degrade receiver performance.

A symbol-timing error can cause:

- Incorrect FFT-window placement
- Inter-symbol interference
- Phase rotation across subcarriers
- Channel-estimation errors
- Increased EVM
- Increased BER

Carrier-frequency offset can cause:

- Common phase rotation
- Inter-carrier interference
- Loss of subcarrier orthogonality
- Pilot-phase drift
- Increased EVM
- A high-SNR BER floor

Because synchronization is performed before normal data detection, synchronization errors cannot always be removed by channel equalization alone.

This project therefore studies synchronization as a separate receiver-algorithm problem rather than treating timing and CFO correction as ideal operations.

---

## Current Technical Configuration

The initial simulation configuration is shown below.

| Parameter | Initial value |
|---|---:|
| Waveform | OFDM |
| FFT size | 256 |
| Cyclic-prefix length | 20 samples |
| Modulation | 16-QAM |
| Preamble | Repeated-half Schmidl–Cox structure |
| Pilot spacing | One pilot every 8 subcarriers |
| Data symbols per frame | 8 |
| Normalized CFO | Configurable; initial value 0.25 |
| SNR range | 0 to 30 dB |
| SNR step | 2 dB |
| Channel models | AWGN and multipath fading |
| Monte Carlo trials | Configurable |
| Primary implementation | MATLAB |
| Python implementation | Planned |
| Fixed-point C/C++ study | Planned |

The normalized CFO is defined relative to the OFDM subcarrier spacing:
```math
$$
\epsilon = \frac{\Delta f_{\mathrm{CFO}}}{\Delta f_{\mathrm{SC}}}
$$

Therefore,

$$
\Delta f_{\mathrm{CFO}}
=
\epsilon \Delta f_{\mathrm{SC}}
$$

For example, when

$$
\epsilon = 0.25
$$

and

$$
\Delta f_{\mathrm{SC}}=15\text{ kHz},
$$

the physical CFO is

$$
\Delta f_{\mathrm{CFO}}
=
0.25 \times 15\text{ kHz}
=
3.75\text{ kHz}.
$$

---

## Signal Model
```math
Let:

- \(N\) be the FFT size
- \(N_{\mathrm{CP}}\) be the cyclic-prefix length
- \(d_0\) be the receiver timing offset
- \(\epsilon\) be the CFO normalized by the subcarrier spacing
- \(h[\ell]\) be the discrete-time multipath-channel impulse response
- \(x[n]\) be the transmitted OFDM waveform
- \(w[n]\) be complex additive white Gaussian noise

The received time-domain signal is modeled as

$$
r[n]
=
e^{j2\pi \epsilon n/N}
\sum_{\ell=0}^{L_h-1}
h[\ell]x[n-d_0-\ell]
+
w[n].
$$

The exponential term represents the CFO-induced sample-by-sample phase rotation.

When \(\epsilon\neq 0\), the FFT output no longer contains perfectly orthogonal subcarriers. The resulting inter-carrier interference increases as the normalized CFO increases.

---

## Schmidl–Cox Preamble

The synchronization preamble is constructed so that its two time-domain halves are identical:

$$
s[n+L]=s[n],
\qquad
0\leq n<L,
$$

where

$$
L=\frac{N}{2}.
$$

One method of producing the repeated structure is to populate only alternating frequency-domain subcarriers before performing the IFFT.

The repeated halves allow the receiver to estimate both:

- the start of the OFDM preamble;
- the phase rotation between the two halves.

---

## Timing Synchronization

### Half-Symbol Correlation

For each candidate sample position \(d\), the receiver computes
```math
$$
P(d)
=
\sum_{n=0}^{L-1}
r^{*}[d+n]r[d+n+L].
$$

Here:

- \(P(d)\) is the complex correlation between the two received preamble halves;
- \((\cdot)^{*}\) denotes complex conjugation;
- \(L=N/2\).

When the observation window is aligned with the repeated preamble, the magnitude of \(P(d)\) becomes large.
```
### Energy Normalization

The energy of the second half is estimated as
```math
$$
R(d)
=
\sum_{n=0}^{L-1}
\left|r[d+n+L]\right|^2.
$$

### Normalized Timing Metric

The timing metric is

$$
M(d)
=
\frac{|P(d)|^2}
{\left(R(d)+\delta\right)^2},
$$

where \(\delta\) is a small positive value used to prevent division by zero.

The baseline timing estimate is

$$
\hat{d}
=
\arg\max_d M(d).
$$
```
The normalized metric reduces sensitivity to received-signal amplitude.

### Plateau Consideration

A repeated-half Schmidl–Cox preamble can produce a timing plateau rather than a single sharp peak. Therefore, later project stages will compare:

- maximum-metric timing selection;
- threshold-based plateau detection;
- first-path or plateau-edge selection;
- peak-to-average metric tests;
- alternative preambles with sharper timing metrics.

---

## Coarse CFO Estimation
```math
The phase of \(P(d)\) represents the phase difference accumulated between the repeated preamble halves.

For a half-symbol separation \(L=N/2\),

$$
\angle P(\hat{d})
\approx
\pi\epsilon.
$$

The normalized coarse CFO estimate is therefore

$$
\hat{\epsilon}_{\mathrm{coarse}}
=
\frac{\angle P(\hat{d})}{\pi}.
$$

The received signal is corrected in the time domain using

$$
r_{\mathrm{coarse}}[n]
=
r[n]
e^{-j2\pi
\hat{\epsilon}_{\mathrm{coarse}}n/N}.
$$

The residual CFO after coarse compensation is

$$
\epsilon_{\mathrm{residual}}
=
\epsilon
-
\hat{\epsilon}_{\mathrm{coarse}}.
$$

The coarse estimator provides a limited unambiguous estimation range because the measured correlation phase is wrapped to a principal interval.

---

## Fine CFO Estimation

After coarse CFO correction, a small residual CFO can remain because of:

- receiver noise;
- multipath distortion;
- timing-estimation error;
- phase wrapping;
- finite preamble length;
- numerical estimation error.

The residual CFO produces progressive phase rotation between OFDM symbols.

Let the LS pilot-domain channel estimates from two consecutive OFDM symbols be
```math
$$
\hat{H}_m[k]
=
\frac{Y_m[k]}{X_m[k]}
$$

and

$$
\hat{H}_{m+1}[k]
=
\frac{Y_{m+1}[k]}{X_{m+1}[k]}.
$$

The average pilot-phase change is estimated by

$$
\Delta\hat{\phi}
=
\angle
\left(
\sum_{k\in\mathcal{P}}
\hat{H}_{m+1}[k]
\hat{H}_m^{*}[k]
\right),
$$

where \(\mathcal{P}\) is the pilot-subcarrier set.

For two adjacent OFDM symbols, the normalized fine-CFO estimate is

$$
\hat{\epsilon}_{\mathrm{fine}}
=
\frac{
\Delta\hat{\phi}N
}{
2\pi(N+N_{\mathrm{CP}})
}.
$$

The total CFO estimate is

$$
\hat{\epsilon}_{\mathrm{total}}
=
\hat{\epsilon}_{\mathrm{coarse}}
+
\hat{\epsilon}_{\mathrm{fine}}.
$$

The final time-domain compensation is

$$
r_{\mathrm{corrected}}[n]
=
r[n]
e^{-j2\pi
\hat{\epsilon}_{\mathrm{total}}n/N}.
$$
```
---

## Receiver Processing Stages

The planned receiver contains the following stages.

### 1. Sample Acquisition

The receiver obtains a time-domain sample buffer containing:

- an unknown frame-start position;
- preamble samples;
- cyclic-prefix samples;
- OFDM data symbols;
- timing offset;
- CFO;
- multipath distortion;
- receiver noise.

### 2. Timing-Metric Computation

The Schmidl–Cox metric is evaluated over a configurable search interval.

The implementation will use vectorized or cumulative-sum operations where practical to reduce repeated computation.

### 3. Frame-Start Detection

The receiver identifies the synchronization-preamble region and selects the FFT-window start.

The detector will later include:

- detection threshold;
- valid search window;
- false-alarm handling;
- missed-detection handling;
- plateau handling.

### 4. Coarse CFO Estimation

The receiver estimates CFO from the phase of the repeated-half correlation.

### 5. Coarse CFO Compensation

The estimated phase ramp is removed from the complete received frame.

### 6. OFDM Demodulation

The receiver removes the cyclic prefix and applies the FFT.

### 7. Fine CFO Estimation

Pilot symbols from adjacent OFDM symbols are used to estimate the remaining phase drift.

### 8. Fine CFO Compensation

The residual CFO is removed before final channel estimation, equalization, and symbol detection.

### 9. Performance Measurement

The receiver computes:

- timing-estimation error;
- coarse-CFO estimation error;
- residual-CFO error;
- CFO RMSE;
- timing RMSE;
- BER;
- EVM;
- synchronization-detection probability;
- missed-detection probability;
- false-alarm probability.

---

## Performance Metrics

### Timing Error

For true timing offset \(d_0\) and estimated offset \(\hat{d}\),

$$
e_d
=
\hat{d}-d_0.
$$

The timing RMSE is

$$
\mathrm{RMSE}_{d}
=
\sqrt{
\frac{1}{N_{\mathrm{trial}}}
\sum_{i=1}^{N_{\mathrm{trial}}}
\left(
\hat{d}_i-d_{0,i}
\right)^2
}.
$$

Because an OFDM receiver may tolerate more than one valid FFT-window position inside the cyclic prefix, both exact-sample error and valid-window detection will be reported.

### CFO Error

The normalized CFO-estimation error is

$$
e_{\epsilon}
=
\hat{\epsilon}-\epsilon.
$$

The CFO RMSE is

$$
\mathrm{RMSE}_{\epsilon}
=
\sqrt{
\frac{1}{N_{\mathrm{trial}}}
\sum_{i=1}^{N_{\mathrm{trial}}}
\left(
\hat{\epsilon}_i-\epsilon_i
\right)^2
}.
$$

The corresponding physical-frequency error is

$$
e_f
=
e_{\epsilon}
\Delta f_{\mathrm{SC}}.
$$

### Error Vector Magnitude

The RMS EVM is calculated as

$$
\mathrm{EVM}_{\mathrm{RMS}}
=
\sqrt{
\frac{
\sum_{k}
|\hat{X}[k]-X[k]|^2
}{
\sum_{k}
|X[k]|^2
}
}.
$$

The percentage EVM is

$$
\mathrm{EVM}_{\%}
=
100
\times
\mathrm{EVM}_{\mathrm{RMS}}.
$$

### Bit Error Rate

The BER is

$$
\mathrm{BER}
=
\frac{N_{\mathrm{bit,error}}}
{N_{\mathrm{bit,total}}}.
$$

When no bit errors are observed, the result will be reported as:

```text
Zero errors observed over N evaluated bits
```

rather than claiming that the true BER is exactly zero.

### Synchronization-Detection Probability

The successful-detection probability is

$$
P_{\mathrm{detect}}
=
\frac{
N_{\mathrm{successful\ detections}}
}{
N_{\mathrm{trials}}
}.
$$

A successful detection must satisfy a configurable valid timing-window requirement.

---

## Planned Simulation Cases

### Case 1: Ideal Reference

- Perfect frame timing
- Zero CFO
- Known FFT-window position
- AWGN channel
- Baseline BER and EVM

### Case 2: Timing Offset Only

- Random frame-start offset
- Zero CFO
- AWGN channel
- Timing-estimation accuracy analysis

### Case 3: CFO Only

- Perfect timing
- Configurable normalized CFO
- Coarse CFO estimation
- Fine CFO estimation
- Residual-CFO analysis

### Case 4: Joint Timing and CFO

- Random timing offset
- Configurable CFO
- AWGN channel
- Complete synchronization chain

### Case 5: Multipath Channel

- Timing offset
- CFO
- Frequency-selective multipath fading
- Timing-plateau and first-path analysis

### Case 6: Low-SNR Detection

- Random noise realizations
- Timing-metric threshold analysis
- Missed-detection probability
- False-alarm probability

### Case 7: CFO Capture Range

- CFO sweep across positive and negative offsets
- Phase-wrapping analysis
- Coarse-estimator capture-range verification

### Case 8: Residual Phase Tracking

- Small residual CFO
- Pilot-based fine correction
- Multiple OFDM data symbols
- Phase-drift analysis

---

## Planned Figures

The completed project is expected to generate the following figures:

1. Transmitted Schmidl–Cox preamble
2. Received waveform with timing offset
3. Schmidl–Cox timing metric
4. Detected frame-start position
5. Timing error versus SNR
6. Timing RMSE versus SNR
7. Coarse CFO estimate versus true CFO
8. Coarse CFO RMSE versus SNR
9. Coarse-only versus coarse-plus-fine CFO RMSE
10. Residual CFO versus SNR
11. BER without synchronization
12. BER with coarse synchronization
13. BER with complete synchronization
14. Perfect-sync versus estimated-sync BER
15. EVM versus SNR
16. Synchronization-detection probability versus SNR
17. CFO-estimator capture range
18. Runtime and algorithm-complexity comparison

---

## Fair Comparison Methodology

All synchronization methods will use the same:

- transmitted data;
- preamble;
- channel realization;
- timing offset;
- CFO value;
- receiver-noise samples;
- pilot symbols;
- modulation settings;
- random seed.

Only the selected synchronization method will change.

This shared-input approach ensures that performance differences are caused by the synchronization algorithms rather than different random test conditions.

---

## Verification Plan

The implementation will include the following verification gates.

### Gate 1: OFDM Round Trip

Verify that OFDM modulation followed by ideal OFDM demodulation reconstructs the input symbols in the absence of channel impairments.

### Gate 2: Timing-Only Recovery

Apply a known timing offset with zero CFO and verify that the timing detector identifies a valid FFT-window position.

### Gate 3: CFO-Only Recovery

Apply a known normalized CFO with perfect timing and verify that the CFO estimator returns the expected value in a noiseless channel.

### Gate 4: CFO Compensation Sign

Verify that CFO compensation reduces phase rotation rather than doubling it.

### Gate 5: Positive and Negative CFO

Test equal-magnitude positive and negative CFO values to verify estimator sign consistency.

### Gate 6: Phase-Wrapping Boundary

Evaluate CFO values close to the coarse estimator's unambiguous range.

### Gate 7: Multipath Robustness

Verify timing and CFO estimation when delayed multipath components are present.

### Gate 8: Reproducibility

Verify that the same configuration and random seed reproduce identical results.

### Gate 9: Statistical Reporting

Store for every SNR point:

- number of Monte Carlo trials;
- total evaluated bits;
- total bit errors;
- timing failures;
- CFO-estimation errors;
- mean EVM;
- confidence intervals where applicable.

---

## Expected Technical Analysis

The final report will examine:

- Why CFO creates inter-carrier interference
- Why equalization alone cannot fully remove CFO
- Why the Schmidl–Cox metric produces a plateau
- Timing accuracy versus detection reliability
- Coarse-CFO capture range
- Noise sensitivity of correlation-phase estimation
- Pilot density versus fine-CFO accuracy
- Multipath impact on frame-start detection
- Residual CFO impact on BER and EVM
- Synchronization performance versus computational complexity
- Floating-point versus fixed-point implementation considerations

No numerical performance claim will be marked as final until it is reproduced by the released code and stored simulation results.

---

## Suggested Project Structure

```text
03-ofdm-synchronization-module/
|
├── README.md
├── LICENSE
|
├── matlab/
│   ├── ofdm_synchronization.m
│   ├── config_sync.m
│   ├── generate_sync_preamble.m
│   ├── schmidl_cox_metric.m
│   ├── estimate_timing_offset.m
│   ├── estimate_coarse_cfo.m
│   ├── estimate_fine_cfo.m
│   ├── apply_cfo_correction.m
│   ├── ofdm_modulate.m
│   ├── ofdm_demodulate.m
│   ├── apply_sync_impairments.m
│   ├── compute_sync_metrics.m
│   ├── run_sync_monte_carlo.m
│   └── plot_sync_results.m
|
├── python/
│   ├── README.md
│   └── planned_implementation.md
|
├── cpp/
│   ├── README.md
│   └── planned_fixed_point_implementation.md
|
├── tests/
│   ├── test_ofdm_round_trip.m
│   ├── test_timing_estimator.m
│   ├── test_cfo_estimator.m
│   ├── test_cfo_correction_sign.m
│   └── test_reproducibility.m
|
├── configs/
│   ├── default_sync_config.m
│   ├── awgn_config.m
│   └── multipath_config.m
|
├── results/
│   ├── csv/
│   ├── logs/
│   └── mat/
|
├── figures/
|
└── docs/
    ├── mathematical_model.md
    ├── algorithm_workflow.md
    └── verification_plan.md
```

The exact structure may change as the implementation is modularized.

---

## Running the MATLAB Baseline

The initial MATLAB implementation can be executed using:

```matlab
run('ofdm_synchronization.m');
```

Before running:

1. Open MATLAB.
2. Set the project folder as the current working directory.
3. Add the MATLAB source folder to the path if required.
4. Review the configuration parameters.
5. Run the main synchronization script.
6. Check the generated figures, result tables, and console verification messages.

A future version will provide a single configuration-driven entry point such as:

```matlab
cfg = config_sync();
results = run_sync_monte_carlo(cfg);
plot_sync_results(results, cfg);
```

---

## Development Roadmap

### Phase 1 — Mathematical Model

- [x] Define OFDM signal model
- [x] Define timing-offset impairment
- [x] Define normalized-CFO impairment
- [x] Derive Schmidl–Cox timing metric
- [x] Derive coarse-CFO estimator
- [x] Define pilot-based fine-CFO estimator

### Phase 2 — MATLAB Baseline

- [ ] Finalize configuration structure
- [ ] Modularize preamble generation
- [ ] Modularize timing estimation
- [ ] Modularize coarse-CFO estimation
- [ ] Modularize fine-CFO estimation
- [ ] Add AWGN and multipath-channel options
- [ ] Add deterministic random-seed control

### Phase 3 — Verification

- [ ] Add OFDM round-trip test
- [ ] Add timing-only test
- [ ] Add CFO-only test
- [ ] Add positive and negative CFO tests
- [ ] Add CFO compensation-sign test
- [ ] Add phase-wrapping test
- [ ] Add multipath test
- [ ] Add reproducibility test

### Phase 4 — Performance Analysis

- [ ] Generate timing RMSE curves
- [ ] Generate coarse-CFO RMSE curves
- [ ] Generate fine-CFO RMSE curves
- [ ] Compare no-sync, coarse-sync, and complete-sync BER
- [ ] Compare EVM before and after synchronization
- [ ] Measure detection and false-alarm probabilities
- [ ] Add confidence intervals
- [ ] Save raw results to CSV and MAT files

### Phase 5 — Advanced Algorithm Study

- [ ] Add plateau-edge timing detection
- [ ] Compare alternative timing metrics
- [ ] Add sampling-frequency-offset model
- [ ] Add common-phase-error tracking
- [ ] Add oscillator phase-noise model
- [ ] Add Doppler and time-varying channels
- [ ] Add interference and adjacent-signal cases

### Phase 6 — Implementation Extension

- [ ] Develop Python reference implementation
- [ ] Cross-verify MATLAB and Python
- [ ] Define fixed-point signal ranges
- [ ] Quantize correlation and phase-estimation stages
- [ ] Develop C/C++ implementation concept
- [ ] Measure runtime, memory use, and numerical error

---

## Current Project Status

| Work item | Status |
|---|---|
| Project definition | Complete |
| Mathematical signal model | Complete |
| Schmidl–Cox algorithm definition | Complete |
| Coarse-CFO algorithm definition | Complete |
| Fine-CFO algorithm definition | Complete |
| Modular MATLAB implementation | In progress |
| Monte Carlo simulation | In progress |
| Verification gates | Planned |
| Final performance figures | Planned |
| Python implementation | Planned |
| MATLAB–Python cross-verification | Planned |
| Fixed-point C/C++ study | Planned |
| Technical report | Planned |

---

## Relationship to Other Repository Projects

This project is a focused synchronization study within the broader repository:

```text
PHY-Algorithm-Design-Firmware-Implementation/
|
├── 01-mimo-ofdm-8x8-16x16-phy-simulator/
├── 02-rf-transceiver-algorithm-to-firmware/
└── 03-ofdm-synchronization-module/
```

---

## Scope Limitation

This project currently implements a generic OFDM synchronization method based on a repeated Schmidl–Cox preamble.

A complete 5G NR initial-synchronization study would additionally require topics such as:

- synchronization-signal-block processing;
- PSS detection;
- SSS detection;
- physical-cell-identity detection;
- PBCH and DM-RS processing;
- SS/PBCH block timing;
- beam-sweeping considerations;
- NR numerology and synchronization raster.

A future extension may add a separate NR-oriented PSS/SSS synchronization mode while retaining the Schmidl–Cox implementation as a generic OFDM reference algorithm.

---

## Portfolio Skills Demonstrated

This project demonstrates practical understanding of:

- OFDM waveform generation
- Time-domain receiver impairments
- Frame and symbol synchronization
- Carrier-frequency-offset estimation
- Pilot-based residual phase tracking
- FFT-window placement
- Multipath-channel effects
- BER and EVM analysis
- Monte Carlo simulation
- Algorithm verification
- MATLAB signal-processing implementation
- Reproducible simulation design
- Floating-point-to-fixed-point planning
- PHY algorithm-to-firmware thinking

---

## Planned Deliverables

The final project will contain:

- MATLAB source code
- Configuration files
- Unit and verification tests
- Simulation logs
- CSV and MAT result files
- Generated figures
- Mathematical derivation document
- Algorithm workflow diagram
- Technical performance report
- Python reference implementation
- MATLAB–Python cross-verification results
- Fixed-point implementation study

---

## Author

**Md Moklesur Rahman**

Wireless/RF/PHY System Engineer with experience in:

- 5G/LTE radio systems
- RF and PHY algorithm specification
- Synchronization and timing
- Massive MIMO and OFDM
- Beamforming and beamforming calibration
- MATLAB and Python simulation
- Embedded RF calibration and validation workflows
- C/C++ implementation concepts

---

## License

A project license will be added before the first stable release.
Until a license is added, the source code remains available for review but should not be assumed to permit unrestricted reuse, modification, or redistribution.
