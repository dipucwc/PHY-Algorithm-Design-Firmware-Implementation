# Scalable 8×8 and 16×16 MIMO-OFDM PHY Simulator

**Design, verification, and comparative performance evaluation of synchronization, channel estimation, MIMO detection, adaptive modulation, and hard/soft Viterbi decoding in MATLAB**

**Status:** Completed and verified baseline  
**Implementation:** MATLAB  
**Array configurations:** 8×8 and 16×16 square MIMO  
**Study type:** Reproducible link-level PHY/modem simulation

---

## Overview

This project implements and evaluates a complete MIMO-OFDM physical-layer simulation chain at two square-array sizes: **8 transmit × 8 receive antennas** and **16 transmit × 16 receive antennas**.

The two configurations use the same OFDM parameters, channel profile, Doppler model, SNR sweep, modulation thresholds, convolutional code, Monte Carlo depth, and random seed. The antenna count is the only intentionally changed system variable. This controlled design makes it possible to attribute the observed differences in capacity, channel-estimation accuracy, detector performance, and coded BER directly to array scaling.

The project covers five important PHY/modem algorithm areas:

1. **Synchronization**
2. **Channel estimation**
3. **MIMO spatial processing**
4. **Linear equalization/detection**
5. **Link adaptation and channel decoding**

A central part of the study is the controlled comparison between **hard-decision and soft-decision Viterbi decoding**. Both decoder branches are generated from the same gain-corrected, unbiased MMSE symbol stream. The hard branch discards reliability information and passes binary decisions to the decoder, while the soft branch uses per-stream effective-noise-variance-scaled log-likelihood ratios.

> **Scope note:**  This repository stage is **Project 1**, where modulation is selected through configured SNR thresholds and the channel-code rate remains fixed at 1/2. **Project 2**, maintained separately, extends the verified baseline to receiver-generated CQI, BLER-targeted MCS selection, and variable-rate adaptive modulation and coding.

---

## Project Objectives

The project was developed to answer the following technical questions:

- How accurately can a Schmidl-Cox receiver recover frame timing and carrier-frequency offset?
- How does interpolation-based LS channel estimation compare with statistics-aware Wiener MMSE estimation?
- How strongly does square-array scaling affect ZF and regularized MMSE detection?
- What is gained by preserving reliability information for soft Viterbi decoding?
- Does the benefit of statistical receiver processing increase as the MIMO array becomes larger?

---

## Relationship to Project 2

The portfolio is intentionally divided into two technically distinct stages:

| Stage | Adaptation input | Modulation | Coding rate | Main purpose |
|---|---|---|---|---|
| **Project 1- this project** | Configured operating SNR and fixed thresholds | QPSK, 16-QAM, or 64-QAM | Fixed at 1/2 | Verify the complete synchronization, estimation, MIMO detection, equalization, and hard/soft decoding chain |
| **Project 2- advanced AMC extension** | Receiver-estimated effective SINR and generated CQI | Selected through an MCS table | Variable | Maintain a target BLER while maximizing achieved goodput |

Project 2 reuses the verified PHY foundation but introduces a separate closed-loop link-adaptation contribution. Keeping the stages separate avoids presenting threshold-based modulation as full CQI/BLER-based AMC and prevents duplication of the baseline results.

---

## Main Features

### Synchronization

- Even-bin Schmidl-Cox training preamble
- Sliding timing autocorrelation and normalized timing metric
- Coarse CFO estimation from repeated-half correlation phase
- Fine CFO estimation from pilot phase drift
- CFO compensation in the time domain
- Genie, uncompensated, and recovered synchronization cases
- Timing RMSE, CFO RMSE, BER, and EVM evaluation

### Channel Estimation

- Orthogonal non-overlapping pilot comb for each transmit antenna
- LS pilot estimation
- Spline interpolation across unobserved subcarriers
- Delay-profile-based Wiener MMSE filtering
- Pilot-density comparison:
  - 32 pilots per transmit antenna for 8×8
  - 16 pilots per transmit antenna for 16×16
- Channel-estimation MSE against the true pilot-time channel

### MIMO Processing and Equalization

- Full spatial multiplexing over square MIMO channels
- Equal total transmit-power normalization using $1/\sqrt{N_t}$
- Per-subcarrier ZF detection
- Regularized MMSE detection
- MMSE gain correction to produce an unbiased symbol estimate
- Per-stream effective error/noise variance
- Hard-bit and soft-LLR demapping from the same unbiased stream
- Per-stream and aggregate BER, EVM, and post-equalization SINR
- Ergodic MIMO capacity calculation

### Adaptive Modulation and Channel Coding

- QPSK for SNR below 8 dB
- 16-QAM for SNR from 8 dB to below 18 dB
- 64-QAM for SNR from 18 dB upward
- Unit-average-power QAM normalization
- Rate-1/2 convolutional coding
- Constraint length 7
- Generator polynomials $[133\ 171]$ in octal form
- Traceback depth 35
- Hard-decision Viterbi decoding
- Soft-decision unquantized Viterbi decoding
- Log-domain interpolation of coded-BER target crossings
- Goodput-style and spectral-efficiency proxies

### Verification and Reproducibility

- Fixed random seed: `rng(7)`
- Saved/restored random-generator state for preamble generation
- Per-configuration CSV result export
- Automated SNR-grid consistency check before size comparison
- Guarded BER-crossing calculation without unsupported extrapolation
- Dedicated LLR sign-convention verification
- Documented defect isolation, correction, and rerun confirmation

---

## Simulation Architecture

The package contains two coordinated studies.

### Study A: OFDM Synchronization

The synchronization experiment characterizes timing and carrier recovery using a single OFDM link:

```text
Known OFDM preamble
        ↓
Timing offset + CFO + multipath channel + AWGN
        ↓
Schmidl-Cox timing metric
        ↓
Coarse CFO estimation and compensation
        ↓
Fine CFO estimation from pilot phase drift
        ↓
Genie / uncompensated / recovered demodulation
        ↓
Timing RMSE, CFO RMSE, BER, and EVM
```

### Study B: 8×8 and 16×16 MIMO-OFDM Link

```text
Information bits
        ↓
Rate-1/2 convolutional encoder
        ↓
Threshold-based QPSK / 16-QAM / 64-QAM selection
        ↓
Spatial-layer mapping and per-antenna comb pilots
        ↓
256-point OFDM modulation
        ↓
Time-varying multipath MIMO channel + AWGN
        ↓
OFDM demodulation
        ↓
LS and Wiener MMSE channel estimation
        ↓
ZF and soft-output unbiased MMSE detection
        ↓
Common gain-corrected MMSE symbol stream
        ├── Hard demapper → hard-decision Viterbi
        └── Soft LLR demapper → soft-decision Viterbi
        ↓
BER, EVM, SINR, MSE, capacity, and goodput-style metrics
```

The synchronization experiment evaluates acquisition performance separately. Its timing estimate is not used to position the FFT window of the MIMO study; the MIMO chain uses its own pilot and channel-processing path.

---
## Mathematical Model

### Power-Normalized MIMO Signal Model

For subcarrier $k$, the received frequency-domain signal is

```math
\mathbf{y}[k]
=
\frac{1}{\sqrt{N_t}}\mathbf{H}[k]\mathbf{x}[k]
+
\mathbf{n}[k].
```

where:

- $N_t$ is the number of transmit antennas,
- $N_r$ is the number of receive antennas,
- $\mathbf{x}[k]\in\mathbb{C}^{N_t\times 1}$ contains the unit-average-power spatial-layer symbols,
- $\mathbf{H}[k]\in\mathbb{C}^{N_r\times N_t}$ is the frequency-domain MIMO channel,
- $\mathbf{y}[k]\in\mathbb{C}^{N_r\times 1}$ is the received signal vector,
- $\mathbf{n}[k]\sim\mathcal{CN}\!\left(\mathbf{0},\sigma_n^2\mathbf{I}_{N_r}\right)$ is complex Gaussian receiver noise.

The factor $1/\sqrt{N_t}$ keeps the total transmit power constant when the number of transmit antennas changes.

Define the power-normalized channel as

```math
\mathbf{H}_s[k]
=
\frac{1}{\sqrt{N_t}}\mathbf{H}[k].
```

The received signal model becomes

```math
\mathbf{y}[k]
=
\mathbf{H}_s[k]\mathbf{x}[k]
+
\mathbf{n}[k].
```

The corresponding estimated power-normalized channel is

```math
\widehat{\mathbf{H}}_s[k]
=
\frac{1}{\sqrt{N_t}}\widehat{\mathbf{H}}[k].
```

### Zero-Forcing Detection

The zero-forcing detector estimates the transmitted symbol vector using the Moore-Penrose pseudo-inverse:

```math
\widehat{\mathbf{x}}_{\mathrm{ZF}}[k]
=
\widehat{\mathbf{H}}_s^{\dagger}[k]\mathbf{y}[k].
```

When the Gram matrix is invertible, the same detector can be written as

```math
\widehat{\mathbf{x}}_{\mathrm{ZF}}[k]
=
\left(
\widehat{\mathbf{H}}_s^{H}[k]\widehat{\mathbf{H}}_s[k]
\right)^{-1}
\widehat{\mathbf{H}}_s^{H}[k]\mathbf{y}[k].
```

where $(\cdot)^H$ denotes the Hermitian transpose and $(\cdot)^\dagger$ denotes the Moore-Penrose pseudo-inverse.

ZF suppresses inter-stream interference through channel inversion. However, it can strongly amplify receiver noise when the estimated channel matrix is poorly conditioned.

### MMSE Detection

The MMSE equalization matrix is

```math
\mathbf{W}_{\mathrm{MMSE}}[k]
=
\left(
\widehat{\mathbf{H}}_s^{H}[k]\widehat{\mathbf{H}}_s[k]
+
\sigma_n^2\mathbf{I}_{N_t}
\right)^{-1}
\widehat{\mathbf{H}}_s^{H}[k].
```

The raw MMSE symbol estimate is

```math
\widetilde{\mathbf{x}}[k]
=
\mathbf{W}_{\mathrm{MMSE}}[k]\mathbf{y}[k].
```

The regularization term $\sigma_n^2\mathbf{I}_{N_t}$ limits noise enhancement and improves numerical stability compared with direct channel inversion.

### Unbiased MMSE Output

The raw MMSE output is generally amplitude-biased. Define the composite response as

$$
\mathbf{G}[k]
=
\mathbf{W}_{\mathrm{MMSE}}[k]
\widehat{\mathbf{H}}_s[k].
$$

For spatial stream $i$, the effective MMSE gain is the corresponding diagonal element:

$$
g_i[k]
=
\left[\mathbf{G}[k]\right]_{i,i}.
$$

The gain-corrected unbiased MMSE output is

$$
z_i[k]
=
\frac{\widetilde{x}_i[k]}{g_i[k]}.
$$

In vector form,

$$
\mathbf{z}[k]
=
\mathbf{D}_g^{-1}[k]
\widetilde{\mathbf{x}}[k],
$$

where the diagonal gain matrix is written explicitly as

$$
\mathbf{D}_g[k]
=
\begin{bmatrix}
g_1[k] & 0 & \cdots & 0 \\
0 & g_2[k] & \cdots & 0 \\
\vdots & \vdots & \ddots & \vdots \\
0 & 0 & \cdots & g_{N_t}[k]
\end{bmatrix}.
$$

### Per-Stream Effective Noise Variance

Under the assumed linear-MMSE model and unit symbol power, the receiver-side reliability estimate for stream $i$ is

$$
\sigma_{\mathrm{eff},i}^{2}[k]
=
\frac{1-g_i[k]}{g_i[k]}.
$$

A small value of $\sigma_{\mathrm{eff},i}^{2}[k]$ indicates a reliable stream, while a large value indicates stronger residual interference and noise.

With estimated CSI, this is a model-based reliability estimate rather than the exact realized error variance.

### Hard-Bit Generation

For bit position $q$ of the QAM symbol transmitted on stream $i$, define the minimum squared distance to the constellation subset associated with bit $0$ as

```math
d_{i,q}^{(0)}[k]
=
\min_{a\in\mathcal{S}_{q}^{(0)}}
\left|z_i[k]-a\right|^2.
```

Similarly, define the minimum squared distance to the constellation subset associated with bit $1$ as

```math
d_{i,q}^{(1)}[k]
=
\min_{a\in\mathcal{S}_{q}^{(1)}}
\left|z_i[k]-a\right|^2.
```

The hard bit decision is then

```math
\widehat{b}_{i,q}^{\mathrm{hard}}[k]
=
\begin{cases}
0, & d_{i,q}^{(0)}[k] \leq d_{i,q}^{(1)}[k], \\
1, & d_{i,q}^{(1)}[k] < d_{i,q}^{(0)}[k].
\end{cases}
```

where:

- $q$ identifies the bit position in the QAM symbol,
- $\mathcal{S}_{q}^{(0)}$ contains constellation points whose $q$-th label bit is $0$,
- $\mathcal{S}_{q}^{(1)}$ contains constellation points whose $q$-th label bit is $1$.
```
The hard-input Viterbi decoder receives only the resulting binary decisions.

### Soft-Bit Generation

For coded bit $b_q$, the max-log LLR generated from stream $i$ is approximated as

```math
L\!\left(b_q\mid z_i[k]\right)
\approx
\frac{1}{\sigma_{\mathrm{eff},i}^{2}[k]}
\left[
\underset{a\in\mathcal{S}_{q}^{(1)}}{\min}\left|z_i[k]-a\right|^2
-
\underset{a\in\mathcal{S}_{q}^{(0)}}{\min}\left|z_i[k]-a\right|^2
\right].
```

The LLR sign convention is

```math
L\!\left(b_q\mid z_i[k]\right)
=
\ln\!\left(
\frac{P\!\left(b_q=0\mid z_i[k]\right)}
{P\!\left(b_q=1\mid z_i[k]\right)}
\right).
```

Therefore:

- a positive LLR indicates that bit $0$ is more likely,
- a negative LLR indicates that bit $1$ is more likely,
- a large absolute LLR indicates high confidence,
- an LLR close to zero indicates low confidence.

The hard- and soft-decision Viterbi branches use the same gain-corrected unbiased symbol sequence $\mathbf{z}[k]$. The hard branch receives binary decisions, while the soft branch receives reliability-valued LLRs.

### Measured Soft-Decision Gain

At a selected target coded BER, the soft-decision gain is defined as

```math
\Delta\mathrm{SNR}\!\left(\mathrm{BER}_{\mathrm{target}}\right)
=
\mathrm{SNR}_{\mathrm{hard}}\!\left(\mathrm{BER}_{\mathrm{target}}\right)
-
\mathrm{SNR}_{\mathrm{soft}}\!\left(\mathrm{BER}_{\mathrm{target}}\right).
```

A positive value of $\Delta\mathrm{SNR}$ means that the soft-decision decoder reaches the selected BER target at a lower SNR than the hard-decision decoder.

Target crossings are interpolated on the logarithmic BER axis only when the measured BER curve crosses the requested target within the simulated SNR range. No crossing is extrapolated beyond the measured results.

---

## Shared Simulation Parameters

| Parameter | Executed value |
|---|---|
| MIMO configurations | 8×8 and 16×16 |
| FFT size | 256 |
| Cyclic prefix | 20 samples |
| OFDM symbol length | 276 samples |
| Sample rate | 30.72 MHz |
| Channel | Five-tap TDL-A-style Rayleigh fading |
| Tap delays | 0, 1, 2, 4, and 6 samples |
| Tap powers | 0, −2.2, −4, −6.5, and −9 dB |
| Carrier frequency | 3.5 GHz |
| Terminal speed | 30 km/h |
| Maximum Doppler | Approximately 97 Hz |
| Temporal model | Simplified common-Doppler phase evolution; channel rebuilt per OFDM symbol |
| SNR sweep | 0:2:30 dB |
| Pilot design | Orthogonal non-overlapping per-antenna combs |
| 8×8 pilot density | 32 pilots per transmit antenna |
| 16×16 pilot density | 16 pilots per transmit antenna |
| Modulation thresholds | QPSK below 8 dB; 16-QAM from 8 to below 18 dB; 64-QAM from 18 dB |
| Channel code | Rate-1/2 convolutional code |
| Constraint length | 7 |
| Generator polynomials | $[133\ 171]$, octal |
| Viterbi traceback depth | 35 |
| Synchronization trials | 400 trials per SNR point |
| MIMO Monte Carlo depth | 100 slots per SNR point |
| Data symbols | 13 per slot |
| Random seed | `rng(7)` |

---

## Fair Hard-versus-Soft Viterbi Comparison

The decoder comparison is designed as a controlled experiment.

Both branches share:

- the same information bits,
- the same convolutionally encoded bits,
- the same modulation symbols,
- the same antenna mapping,
- the same channel realization,
- the same AWGN samples,
- the same channel estimate,
- the same MMSE weight matrix,
- the same gain-corrected unbiased symbol stream.

The only changed element is the decoder input representation:

| Branch | Demapper output | Decoder metric |
|---|---|---|
| Hard decision | Binary bits | Hamming-distance branch metric |
| Soft decision | Per-bit reliability/LLR values | Reliability-weighted branch metric |

This prevents the measured decoder separation from being contaminated by different equalizer gains, different channel realizations, or different noise samples.

---

## Performance Metrics

The simulator records:

- Uncoded BER
- Hard-decision coded BER
- Soft-decision coded BER
- RMS EVM
- Reference-based post-equalization SINR
- LS channel-estimation MSE
- Wiener MMSE channel-estimation MSE
- Ergodic MIMO capacity
- Hard-decision goodput-style proxy
- Spectral-efficiency proxy
- Timing RMSE
- Coarse CFO RMSE
- Combined coarse-and-fine CFO RMSE
- Hard/soft coded-BER target crossings
- Measured soft-decision SNR gain

The reported capacity is an information-theoretic reference and is not interpreted as achieved coded throughput. The goodput and spectral-efficiency outputs are BER-based proxies rather than measured block-delivery rates.

---

## Executed Results

### Synchronization

| Quantity | Measured result |
|---|---:|
| True normalized CFO | 0.25 subcarrier spacings |
| Recovered versus genie BER at 30 dB | $6.060\times10^{-3}$ versus $6.059\times10^{-3}$ |
| Total CFO RMSE at 30 dB | $1.0\times10^{-3}$ subcarrier spacings |
| Timing RMSE floor | Approximately 11 samples |
| Uncompensated-CFO behavior | BER floor near 0.2 |
| Recovered-chain behavior | Overlaps the genie reference across the sweep |

The timing floor is caused by the known Schmidl-Cox metric plateau across the cyclic-prefix region. The detected positions remain inside the valid cyclic-prefix interval.

### 8×8 Results

| Quantity | Measured result |
|---|---:|
| Wiener versus LS estimation MSE at 30 dB | $1.5\times10^{-4}$ versus $1.5\times10^{-3}$ |
| MMSE versus ZF output SINR at 30 dB | 15.5 dB versus 8.5 dB |
| Ergodic capacity at 30 dB | 69.3 bit/s/Hz |
| Soft gain at coded BER $5\times10^{-2}$ | 4.30 dB |
| Soft gain at coded BER $10^{-1}$ | 4.07 dB |

Hard/soft crossings in the 64-QAM region:

| Target coded BER | Hard crossing | Soft crossing | Soft gain |
|---:|---:|---:|---:|
| $5\times10^{-2}$ | 28.06 dB | 23.76 dB | 4.30 dB |
| $10^{-1}$ | 25.10 dB | 21.03 dB | 4.07 dB |

### 16×16 Results

| Quantity | Measured result |
|---|---:|
| Ergodic capacity at 30 dB | 138.0 bit/s/Hz |
| High-SNR LS estimation floor | Approximately $7\times10^{-2}$ |
| Wiener estimation MSE at 30 dB | $3\times10^{-4}$ |
| Wiener advantage over LS at 30 dB | Approximately 200× |
| ZF output SINR at 30 dB | −2.2 dB |
| MMSE output SINR at 30 dB | 14.4 dB |
| Hard coded BER at 30 dB | $5.2\times10^{-2}$ |
| Soft coded BER at 30 dB | $1.1\times10^{-2}$ |
| Soft gain at coded BER $10^{-1}$ | 5.05 dB |

Hard/soft crossings in the 64-QAM region:

| Target coded BER | Hard crossing | Soft crossing | Soft gain |
|---:|---:|---:|---:|
| $5\times10^{-2}$ | Not reached by 30 dB | 24.45 dB | Not extrapolated |
| $10^{-1}$ | 27.09 dB | 22.04 dB | 5.05 dB |

### Controlled 8×8-versus-16×16 Findings

The executed comparison supports the following conclusions:

1. **Capacity doubled.**  
   The 30 dB ergodic capacity increased from 69.3 to 138.0 bit/s/Hz.

2. **Pilot scarcity affected LS estimation strongly.**  
   Doubling the number of transmit antennas on the same 256-subcarrier grid halved the pilot count per antenna. The 16×16 LS estimator reached a high-SNR interpolation floor, while the Wiener estimator retained its downward trend.

3. **ZF was highly sensitive to square-array scaling.**  
   The 16×16 ZF output SINR remained below 0 dB across the full sweep and reached only −2.2 dB at 30 dB.

4. **MMSE detection remained comparatively stable.**  
   The MMSE output SINR changed from 15.5 dB at 8×8 to 14.4 dB at 16×16, a penalty of approximately 1.1 dB.

5. **Soft information became more valuable at the larger array.**  
   At coded BER $10^{-1}$, the soft-over-hard separation increased from 4.07 dB at 8×8 to 5.05 dB at 16×16.

6. **The hard decoder absorbed most of the size penalty.**  
   In the 64-QAM region, the two soft-decoded curves remained close, while the 16×16 hard-decoded curve shifted approximately 2–3 dB to the right.

The main technical finding is that the value of **correlation-aware estimation, regularized detection, and reliability-calibrated soft decoding increases with array size**.

---

## Verification Record

The project uses an execution-first verification process: run the chain, compare each result against theoretically required behavior, isolate any inconsistency with an independent numerical experiment, correct the implementation, and rerun all affected results.

Four genuine defects were identified and corrected.

| Defect | Observed symptom | Independent diagnosis | Correction |
|---|---|---|---|
| Genie synchronization reference compensated the wrong signal | Ideal-reference BER was implausibly high | Audited the definition of the genie case | Compensated the received signal with the true CFO |
| Time-domain noise variance omitted the $1/N$ OFDM scaling | BER near 0.5, very high EVM, and large timing error at nominally high SNR | Reproduced a 24 dB SNR discrepancy using two noise scalings | Divided the time-domain noise variance by the FFT length |
| Preamble occupied the wrong zero-based subcarrier parity | CFO RMSE fixed at exactly 1.0 and recovered BER near 0.5, while the timing metric still appeared healthy | Reconstructed anti-identical time-domain halves and a −0.75 estimate for a true +0.25 CFO | Changed the MATLAB placement pattern to select zero-based even bins |
| Hard and soft branches used different MMSE symbol streams | Decoder gap included both gain correction and soft-information effects | Compared the two branch inputs directly | Generated both hard bits and soft LLRs from the same unbiased MMSE output |

This defect record is retained because verification is part of the engineering result, not only a preprocessing step.

---

## Key MATLAB Files

The report maps each algorithm to the MATLAB files responsible for its implementation.

### Main Execution and Comparison

| File | Responsibility |
|---|---|
| `main_phy_simulation.m` | Runs the synchronization study and the complete 8×8 MIMO-OFDM study |
| `main_phy_simulation_16x16.m` | Runs the complete 16×16 MIMO-OFDM study |
| `run_size_comparison.m` | Loads both CSV files, checks the SNR grids, generates overlays, and evaluates coded-BER crossings |

### Synchronization

| File | Responsibility |
|---|---|
| `generate_preamble.m` | Generates the repeated-half Schmidl-Cox preamble using zero-based even subcarriers |
| `schmidl_cox_metric.m` | Computes the timing autocorrelation, energy, and normalized metric |
| `estimate_coarse_cfo.m` | Estimates normalized coarse CFO from the correlation phase |
| `estimate_fine_cfo.m` | Estimates residual CFO from pilot phase drift |
| `apply_cfo.m` | Applies or compensates a time-domain CFO phase ramp |
| `demod_ofdm_symbol.m` | Removes the cyclic prefix and performs OFDM demodulation |

### Channel Estimation

| File | Responsibility |
|---|---|
| `ls_pilot_estimate.m` | Produces LS pilot estimates and spline interpolation across frequency |
| `compute_wiener_matrices.m` | Builds channel-correlation matrices from the delay-power profile |
| `wiener_mmse_estimate.m` | Applies the Wiener MMSE estimator to pilot observations |

### Detection and Soft Output

| File | Responsibility |
|---|---|
| `zf_equalize_mimo.m` | Performs per-subcarrier ZF detection |
| `mmse_equalize_soft.m` | Performs MMSE detection, gain correction, effective-variance calculation, and soft-output preparation |

### Adaptive Modulation, Decoding, and Metrics

| File | Responsibility |
|---|---|
| `amc_select_modulation.m` | Selects QPSK, 16-QAM, or 64-QAM from the configured SNR thresholds |
| `interp_snr_at_ber.m` | Interpolates target-BER crossings on a logarithmic BER axis |
| `compute_evm.m` | Computes RMS EVM |
| `compute_sinr.m` | Computes reference-based post-equalization SINR |
| `compute_mimo_capacity.m` | Computes the ergodic MIMO capacity reference |

The package also contains additional single-purpose helper files and an LLR sign-convention unit test.

---

## Generated Result Files

The main scripts export one aggregated table per configuration:

```text
results_8x8.csv
results_16x16.csv
```

Each table contains named metric columns across the common SNR grid. The size-comparison script:

1. verifies that both files exist,
2. verifies that their SNR grids match,
3. generates the 8×8/16×16 overlay figures,
4. computes coded-BER crossings from the stored values,
5. refuses to extrapolate when a requested target is outside the measured sweep.

This result-provenance chain ensures that reported numerical values are derived from saved execution outputs rather than manually transcribed from figures.

---

## Requirements

- MATLAB
- Communications Toolbox functions used by the implementation, including convolutional encoding, Viterbi decoding, and QAM modulation/demodulation
- Sufficient memory and execution time for the 16×16 Monte Carlo sweep

Before running the full sweep, confirm that the required toolbox functions are available:

```matlab
which qammod
which qamdemod
which poly2trellis
which convenc
which vitdec
```

---

## How to Run

Place all MATLAB source files in the project directory or add their containing folders to the MATLAB path.

### 1. Run the LLR Sign-Convention Test

Run the included LLR sign-convention unit test before the main simulation. The test should confirm that the soft-metric polarity used by the demapper matches the convention expected by the Viterbi decoder.

### 2. Run the 8×8 Study

```matlab
run('main_phy_simulation.m');
```

This script executes:

- the synchronization campaign,
- the 8×8 MIMO-OFDM campaign,
- metric aggregation,
- 8×8 figure generation,
- export of `results_8x8.csv`.

### 3. Run the 16×16 Study

```matlab
run('main_phy_simulation_16x16.m');
```

This script executes:

- the 16×16 MIMO-OFDM campaign,
- metric aggregation,
- 16×16 figure generation,
- export of `results_16x16.csv`.

### 4. Generate the Controlled Size Comparison

```matlab
run('run_size_comparison.m');
```

The comparison script requires both CSV result files. It checks their SNR grids before producing capacity, channel-estimation, detector-SINR, and coded-BER overlays.

### Recommended Clean Run

```matlab
clear;
clc;
close all;

run('main_phy_simulation.m');
run('main_phy_simulation_16x16.m');
run('run_size_comparison.m');
```

---

## Expected Figures

The executed package produces figures in the following groups:

### Synchronization

- Schmidl-Cox timing metric
- BER for genie, uncompensated, and recovered synchronization
- Coarse and total CFO RMSE
- Timing RMSE
- Synchronization EVM

### 8×8 MIMO-OFDM

- Uncoded and coded BER
- LS and Wiener estimation MSE
- ZF and MMSE output SINR
- ZF and MMSE EVM
- Ergodic capacity
- Goodput-style and spectral-efficiency proxies
- Adaptive-modulation selection
- Hard-versus-soft Viterbi coded BER

### 16×16 MIMO-OFDM

- Uncoded and coded BER
- LS and Wiener estimation MSE
- ZF and MMSE output SINR
- ZF and MMSE EVM
- Ergodic capacity
- Goodput-style and spectral-efficiency proxies
- Hard-versus-soft Viterbi coded BER

### Controlled Size Comparison

- 8×8/16×16 capacity overlay
- Four-curve channel-estimation MSE overlay
- Four-curve detector-SINR overlay
- Four-curve hard/soft coded-BER overlay

---

## Interpreting the BER Curves

The modulation order changes at 8 dB and 18 dB. The resulting BER curves are therefore not expected to decrease monotonically across the entire SNR sweep.

Each modulation region shows decreasing BER as SNR increases, followed by an upward step when the constellation changes:

```text
QPSK → 16-QAM → 64-QAM
```

This sawtooth behavior is a direct consequence of threshold-based adaptive modulation. Hard/soft SNR gains are therefore evaluated inside the 64-QAM region, where the compared curves use the same modulation order and cross the requested target.

---

## Planned Extensions

Natural next steps are:

- CQI-based adaptive modulation and coding
- BLER-targeted MCS selection
- Multiple convolutional-code rates through puncturing
- Quantized soft metrics for fixed-point receiver analysis
- Block-level CRC, BLER, and measured goodput
- Independent per-path Doppler using a sum-of-sinusoids model
- Successive interference cancellation
- Sphere detection
- Asymmetric $N_r>N_t$ many-antenna configurations
- Receiver-estimated effective-SINR mapping
- Runtime, memory, and operation-count profiling
- Embedded C/C++ or fixed-point implementation of selected receiver blocks

The CQI/BLER-based AMC extension should remain a separate advanced stage so that the baseline threshold-based study stays reproducible and its conclusions remain unchanged.

---

## Skills Demonstrated

This project provides practical evidence of experience in:

- OFDM waveform generation and demodulation
- Timing synchronization and CFO recovery
- Pilot design and channel estimation
- MIMO spatial multiplexing
- Linear-algebra-based ZF and MMSE detection
- Soft-output receiver design
- LLR calibration
- Convolutional coding and Viterbi decoding
- Hard-versus-soft decision analysis
- Adaptive modulation
- Monte Carlo simulation
- BER, EVM, SINR, MSE, capacity, and throughput analysis
- Controlled comparative experimentation
- Numerical verification and root-cause debugging
- Reproducible result export and provenance

These topics are directly relevant to PHY algorithm, modem, baseband, DSP, wireless system simulation, and receiver-development roles.

---

## Technical Report

The full report contains:

- complete system and signal models,
- mathematical derivations,
- five numbered algorithms,
- workflow diagrams,
- equation-to-code traceability,
- verification methodology,
- defect records,
- executed figures,
- 8×8 and 16×16 result tables,
- controlled size-comparison analysis,
- limitations and future work.

Report title:

> **Design, Verification, and Comparative Performance Evaluation of a Scalable 8×8 and 16×16 MIMO-OFDM PHY Simulator with Threshold-Based Adaptive Modulation and Fixed-Rate Channel Coding**

---

## References

1. T. M. Schmidl and D. C. Cox, “Robust frequency and timing synchronization for OFDM,” *IEEE Transactions on Communications*, vol. 45, no. 12, pp. 1613–1621, 1997.
2. J.-J. van de Beek, O. Edfors, M. Sandell, S. K. Wilson, and P. O. Börjesson, “On channel estimation in OFDM systems,” in *Proc. IEEE VTC*, 1995, pp. 815–819.
3. O. Edfors, M. Sandell, J.-J. van de Beek, S. K. Wilson, and P. O. Börjesson, “OFDM channel estimation by singular value decomposition,” *IEEE Transactions on Communications*, vol. 46, no. 7, pp. 931–939, 1998.
4. S. Coleri, M. Ergen, A. Puri, and A. Bahai, “Channel estimation techniques based on pilot arrangement in OFDM systems,” *IEEE Transactions on Broadcasting*, vol. 48, no. 3, pp. 223–229, 2002.
5. I. E. Telatar, “Capacity of multi-antenna Gaussian channels,” *European Transactions on Telecommunications*, vol. 10, no. 6, pp. 585–595, 1999.
6. T. L. Marzetta, “Noncooperative cellular wireless with unlimited numbers of base station antennas,” *IEEE Transactions on Wireless Communications*, vol. 9, no. 11, pp. 3590–3600, 2010.
7. E. G. Larsson, O. Edfors, F. Tufvesson, and T. L. Marzetta, “Massive MIMO for next generation wireless systems,” *IEEE Communications Magazine*, vol. 52, no. 2, pp. 186–195, 2014.
8. D. Tse and P. Viswanath, *Fundamentals of Wireless Communication*. Cambridge University Press, 2005.
9. A. Goldsmith, *Wireless Communications*. Cambridge University Press, 2005.
10. J. G. Proakis and M. Salehi, *Digital Communications*, 5th ed. McGraw-Hill, 2008.
11. A. J. Viterbi, “Error bounds for convolutional codes and an asymptotically optimum decoding algorithm,” *IEEE Transactions on Information Theory*, vol. 13, no. 2, pp. 260–269, 1967.
12. J. Hagenauer and P. Hoeher, “A Viterbi algorithm with soft-decision outputs and its applications,” in *Proc. IEEE GLOBECOM*, 1989, pp. 1680–1686.
13. W. C. Jakes, *Microwave Mobile Communications*. Wiley, 1974.
14. 3GPP, “Study on channel model for frequencies from 0.5 to 100 GHz,” TR 38.901.

---

## Author

**Md Moklesur Rahman**  
Independent Researcher, Finland  
Email: moklesur.eee@gmail.com  
GitHub: [dipucwc](https://github.com/dipucwc)

---

## Citation

```bibtex
@techreport{rahman2026mimoofdm,
  author      = {Md Moklesur Rahman},
  title       = {Design, Verification, and Comparative Performance Evaluation of a Scalable 8x8 and 16x16 MIMO-OFDM PHY Simulator with Threshold-Based Adaptive Modulation and Fixed-Rate Channel Coding},
  institution = {Independent Research},
  year        = {2026}
}
```
