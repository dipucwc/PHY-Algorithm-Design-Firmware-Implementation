%{
=========================================================================================================================
 create_cqi_amc_config.m — Central configuration for the Project 2 CQI-based AMC study
=========================================================================================================================

The function returns the configuration structure shared by the calibration script, the two online-adaptation main
scripts, the comparison script, and the verification gates. The PHY parameters replicate the verified Project 1
platform so that Project 2 results remain directly comparable with the Project 1 baseline. All Project 2 controller
parameters, the EESM calibration parameters, the adaptive Monte Carlo stopping limits, and the random seed are set
here so that one structure defines a reproducible run.
=========================================================================================================================
%}

function cfg = create_cqi_amc_config(Nt)

%% Project identification:
%%

cfg.projectVersion   = 'P2-CQI-AMC-v2.0';         % Project version tag written to every result file.

cfg.arrayLabel       = sprintf('%dx%d', Nt, Nt);  % Array label used in file names and result columns.


%% Verified Project 1 PHY platform:
%%

cfg.Nt             = Nt;                          % Number of transmit antennas.

cfg.Nr             = Nt;                          % Number of receive antennas (square array).

cfg.Nfft           = 256;                         % FFT size and number of subcarriers.

cfg.cpLen          = 20;                          % Cyclic prefix length in samples.

cfg.numDataSymbols = 13;                          % Number of data OFDM symbols per slot.

cfg.sampleRate     = 30.72e6;                     % Sample rate in hertz.

cfg.symbolDur      = (cfg.Nfft + cfg.cpLen) / cfg.sampleRate;  % OFDM symbol duration in seconds.

cfg.tapDelays_samp = [0, 1, 2, 4, 6];             % Integer tap delays of the TDL-A profile in samples.

cfg.tapPowers_dB   = [0, -2.2, -4.0, -6.5, -9.0]; % Tap powers of the TDL-A profile in decibels.

cfg.velocity_kmh   = 30;                          % Terminal speed for the common-Doppler phase evolution.

cfg.fc             = 3.5e9;                       % Carrier frequency in hertz.

cfg.fd_max         = (cfg.velocity_kmh/3.6) * cfg.fc / 3e8;  % Maximum Doppler frequency in hertz.


%% Channel code:
%%

cfg.constraintLength = 7;                         % Constraint length of the mother convolutional code.

cfg.codePolynomials  = [133 171];                 % Generator polynomials of the rate-1/2 mother code.

cfg.tailBits         = cfg.constraintLength - 1;  % Tail bits appended for code termination.

cfg.tracebackDepth   = 35;                        % Viterbi traceback depth.


%% CRC:
%%

cfg.crcLength     = 16;                           % CRC length in bits.

cfg.crcPolynomial = [1 0 0 0 1 0 0 0 0 0 0 1 0 0 0 0 1];  % CRC-16-CCITT generator polynomial x^16+x^12+x^5+1.


%% Link-adaptation controller:
%%

cfg.targetBler          = 0.10;                   % Target block error rate.

cfg.initialMcsIndex     = 0;                      % MCS used in the first slot before any CQI is available.

cfg.cqiDelaySlots       = 1;                      % CQI feedback delay in slots for the delayed methods.

cfg.cqiErrorProbability = 0;                      % Probability of a corrupted CQI report (optional experiment).

cfg.effectiveSinrMethod = "eesm";                 % Primary effective-SINR mapping.

cfg.effectiveSinrMappings = ["eesm", "mean", "minimum"];  % Mappings calibrated and selectable online, each with its own curve file.

cfg.selectionCriterion  = "average";              % Per-layer prediction criterion: "average" aligns with the aggregated block BLER; "worst" is conservative.

cfg.eesmBeta = [1.5 1.6 1.7 4.5 5.5 6.5 12.0 16.0 20.0];  % Configured EESM calibration parameter per MCS index 0..8.


%% Outer-loop link adaptation:
%%

cfg.ollaStepDownDb = 0.5;                         % Offset decrease in decibels after a CRC failure.

cfg.ollaStepUpDb   = cfg.ollaStepDownDb * cfg.targetBler / (1 - cfg.targetBler);  % Offset increase after a success.

cfg.ollaOffsetInit = 0;                           % Initial outer-loop offset in decibels.

cfg.ollaOffsetMin  = -10;                         % Lower clamp of the outer-loop offset in decibels.

cfg.ollaOffsetMax  = 10;                          % Upper clamp of the outer-loop offset in decibels.


%% Online-adaptation sweep:
%%

cfg.snrGrid_dB = 0:2:30;                          % SNR sweep of the online-adaptation study.

cfg.numSlots   = 100;                             % Monte Carlo slots per SNR point.

cfg.convergenceSnrDb = 20;                        % SNR point used for the per-slot convergence plots.


%% Calibration sweep:
%%

cfg.minimumBlockErrors = 100;                     % Adaptive stopping: minimum block errors per calibration point.

cfg.maximumBlocks      = 2000;                    % Adaptive stopping: maximum blocks per calibration point.

cfg.calibrationSnrWindows = { ...                 % Per-MCS SNR windows extended until the target crossing or the 30 dB ceiling.
    4:2:16;   6:2:22;   8:2:24; ...               % MCS 0-2 (QPSK 1/2, 2/3, 3/4).
    12:2:28;  14:2:30;  16:2:30; ...              % MCS 3-5 (16-QAM 1/2, 2/3, 3/4).
    20:2:30;  22:2:30;  24:2:30};                 % MCS 6-8 (64-QAM 1/2, 2/3, 3/4).

%% Reproducibility:
%%

cfg.randomSeed     = 7;                           % Master random seed of the study.

cfg.slotSeedStride = 1000;                        % Seed stride separating SNR points in the per-slot seeding.

end
