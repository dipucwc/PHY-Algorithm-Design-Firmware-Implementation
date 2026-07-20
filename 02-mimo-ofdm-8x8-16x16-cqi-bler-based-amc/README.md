# CQI-Based BLER-Constrained Adaptive Modulation and Coding for 8×8 and 16×16 MIMO-OFDM Links

**Design, implementation, verification, and performance evaluation of receiver-driven CQI/BLER-based adaptive modulation and coding in MATLAB**

---

## Project Identification

| Item | Description |
|---|---|
| **Project stage** | Project- advanced link-adaptation extension |
| **Implementation** | MATLAB |
| **Array configurations** | 8×8 and 16×16 square MIMO |
| **Waveform** | MIMO-OFDM |
| **Adaptation method** | Receiver-driven CQI-based AMC |
| **Reliability target** | BLER ≤ 0.10 |
| **Channel coding** | Rate-1/2 convolutional mother code with punctured rates 2/3 and 3/4 |
| **Block verification** | CRC-16-CCITT |
| **Primary quality mapping** | Exponential Effective-SINR Mapping (EESM) |
| **Feedback model** | One-slot delayed quality feedback |
| **Advanced controller** | Outer-Loop Link Adaptation (OLLA) |
| **Status** | Completed MATLAB research implementation with executed results and verification gates |
| **Author** | Md Moklesur Rahman |
| **Location** | Finland |
| **GitHub** | [dipucwc](https://github.com/dipucwc) |
| **Email** | moklesur.eee@gmail.com |

---

## Overview

This project extends a verified 8×8 and 16×16 MIMO-OFDM PHY/modem simulator from open-loop threshold-based adaptive modulation to a receiver-driven, BLER-constrained adaptive modulation and coding system.

The companion baseline project selects QPSK, 16-QAM, or 64-QAM from configured SNR thresholds while keeping the convolutional-code rate fixed at 1/2. That approach does not observe the post-equalization link quality experienced by the receiver and cannot jointly adapt modulation order and coding rate.

This Project 2 implementation introduces:

- post-equalization SINR estimation from the deployed MMSE detector;
- per-layer effective-SINR reporting;
- EESM, arithmetic-mean, and minimum-SINR mappings;
- separate BLER calibration curves for each mapping and array size;
- a nine-entry research MCS table;
- receiver-generated CQI;
- BLER-targeted MCS selection;
- punctured convolutional-code rates 1/2, 2/3, and 3/4;
- CRC-qualified block-error measurement;
- one-slot delayed quality feedback;
- transmitter-side OLLA correction;
- fixed-MCS, threshold, delayed-CQI, same-slot, and pilot-time-CSI reference comparisons;
- 95% Wilson confidence intervals;
- deterministic Monte Carlo execution and CSV-based result provenance.

The project is a research-oriented MIMO-OFDM link-adaptation study. It does not claim compliance with a standardized 3GPP NR MCS table or a complete NR protocol stack.

---

## Relationship to Project 1

The portfolio is intentionally divided into two distinct stages.

| Feature | Project-1 PHY baseline | Project 2 — this project |
|---|---|---|
| Adaptation input | Configured operating SNR | Receiver-estimated post-MMSE quality |
| Modulation | Threshold-selected QPSK, 16-QAM, or 64-QAM | Selected through the MCS table |
| Coding rate | Fixed at 1/2 | Variable: 1/2, 2/3, or 3/4 |
| Block-success definition | BER-oriented baseline analysis | CRC-qualified block delivery |
| Link-quality feedback | None | One-slot delayed quality report |
| Reliability objective | No explicit BLER constraint | BLER target of 0.10 |
| Advanced control | Not included | OLLA |
| Main purpose | Verify the complete PHY receiver chain | Implement and evaluate closed-loop AMC |

Project 1 establishes the synchronization, channel-estimation, MIMO-detection, equalization, and decoding foundation. Project 2 reuses that verified PHY and adds the complete receiver-driven link-adaptation loop.

---

## Main Contributions

1. **Per-stream post-equalization SINR estimation**

   The controller uses the same regularized MMSE detector deployed for data recovery. Desired signal power, residual inter-stream leakage, and equalizer-enhanced noise are included in the quality estimate.

2. **Per-layer codeword-quality reporting**

   Each spatial layer carries one codeword. The controller evaluates the subcarrier SINR profile of every layer separately and produces one candidate-specific effective-SINR report per layer and per MCS.

3. **Mapping-matched BLER calibration**

   EESM, mean-SINR, and minimum-SINR controllers use different effective-SINR axes. The implementation therefore generates and validates separate calibration files for every mapping and array size.

4. **BLER-constrained MCS selection**

   The transmitter predicts one BLER per layer and candidate MCS, combines those predictions using the configured average- or worst-layer criterion, and selects the highest admissible spectral-efficiency entry.

5. **Variable-rate coding and real block delivery**

   The transmitter appends CRC-16, terminates and convolutionally encodes the codeword, punctures the mother code to the selected rate, interleaves the transmitted bits, and maps them to the selected QAM constellation. Goodput includes only information bits belonging to CRC-passing blocks.

6. **Causal feedback processing**

   The receiver generates an uncorrected per-layer quality report. The complete report is delayed by one slot. The transmitter reads the delayed report and applies the current OLLA offset before selecting the MCS.

7. **Block-level OLLA update**

   The outer loop updates from the fraction of failed layer codewords rather than from an any-layer slot verdict. This aligns the OLLA equilibrium with the intended block-error target.

8. **Controlled comparison and reproducibility**

   Every adaptation method in one slot uses the same channel evolution, pilot noise, data noise, channel estimate, and equalizer state. Deterministic per-slot seeds reproduce the complete run.

---

## End-to-End Processing Chain

```text
Delayed quality report from slot t - D
                  │
                  ▼
Transmitter applies the current OLLA offset
                  │
                  ▼
BLER-constrained MCS selection
                  │
                  ▼
Information bits + CRC-16 + termination bits
                  │
                  ▼
Rate-1/2 convolutional mother code
                  │
                  ▼
Puncturing to rate 1/2, 2/3, or 3/4
                  │
                  ▼
Seeded bit interleaving
                  │
                  ▼
QPSK, 16-QAM, or 64-QAM mapping
                  │
                  ▼
8×8 or 16×16 MIMO-OFDM transmission
                  │
                  ▼
Comb-pilot Wiener channel estimation
                  │
                  ▼
Unbiased soft-output MMSE equalization
                  │
                  ▼
Per-stream, per-subcarrier SINR estimation
                  │
                  ▼
Per-layer effective-SINR mapping
                  │
                  ▼
New uncorrected quality report for a future slot
                  │
                  ▼
Soft demapping, deinterleaving, depuncturing
                  │
                  ▼
Terminated soft-decision Viterbi decoding
                  │
                  ▼
CRC pass/fail verdict for every layer codeword
                  │
                  ▼
BLER, goodput, spectral efficiency, MCS, CQI,
switching, confidence-interval, and OLLA statistics
```

---

## System Model

### Power-Normalized MIMO Signal

For subcarrier `k`, the received vector is modeled as:

```text
y[k] = (1 / sqrt(Nt)) H[k] x[k] + n[k]
```

where:

- `Nt` is the number of transmit antennas;
- `H[k]` is the `Nr × Nt` frequency-domain MIMO channel;
- `x[k]` contains the spatial-layer symbols;
- `n[k]` is complex Gaussian receiver noise.

The factor `1 / sqrt(Nt)` keeps the total transmitted power constant when the array size changes.

### MMSE Equalizer

```text
W[k] = (Hhat[k]^H Hhat[k] + sigma_n^2 I)^(-1) Hhat[k]^H
```

The composite response is:

```text
G[k] = W[k] Hhat[k]
```

For stream `l`, `G[k](l,l)` is the desired-stream gain, the off-diagonal terms are residual inter-stream leakage, and the row norm of `W[k]` determines the equalizer-enhanced noise power.

### Post-Equalization SINR

```text
SINR(l,k) =
    |G[k](l,l)|^2 Es
    -------------------------------------------------------
    sum_{j != l} |G[k](l,j)|^2 Es + ||w_l[k]||^2 sigma_n^2
```

The controller calculates this quantity from the Wiener channel estimate and the known receiver-noise variance.

### Effective-SINR Mappings

Arithmetic mean:

```text
SINR_mean = (1/N) sum_n SINR_n
```

Minimum mapping:

```text
SINR_min = min_n SINR_n
```

EESM:

```text
SINR_eff(m) =
    -beta_m * ln[(1/N) sum_n exp(-SINR_n / beta_m)]
```

The EESM parameter `beta_m` depends on the candidate MCS.

### BLER-Constrained Selection

For candidate MCS `m`, the controller:

1. calculates one effective SINR for every layer;
2. predicts one BLER for every layer from the calibrated curve;
3. forms either the average-layer or worst-layer criterion;
4. admits the MCS when the criterion is no greater than the target;
5. selects the admissible entry with the highest nominal spectral efficiency.

Conceptually:

```text
selected MCS =
    highest-efficiency m for which predicted BLER(m) <= 0.10
```

### OLLA Update

For one slot:

```text
failure_fraction = failed_blocks / total_blocks
success_fraction = 1 - failure_fraction

offset_new =
    offset_old
    + success_fraction * delta_up
    - failure_fraction * delta_down
```

The step relationship is:

```text
delta_up = delta_down * target_BLER / (1 - target_BLER)
```

This makes the expected offset drift zero when the measured block-error rate equals the target.

### Measured BLER

```text
BLER = failed CRC blocks / transmitted blocks
```

### CRC-Qualified Goodput

```text
goodput = delivered information bits / simulated slots
```

Only information bits from CRC-passing blocks are counted as delivered.

### Delivered Spectral Efficiency

```text
spectral efficiency =
    delivered information bits
    ------------------------------------------------
    slots × data subcarriers × data OFDM symbols
```

The value aggregates delivered information across all spatial layers.

---

## Research MCS Table

| MCS | Modulation | Bits/symbol | Coding rate | Nominal spectral efficiency |
|---:|---|---:|---:|---:|
| 0 | QPSK | 2 | 1/2 | 1.00 |
| 1 | QPSK | 2 | 2/3 | 1.33 |
| 2 | QPSK | 2 | 3/4 | 1.50 |
| 3 | 16-QAM | 4 | 1/2 | 2.00 |
| 4 | 16-QAM | 4 | 2/3 | 2.67 |
| 5 | 16-QAM | 4 | 3/4 | 3.00 |
| 6 | 64-QAM | 6 | 1/2 | 3.00 |
| 7 | 64-QAM | 6 | 2/3 | 4.00 |
| 8 | 64-QAM | 6 | 3/4 | 4.50 |

This is a custom research MCS table. It is not a standardized LTE or NR table.

The selector uses nominal spectral efficiency as the first comparison criterion. For equal efficiencies, it prefers the lower predicted BLER and then the lower modulation order.

---

## Channel Coding and Block Structure

The channel-code chain uses:

- constraint length `K = 7`;
- rate-1/2 convolutional mother code;
- generator polynomials `(133, 171)` in octal;
- terminated trellis;
- punctured rates `2/3` and `3/4`;
- CRC-16-CCITT;
- seeded random interleaving;
- zero-valued LLR erasures at depunctured positions;
- soft-decision Viterbi decoding.

Each spatial layer carries one codeword per slot.

The channel-bit container of one layer is:

```text
N_chan = N_sc × N_sym × bits_per_symbol
```

The information payload is:

```text
K_info =
    floor(N_chan × coding_rate)
    - CRC_length
    - termination_length
```

Eight MCS entries fill the container directly. MCS 4 requires one known zero-padding bit per layer codeword. The encoder records the padding length, and Verification Gate 17 checks the expected vector:

```text
[0 0 0 0 1 0 0 0 0]
```

---

## Adaptation Methods

The online study evaluates eight methods.

| Method | Mapping | Feedback | Coding/modulation behavior | Purpose |
|---|---|---|---|---|
| `fixed_mcs0` | None | None | Fixed QPSK, rate 1/2 | Static reference |
| `threshold_p1` | Configured SNR | None | Project 1 threshold modulation, rate 1/2 | Open-loop baseline |
| `cqi_mean_delayed` | Mean SINR | One-slot delay | BLER-constrained AMC | Mapping baseline |
| `cqi_min_delayed` | Minimum SINR | One-slot delay | BLER-constrained AMC | Conservative mapping baseline |
| `cqi_eesm_delayed` | EESM | One-slot delay | BLER-constrained AMC | Primary practical controller |
| `cqi_eesm_olla_delayed` | EESM | One-slot delay | EESM AMC with OLLA | Advanced closed-loop controller |
| `cqi_eesm_instant` | EESM | Same slot | Causality-free reference | Feedback-delay upper bound |
| `oracle` | EESM from true pilot-time channel | Same slot | Pilot-time-CSI quality reference | Reporting-loss reference |

The method named `oracle` is not a strict full-link oracle. It uses perfect pilot-time channel knowledge for CQI generation while the data detector still uses estimated-channel processing. It therefore bounds reporting loss rather than all receiver losses.

---

## Simulation Parameters

| Parameter | Executed value |
|---|---|
| MIMO configurations | 8×8 and 16×16 |
| FFT size | 256 |
| Cyclic prefix | 20 samples |
| Data OFDM symbols per slot | 13 |
| Pilot symbols per slot | 1 |
| Sample rate | 30.72 MHz |
| Channel | Five-tap TDL-A-style Rayleigh fading |
| Tap delays | `[0 1 2 4 6]` samples |
| Tap powers | `[0 -2.2 -4.0 -6.5 -9.0]` dB |
| Carrier frequency | 3.5 GHz |
| Terminal speed | 30 km/h |
| Doppler model | Simplified common-Doppler phase evolution |
| Online SNR sweep | 0:2:30 dB |
| Online slots per SNR | 100 |
| Target BLER | 0.10 |
| Feedback delay | 1 slot for delayed methods |
| Initial MCS | 0 |
| MCS entries | 9 |
| Coding rates | 1/2, 2/3, 3/4 |
| CRC | CRC-16-CCITT |
| EESM beta values | `[1.5 1.6 1.7 4.5 5.5 6.5 12.0 16.0 20.0]` |
| OLLA down step | 0.5 dB |
| OLLA up step | `delta_down × target/(1-target)` |
| OLLA clamp | ±10 dB |
| Calibration stopping | 100 block errors or 2000 blocks |
| Selection criterion | Average predicted layer BLER |
| Master random seed | 7 |

---

## Verification Methodology

The package implements twenty executable verification gates.

| Gate | Verification | Required result |
|---:|---|---|
| 1 | Valid and corrupted CRC blocks | Valid passes; corrupted fails |
| 2 | Noiseless round trip at rates 1/2, 2/3, and 3/4 | Zero information-bit errors |
| 3 | Puncturing/depuncturing positions | Erasures restored at removed positions |
| 4 | MCS-table integrity | Unique indices, supported rates/orders, nondecreasing efficiency |
| 5 | SINR-estimator behavior | Stronger channel raises SINR; more noise lowers SINR |
| 6 | Effective-SINR monotonicity | Quality cannot fall when every resource element improves |
| 7 | CQI monotonicity | CQI does not decrease with improving quality |
| 8 | BLER-curve interpolation | Predicted BLER is nonincreasing |
| 9 | BLER-target selector | Highest admissible efficiency is selected |
| 10 | Feedback causality | No same-slot report use |
| 11 | OLLA direction | Failures reduce offset; successes increase it |
| 12 | Reproducibility | Repeated run with the same seed is identical |
| 13 | Mapping-matched calibration | Controller and curve mapping labels agree |
| 14 | Per-layer quality report | One report row per layer codeword |
| 15 | OLLA equilibrium | Zero expected drift at target BLER |
| 16 | Offset application order | OLLA is applied after delayed-report retrieval |
| 17 | Padding lengths | `[0 0 0 0 1 0 0 0 0]` |
| 18 | CQI on executed curves | Nondecreasing on stored calibration data |
| 19 | Pilot-time-CSI reference | Uses mapping-matched curves |
| 20 | Wilson confidence interval | Known test intervals are reproduced |

The supplied report records all twenty gates as PASS.

---

## Executed Results

### 1. BLER-Target Compliance

The practical delayed-EESM controller first satisfies the `0.10` target at `12 dB` for both arrays.

| Array | BLER at 12 dB | 95% Wilson interval | Average BLER from 12–30 dB | Post-crossing violations |
|---|---:|---:|---:|---:|
| 8×8 | 0.075 | 0.059–0.095 | 0.025 | 0 |
| 16×16 | 0.034 | 0.027–0.044 | 0.014 | 0 |

The confidence interval of the tightest 8×8 point remains below the target, so the crossing is statistically supported by the stored block count.

### 2. Terminal Goodput at 30 dB

| Method | 8×8 goodput | 16×16 goodput |
|---|---:|---:|
| Fixed MCS 0 | 26,448 bits/slot | 52,896 bits/slot |
| Project 1 threshold rule | 47,618 bits/slot | 81,888 bits/slot |
| Mean-SINR delayed AMC | 52,540 bits/slot | 112,297 bits/slot |
| Minimum-SINR delayed AMC | 40,558 bits/slot | 91,678 bits/slot |
| Practical delayed EESM | 52,341 bits/slot | 106,457 bits/slot |
| Delayed EESM with OLLA | 52,474 bits/slot | 125,860 bits/slot |
| Same-slot EESM | 52,674 bits/slot | 107,786 bits/slot |
| Pilot-time-CSI reference | 52,873 bits/slot | 108,008 bits/slot |

### 3. Gain over the Fixed-MCS Reference

At 30 dB, the practical delayed-EESM controller provides:

- `1.98×` the fixed-MCS goodput for 8×8;
- `2.01×` the fixed-MCS goodput for 16×16.

### 4. Gain over the Project 1 Threshold Rule

At 30 dB, the practical delayed-EESM controller provides:

- `9.9%` more CRC-qualified goodput for 8×8;
- `30.0%` more CRC-qualified goodput for 16×16.

The Project 1 threshold rule still has measured BLER values of:

- `0.403` for 8×8;
- `0.486` for 16×16.

The receiver-driven controller therefore improves goodput while also maintaining the BLER constraint.

### 5. Mapping Comparison

The corrected implementation calibrates EESM, mean, and minimum mappings on their own axes.

At 30 dB:

- the mean controller reaches `52,540` bits/slot for 8×8 and `112,297` bits/slot for 16×16;
- the EESM controller reaches `52,341` bits/slot for 8×8 and `106,457` bits/slot for 16×16;
- both mean and EESM remain compliant after their target crossings;
- the minimum controller is conservative and produces lower goodput with low BLER.

The comparison is therefore controlled and no longer mixes mean-SINR inputs with EESM-calibrated curves.

### 6. Feedback-Delay Cost

At 30 dB, comparing delayed and same-slot EESM gives:

- 8×8: `333 bits/slot` delay cost;
- 16×16: `1.25%` delay cost.

The same-slot method is only a causality-free reference. The deployable controller uses the one-slot delay.

### 7. Pilot-Time-CSI Reference Gap

At 30 dB, the practical controller is:

- about `1.0%` below the pilot-time-CSI reference for 8×8;
- about `1.4%` below the reference for 16×16.

This reference bounds the quality-reporting loss rather than all link losses.

### 8. OLLA Behavior

The corrected OLLA update uses every block verdict.

At the convergence SNR:

- the 8×8 offset settles around `+0.8 dB`;
- the 16×16 offset settles around `+1.2 dB`;
- the running BLER approaches the `0.10` target from below;
- the loop remains stable and does not hit the ±10 dB clamp.

At 30 dB, the 16×16 OLLA controller reaches `125,860 bits/slot` with measured BLER `0.0625`, the highest terminal goodput in the supplied 16×16 results.

For 8×8, OLLA slightly improves the practical delayed-EESM result, while the same-slot and pilot-time-CSI references remain slightly higher.

### 9. Array-Size Comparison

The practical delayed-EESM terminal goodput is:

```text
8×8:   52,341 bits/slot
16×16: 106,457 bits/slot
```

The ratio is approximately `2.03`, closely matching the doubling of spatial layers.

The 16×16 calibration admits MCS 4 in a small fraction of high-SNR slots. The 8×8 calibration does not admit MCS 4 within the executed range, although its final confidence interval includes the target and leaves the decision statistically open without additional calibration above 30 dB.

---

## Representative Figures

The MATLAB package generates named PNG figures. A clean GitHub organization can place them under `plot/`.

### BLER Compliance

![8x8 BLER](plot/P2A3_bler_vs_snr_8x8.png)

![16x16 BLER](plot/P2B3_bler_vs_snr_16x16.png)

### CRC-Qualified Goodput

![8x8 Goodput](plot/P2A4_goodput_vs_snr_8x8.png)

![16x16 Goodput](plot/P2B4_goodput_vs_snr_16x16.png)

### MCS Calibration

![8x8 Calibration](plot/P2C1_bler_curves_8x8.png)

![16x16 Calibration](plot/P2C1_bler_curves_16x16.png)

### Controlled Array Comparison

![Cross-array Goodput](plot/P2D2_goodput_8x8_vs_16x16.png)

> Keep the filenames unchanged when moving the generated PNG files into the `plot/` folder so the links remain valid.

---

## MATLAB Package Architecture

### Main Execution

| File | Responsibility |
|---|---|
| `main_cqi_amc_8x8.m` | Starts the complete 8×8 online AMC study |
| `main_cqi_amc_16x16.m` | Starts the complete 16×16 online AMC study |
| `run_cqi_amc_main.m` | Shared online engine for all eight methods |
| `run_cqi_amc_comparison.m` | Validates run fingerprints and generates cross-array overlays |
| `generate_mcs_bler_curves.m` | Generates fixed-MCS calibration curves for all mappings |
| `run_verification_gates.m` | Runs Verification Gates 1–20 |

### Configuration and MCS Definition

| File | Responsibility |
|---|---|
| `create_cqi_amc_config.m` | Central PHY, controller, calibration, OLLA, and reproducibility configuration |
| `create_mcs_table.m` | Creates the nine-entry research MCS table |

### Channel and Receiver Processing

| File | Responsibility |
|---|---|
| `build_link_precompute.m` | Precomputes pilot patterns and channel statistics |
| `build_wiener_filter.m` | Builds the operating-SNR Wiener filter |
| `prepare_slot_shared.m` | Draws one shared channel/noise realization and prepares receiver quantities |
| `mimo_freq_response.m` | Generates the frequency-domain time-varying MIMO channel |
| `ls_pilot_estimate.m` | Produces LS estimates at pilots and frequency interpolation |
| `wiener_mmse_estimate.m` | Applies Wiener MMSE channel estimation |
| `compute_wiener_matrices.m` | Builds the channel-correlation matrices |
| `mmse_equalize_soft.m` | Provides the soft-output unbiased MMSE convention |
| `estimate_post_eq_sinr.m` | Calculates post-equalization SINR, weights, gains, and effective variance |

### CQI and Link Adaptation

| File | Responsibility |
|---|---|
| `calculate_effective_sinr.m` | Mean, minimum, and EESM mappings |
| `estimate_quality_report.m` | Builds the per-layer, per-candidate quality report |
| `estimate_cqi.m` | Generates the receiver-side uncorrected CQI and quality report |
| `select_mcs_for_target_bler.m` | Applies the BLER constraint and tie-breaking rules |
| `interpolate_bler_curve.m` | Produces monotonic BLER predictions |
| `verify_curve_mapping.m` | Prevents a mapping/curve-axis mismatch |
| `apply_cqi_feedback_delay.m` | Delays the complete quality report causally |
| `update_olla_offset.m` | Updates the transmitter-side OLLA offset from block verdicts |

### Variable-Rate Coding and CRC

| File | Responsibility |
|---|---|
| `append_crc.m` | Appends CRC-16 |
| `check_crc.m` | Checks the decoded CRC field |
| `crc16_bits.m` | Implements the CRC-16 bitwise remainder |
| `select_puncturing_pattern.m` | Selects the rate-specific puncturing mask |
| `apply_puncturing.m` | Removes mother-code bits according to the mask |
| `depuncture_llr.m` | Restores punctured positions as zero-LLR erasures |
| `encode_variable_rate.m` | CRC, termination, convolutional encoding, puncturing, interleaving, and padding |
| `decode_variable_rate.m` | Soft deinterleaving, depuncturing, Viterbi decoding, and CRC verification |
| `run_slot_link.m` | Runs one complete multi-layer coded MIMO-OFDM slot |

### Results and Plotting

| File | Responsibility |
|---|---|
| `compute_bler.m` | Calculates BLER and the 95% Wilson interval |
| `plot_amc_results.m` | Generates per-array result figures |
| `mcs_selection_8x8.csv` | Primary-method MCS statistics for 8×8 |
| `mcs_selection_16x16.csv` | Primary-method MCS statistics for 16×16 |
| `results_cqi_amc_8x8.csv` | Complete 8×8 online results |
| `results_cqi_amc_16x16.csv` | Complete 16×16 online results |
| `run_config_cqi_8x8.csv` | 8×8 run fingerprint |
| `run_config_cqi_16x16.csv` | 16×16 run fingerprint |

---

## Calibration Files

The implementation stores separate curves for every mapping and array size:

```text
mcs_bler_curves_eesm_8x8.csv
mcs_bler_curves_mean_8x8.csv
mcs_bler_curves_minimum_8x8.csv

mcs_bler_curves_eesm_16x16.csv
mcs_bler_curves_mean_16x16.csv
mcs_bler_curves_minimum_16x16.csv
```

Each row stores:

- MCS index;
- operating SNR;
- effective SINR;
- measured BLER;
- transmitted blocks;
- failed blocks;
- successful blocks;
- lower and upper 95% Wilson bounds;
- EESM beta;
- mapping label.

`verify_curve_mapping.m` checks the mapping label before an online controller is allowed to use a calibration table.

---

## Generated Online Result Columns

The main CSV files contain:

- `SNR_dB`
- `Array_Size`
- `Adaptation_Method`
- `Effective_SINR_Method`
- `Average_Effective_SINR_dB`
- `Average_CQI`
- `Average_MCS`
- `Measured_BLER`
- `Target_BLER`
- `BLER_Error`
- `BLER_CI_Low_95`
- `BLER_CI_High_95`
- `Goodput_Bits_Per_Slot`
- `Spectral_Efficiency`
- `MCS_Switching_Rate`
- `CQI_Delay_Slots`
- `CQI_Error_Probability`
- `Average_OLLA_Offset_dB`
- `Total_Blocks`
- `Failed_Blocks`
- `Successful_Blocks`
- `Total_Information_Bits`
- `Delivered_Information_Bits`
- `Random_Seed`

---

## Recommended Repository Structure

```text
02-mimo-ofdm-8x8-16x16-cqi-bler-based-amc/
│
├── README.md
│
├── MATLAB_Package/
│   ├── main_cqi_amc_8x8.m
│   ├── main_cqi_amc_16x16.m
│   ├── generate_mcs_bler_curves.m
│   ├── run_cqi_amc_main.m
│   ├── run_cqi_amc_comparison.m
│   ├── run_verification_gates.m
│   ├── create_cqi_amc_config.m
│   ├── create_mcs_table.m
│   ├── receiver_and_link_functions/
│   ├── coding_and_crc_functions/
│   ├── cqi_and_amc_functions/
│   └── results/
│
├── plot/
│   ├── P2A1_mcs_vs_snr_8x8.png
│   ├── P2A2_cqi_vs_snr_8x8.png
│   ├── P2A3_bler_vs_snr_8x8.png
│   ├── P2A4_goodput_vs_snr_8x8.png
│   ├── P2B3_bler_vs_snr_16x16.png
│   ├── P2B4_goodput_vs_snr_16x16.png
│   ├── P2C1_bler_curves_8x8.png
│   ├── P2C1_bler_curves_16x16.png
│   ├── P2D1_bler_8x8_vs_16x16.png
│   ├── P2D2_goodput_8x8_vs_16x16.png
│   ├── P2D3_mcs_8x8_vs_16x16.png
│   └── P2D4_oracle_vs_practical.png
│
└── report/
    └── CQI-AMC based 8x8-16 x16 MIMO-OFDM .docx
```

The MATLAB source filenames should remain unchanged because the execution scripts and function calls depend on them.

---

## Requirements

- MATLAB
- Communications Toolbox
- Functions used by the package include:
  - `poly2trellis`
  - `convenc`
  - `vitdec`
  - `qammod`
  - `qamdemod`
  - `RandStream`
  - `readtable`
  - `writetable`

Check the required functions before the full run:

```matlab
which poly2trellis
which convenc
which vitdec
which qammod
which qamdemod
```

---

## How to Run

Place all MATLAB source files and CSV files in the MATLAB working folder, or add the source folder to the MATLAB path.

### 1. Run the verification gates

```matlab
run('run_verification_gates.m');
```

Expected summary:

```text
Verification gates: 20 passed, 0 failed
```

### 2. Generate the 8×8 calibration files

Open `generate_mcs_bler_curves.m` and set:

```matlab
arraySizeToCalibrate = 8;
```

Then run:

```matlab
run('generate_mcs_bler_curves.m');
```

This creates the EESM, mean, and minimum calibration files for 8×8.

### 3. Generate the 16×16 calibration files

Set:

```matlab
arraySizeToCalibrate = 16;
```

Then run the same script again:

```matlab
run('generate_mcs_bler_curves.m');
```

### 4. Run the 8×8 online study

```matlab
run('main_cqi_amc_8x8.m');
```

### 5. Run the 16×16 online study

```matlab
run('main_cqi_amc_16x16.m');
```

### 6. Generate the controlled array comparison

```matlab
run('run_cqi_amc_comparison.m');
```

### Recommended clean execution

```matlab
clear;
clc;
close all;

run('run_verification_gates.m');

% Set arraySizeToCalibrate = 8 inside generate_mcs_bler_curves.m
run('generate_mcs_bler_curves.m');

% Set arraySizeToCalibrate = 16 and run again
run('generate_mcs_bler_curves.m');

run('main_cqi_amc_8x8.m');
run('main_cqi_amc_16x16.m');
run('run_cqi_amc_comparison.m');
```

The calibration stage is computationally heavier than the online sweep because every MCS is evaluated over a dedicated SNR window with adaptive block-count stopping.

---

## Reproducibility and Fair Comparison

The project enforces repeatability through:

- master random seed `7`;
- deterministic per-SNR and per-slot seeds;
- separate shared-realization and payload streams;
- identical channel and noise realizations for every adaptation method in a slot;
- stored run fingerprints;
- mapping labels in every calibration file;
- CSV-generated plots and conclusions;
- guarded cross-array comparison;
- confidence intervals derived from stored block counts.

The methods use different payload bits, but each method experiences the same propagation channel, pilot noise, data noise, estimated channel, MMSE equalizer, and receiver-quality state for a given slot.

---

## Important Interpretation Notes

1. **BLER is measured from CRC verdicts.**  
   No BER-derived approximation is used for block success.

2. **Goodput is delivered payload.**  
   Failed blocks contribute zero delivered information bits.

3. **The same-slot EESM method is not practical.**  
   It is included only to quantify the cost of feedback delay.

4. **The pilot-time-CSI reference is not a full oracle.**  
   It uses true pilot-time channel knowledge for quality generation but does not replace the estimated-channel data detector.

5. **The threshold baseline is intentionally open loop.**  
   Its QAM order depends only on configured SNR, and its coding rate stays fixed at 1/2.

6. **The MCS table is research-specific.**  
   The project does not claim standardized NR CQI or MCS behavior.

7. **MCS 4 at 8×8 remains statistically unresolved.**  
   Its lowest calibrated point has BLER slightly above 0.10, while the Wilson interval includes the target. Additional calibration above 30 dB would be required for a definitive decision.

8. **The stored calibration point uses aggregate block counts and the mean of per-layer effective-SINR values at each fixed-MCS operating point.**  
   The online controller forms per-layer quality reports. A stricter future calibration can pair every individual layer CRC verdict directly with its own effective SINR.

---

## Limitations

- custom nine-entry research MCS table;
- convolutional coding rather than standardized LDPC coding;
- CRC-16 rather than NR data-channel CRC and segmentation;
- simplified five-tap TDL-A-style channel;
- common-Doppler temporal evolution rather than independent per-path Doppler spectra;
- square 8×8 and 16×16 arrays only;
- one common MCS for all spatial layers;
- no rank adaptation;
- no HARQ or soft combining;
- no scheduler or multi-user interference;
- no standardized CQI quantization or reporting format;
- fixed integer feedback delay;
- one pilot-time channel estimate per slot;
- floating-point MATLAB implementation;
- no embedded or real-time execution.

---

## Future Work

- standardized LDPC coding and rate matching;
- standardized CRC attachment and code-block segmentation;
- standardized CQI and MCS tables;
- HARQ with soft combining;
- rank adaptation;
- per-layer or per-codeword MCS selection;
- mutual-information effective-SINR mapping;
- direct per-layer calibration using individual CRC verdict/effective-SINR pairs;
- CQI quantization and reporting-channel errors;
- variable feedback delay;
- spatially correlated and geometry-based channel models;
- independent per-path Doppler spectra;
- multi-user scheduling;
- fixed-point implementation;
- C/C++ implementation of the controller;
- real-time or hardware-in-the-loop demonstration.

---

## Skills Demonstrated

This project provides practical evidence of experience in:

- MIMO-OFDM link-level simulation;
- post-equalization SINR estimation;
- CQI generation;
- adaptive modulation and coding;
- BLER-constrained MCS selection;
- EESM and link-to-system mapping;
- variable-rate convolutional coding;
- puncturing and depuncturing;
- soft-decision Viterbi decoding;
- CRC-based block verification;
- delayed feedback modeling;
- outer-loop link adaptation;
- Monte Carlo simulation;
- Wilson confidence intervals;
- controlled baseline comparison;
- numerical verification;
- MATLAB software architecture;
- reproducibility and result provenance;
- root-cause correction of receiver-algorithm mismatches.

These topics are directly relevant to PHY algorithm, modem, baseband, DSP, wireless system simulation, link adaptation, and receiver-development roles.

---

## Technical Report

The full report is titled:

> **Design, Implementation, Verification, and Performance Evaluation of CQI-Based BLER-Constrained Adaptive Modulation and Coding for 8×8 and 16×16 MIMO-OFDM Links**

The report contains:

- motivation and related work;
- baseline system model;
- post-equalization SINR derivation;
- mean, minimum, and EESM mappings;
- CQI and MCS design;
- variable-rate coding and CRC-based BLER;
- eight numbered algorithms;
- algorithm-to-code traceability;
- twenty verification gates;
- complete simulation parameters;
- thirty-two result figures;
- 8×8 and 16×16 comparative analysis;
- limitations and future work.

---

## References

1. A. J. Goldsmith and S.-G. Chua, “Variable-rate variable-power MQAM for fading channels,” *IEEE Transactions on Communications*, 1997.
2. S. T. Chung and A. J. Goldsmith, “Degrees of freedom in adaptive modulation: a unified view,” *IEEE Transactions on Communications*, 2001.
3. E. Dahlman, S. Parkvall, and J. Sköld, *5G NR: The Next Generation Wireless Access Technology*, 2nd ed., 2020.
4. A. Ghosh, J. Zhang, J. G. Andrews, and R. Muhamed, *Fundamentals of LTE*, 2010.
5. Ericsson, “System-level evaluation of OFDM — further considerations,” 3GPP R1-031303, 2003.
6. K. Brueninghaus et al., “Link performance models for system level simulations of broadband radio access systems,” IEEE PIMRC, 2005.
7. J. C. Ikuno, M. Wrulich, and M. Rupp, “System level simulation of LTE networks,” IEEE VTC-Spring, 2010.
8. A. Sampath, P. S. Kumar, and J. M. Holtzman, “On setting reverse link target SIR in a CDMA system,” IEEE VTC, 1997.
9. D. L. Goeckel, “Adaptive coding for time-varying channels using outdated fading estimates,” *IEEE Transactions on Communications*, 1999.
10. S. Catreux, V. Erceg, D. Gesbert, and R. W. Heath, “Adaptive modulation and MIMO coding for broadband wireless data networks,” *IEEE Communications Magazine*, 2002.
11. M. M. Rahman, “Design, verification, and comparative performance evaluation of a scalable 8×8 and 16×16 MIMO-OFDM PHY simulator with threshold-based adaptive modulation and fixed-rate channel coding,” Technical Report, 2026.
12. S. Lin and D. J. Costello, *Error Control Coding*, 2nd ed., 2004.
13. J. Hagenauer, “Rate-compatible punctured convolutional codes and their applications,” *IEEE Transactions on Communications*, 1988.
14. E. B. Wilson, “Probable inference, the law of succession, and statistical inference,” *Journal of the American Statistical Association*, 1927.

---

## Author

**Md Moklesur Rahman**  
Independent Researcher, Finland  
Email: moklesur.eee@gmail.com  
GitHub: [dipucwc](https://github.com/dipucwc)

---

## Citation

```bibtex
@techreport{rahman2026cqiamcmimoofdm,
  author      = {Md Moklesur Rahman},
  title       = {Design, Implementation, Verification, and Performance Evaluation of CQI-Based BLER-Constrained Adaptive Modulation and Coding for 8x8 and 16x16 MIMO-OFDM Links},
  institution = {Independent Research},
  year        = {2026}
}
```
