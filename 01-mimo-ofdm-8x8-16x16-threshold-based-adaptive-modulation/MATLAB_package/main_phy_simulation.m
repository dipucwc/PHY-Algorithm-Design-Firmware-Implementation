
%% *** PHY/Modem Algorithm Simulation - 8x8 MIMO-OFDM ***:
%% This is the main code for the simulation:
%{
The main script executes a two-part physical-layer simulation over a shared total-SNR range. Part A evaluates OFDM
synchronization on a single-antenna link, and Part B evaluates an 8x8 MIMO-OFDM link. The script initializes the MATLAB
environment, adds the project directory to the path, seeds the random-number generator for reproducible Monte Carlo runs,
and sets the shared system parameters used by both parts.

Part A processes a Schmidl-Cox preamble followed by data OFDM symbols. For each SNR point and Monte Carlo trial the
transmitted frame passes through a 3GPP TDL-A multipath channel, receives a carrier-frequency-offset phase ramp, and is
corrupted by additive noise. The receiver detects the timing position from the normalized Schmidl-Cox metric, estimates a
coarse carrier frequency offset from the preamble autocorrelation phase, refines it from the pilot inter-symbol phase drift,
and compensates the offset. Three cases are demodulated at every trial: perfect synchronization, uncompensated offset, and
the recovered synchronization. The script accumulates bit-error rate, error vector magnitude, carrier-offset estimation
error, and timing error across all trials.

Part B processes an 8x8 MIMO-OFDM slot. A comb pilot pattern assigns each transmit antenna a non-overlapping subset of
subcarriers, so the pilot symbol observed at every subcarrier comes from a single transmit antenna. The channel is a
time-varying TDL-A realization with common-Doppler phase evolution across the slot. The receiver forms a least-squares channel
estimate from the pilot symbol and a Wiener MMSE estimate from the precomputed channel statistics, and equalizes the data symbols per subcarrier with zero-forcing and MMSE
detectors. The MMSE detector forms a biased intermediate estimate and a gain-corrected unbiased estimate. The common
unbiased estimate is used for uncoded BER, EVM, SINR, hard-decision demapping, and soft-decision LLR generation. Adaptive modulation selects the QAM order, and the rate-1/2 convolutional code
is decoded twice, once with hard-decision Viterbi on the demodulated bits and once with soft-decision Viterbi on the
log-likelihood ratios, so that the coding gain of soft decoding is measured directly. The script accumulates bit-error rate,
channel-estimation mean-square error, post-equalization signal-to-interference-plus-noise ratio, error vector magnitude,
ergodic capacity, and throughput.

After both sweeps complete, the script generates the synchronization figures A1 to A5 and the MIMO figures B1 to B7.

Auxiliary functions:

    generate_preamble
        Builds the Schmidl-Cox preamble whose two time-domain halves are identical, enabling joint timing and
        carrier-offset estimation from a single OFDM symbol.

    schmidl_cox_metric
        Computes the normalized Schmidl-Cox timing metric from the received signal using cumulative-sum autocorrelation.

    estimate_coarse_cfo
        Estimates the coarse carrier frequency offset from the phase of the preamble autocorrelation at the detected timing.

    estimate_fine_cfo
        Estimates the residual carrier frequency offset from the pilot phase drift between two consecutive data symbols.

    apply_cfo
        Applies a carrier-frequency-offset phase ramp for either impairment or compensation.

    apply_tdla_channel
        Convolves a signal frame with the TDL-A tapped-delay-line channel.

    demod_ofdm_symbol
        Demodulates the single-antenna data OFDM symbols using least-squares pilot estimation and zero-forcing.

    compute_wiener_matrices
        Precomputes the pilot-to-pilot and all-to-pilot channel correlation matrices used by the Wiener MMSE estimator.

    mimo_freq_response
        Builds the receive-by-transmit-by-subcarrier channel matrix with common-Doppler phase evolution at a given symbol time.

    ls_pilot_estimate
        Estimates the MIMO channel at the pilot subcarriers and interpolates to all subcarriers with a spline.

    wiener_mmse_estimate
        Applies the precomputed Wiener filter to the pilot observations to produce the MMSE channel estimate.

    zf_equalize_mimo
        Recovers the transmit symbols at one subcarrier with the zero-forcing pseudo-inverse.

    mmse_equalize_mimo
        Recovers the transmit symbols at one subcarrier with the regularized MMSE equalizer.

    mmse_equalize_soft
        Recovers the transmit symbols at one subcarrier and returns the biased estimate, the unbiased estimate, and the
        per-stream effective noise variance used for soft-decision log-likelihood ratios.

    interp_snr_at_ber
        Returns the SNR at which a BER curve crosses a target value by interpolation on the logarithmic axis.

    amc_select_modulation
        Selects the QAM modulation order from the operating SNR.

    compute_mimo_capacity
        Computes the ergodic capacity from the singular values of the per-subcarrier channel.

    compute_evm
        Computes the RMS error vector magnitude as a percentage.

    compute_sinr
        Computes the post-equalization signal-to-interference-plus-noise ratio in decibels.

Input:

    randomSeed        Random-number-generator seed used for reproducible Monte Carlo runs.
    Nfft              FFT size and number of subcarriers.
    cpLen             Cyclic prefix length in samples.
    SNRdB_list        Vector of total-SNR points in decibels.
    tapDelays_samp    Integer TDL-A tap delays in samples.
    tapPowers_dB      TDL-A tap powers in decibels.
    velocity_kmh      Terminal velocity used for the maximum Doppler frequency.
    Nt                Number of transmit antennas.
    Nr                Number of receive antennas.

Output:

    Part A arrays     BER, EVM, carrier-offset RMSE, and timing RMSE versus SNR.
    Part B arrays     BER, channel-estimation MSE, SINR, EVM, capacity, and throughput versus SNR.
    Figures A1-A5     Synchronization performance figures.
    Figures B1-B7     MIMO-OFDM performance figures.
%}


%% Initialization:
%%

clc;
clear;
close all;

addpath(pwd);                                     % Add the project directory so every function file is on the path.

randomSeed = 7;                                   % Fix the seed for a reproducible Monte Carlo run.

rng(randomSeed);                                  % Seed the random generator before any random draw.


%% Shared system parameters:
%%

Nfft       = 256;                                 % FFT size and number of subcarriers.

cpLen      = 20;                                  % Cyclic prefix length in samples.

symbolLen  = Nfft + cpLen;                        % Total OFDM symbol length including the cyclic prefix.

SNRdB_list = 0:2:30;                              % Total-SNR sweep in decibels.

numSNR     = numel(SNRdB_list);                   % Number of SNR points in the sweep.


%% TDL-A channel profile:
%%

tapDelays_samp = [0, 1, 2, 4, 6];                 % Integer tap delays of the TDL-A profile in samples.

tapPowers_dB   = [0.0, -2.2, -4.0, -6.5, -9.0];   % Tap powers of the TDL-A profile in decibels.

tapPowers      = 10.^(tapPowers_dB/10);           % Convert the tap powers to the linear scale.

tapPowers      = tapPowers / sum(tapPowers);      % Normalize the profile to unit total power.

numTaps        = numel(tapDelays_samp);           % Number of multipath taps.

maxDelay       = max(tapDelays_samp);             % Maximum tap delay used for the cyclic-prefix check.


%% Doppler parameters:
%%

velocity_kmh = 30;                                % Terminal velocity in kilometres per hour.

fc           = 3.5e9;                             % Carrier frequency in hertz.

fd_max       = (velocity_kmh/3.6) * fc / 3e8;     % Maximum Doppler frequency in hertz.

symbolDur    = symbolLen / 30.72e6;               % OFDM symbol duration in seconds.

assert(maxDelay < cpLen, ...                      % Confirm the cyclic prefix covers the maximum delay spread.
    'Cyclic prefix must exceed the maximum channel delay spread');


%% Part A synchronization parameters:
%%

fprintf('Part A: OFDM synchronization\n');

M_sync           = 16;                            % QAM order used for the synchronization data symbols.

bpsSym_sync      = log2(M_sync);                  % Bits per QAM symbol for the synchronization data.

L                = Nfft / 2;                       % Half-symbol length used by the Schmidl-Cox metric.

pilotSpacing     = 8;                             % Pilot spacing in subcarriers for the single-antenna link.

pilotIdx_sync    = (1:pilotSpacing:Nfft).';       % Pilot subcarrier indices for the single-antenna link.

dataIdx_sync     = setdiff((1:Nfft).', pilotIdx_sync);  % Data subcarrier indices for the single-antenna link.

numDataSC_sync   = length(dataIdx_sync);          % Number of data subcarriers per symbol.

numDataSyms_sync = 8;                             % Number of data OFDM symbols per frame.

numTrials        = 400;                           % Number of Monte Carlo trials per SNR point.

epsilon_true     = 0.25;                          % True normalized carrier frequency offset in subcarrier spacings.


%% Preamble generation:
%%

[preamble, ~, preambleLen] = ...                  % Build the fixed Schmidl-Cox preamble reused at every trial.
    generate_preamble(Nfft, cpLen, M_sync);


%% Part A result arrays:
%%

BER_perfect     = zeros(numSNR, 1);               % BER with perfect synchronization.

BER_cfo_only    = zeros(numSNR, 1);               % BER with an uncompensated carrier offset.

BER_after_sync  = zeros(numSNR, 1);               % BER after Schmidl-Cox and carrier-offset recovery.

EVM_perfect     = zeros(numSNR, 1);               % EVM with perfect synchronization.

EVM_after_sync  = zeros(numSNR, 1);               % EVM after synchronization recovery.

CFO_RMSE_coarse = zeros(numSNR, 1);               % RMSE of the coarse carrier-offset estimate.

CFO_RMSE_fine   = zeros(numSNR, 1);               % RMSE of the coarse-plus-fine carrier-offset estimate.

Timing_RMSE     = zeros(numSNR, 1);               % RMSE of the Schmidl-Cox timing estimate.


%% Part A SNR sweep:
%%

for snrIdx = 1:numSNR                             % Process every SNR point in the synchronization sweep.

    SNRdB    = SNRdB_list(snrIdx);                % Select the current SNR value.

    noiseVar = 1 / (Nfft * 10^(SNRdB/10));        % Convert the SNR to a time-domain noise variance scaled by the FFT gain.

    err_perf = 0;                                 % Accumulated bit errors for the perfect-sync case.
    err_cfo  = 0;                                 % Accumulated bit errors for the uncompensated case.
    err_sync = 0;                                 % Accumulated bit errors for the recovered case.
    tot_bits = 0;                                 % Accumulated number of evaluated bits.

    evm_sq_perf = 0;                              % Accumulated squared EVM for the perfect-sync case.
    evm_sq_sync = 0;                              % Accumulated squared EVM for the recovered case.

    cfo_sq_coarse = 0;                            % Accumulated squared coarse carrier-offset error.
    cfo_sq_fine   = 0;                            % Accumulated squared coarse-plus-fine carrier-offset error.
    tim_sq        = 0;                            % Accumulated squared timing error.

    for trial = 1:numTrials                       % Process every Monte Carlo trial at the current SNR.


        %% Transmitter frame generation:
        %%

        numBits = numDataSC_sync * bpsSym_sync * numDataSyms_sync;  % Number of data bits per frame.

        txBits  = randi([0 1], numBits, 1);       % Generate the random data bits.

        txQAM   = qammod(txBits, M_sync, ...       % Map the bits to unit-power QAM symbols.
            'InputType', 'bit', 'UnitAveragePower', true);

        txSC    = reshape(txQAM, numDataSC_sync, numDataSyms_sync);  % Arrange symbols by subcarrier and OFDM symbol.

        txDataTime = zeros(numDataSyms_sync * symbolLen, 1);        % Preallocate the time-domain data waveform.

        for s = 1:numDataSyms_sync                % Build each data OFDM symbol.
            X = zeros(Nfft, 1);                   % Initialize the frequency-domain grid.
            X(pilotIdx_sync) = 1 + 0j;            % Insert unit-power pilot tones.
            X(dataIdx_sync)  = txSC(:, s);        % Insert the QAM data symbols.
            x = ifft(X, Nfft);                    % Transform the grid to the time domain.
            txDataTime((s-1)*symbolLen+1 : s*symbolLen) = ...  % Prepend the cyclic prefix and store the symbol.
                [x(end-cpLen+1:end); x];
        end

        txFrame  = [preamble; txDataTime];        % Prepend the preamble to form the complete frame.

        frameLen = length(txFrame);               % Total transmitted frame length.


        %% TDL-A channel and impairments:
        %%

        h_taps = zeros(numTaps, 1);               % Preallocate the complex tap gains.

        for i = 1:numTaps                         % Draw one Rayleigh tap gain per path.
            h_taps(i) = sqrt(tapPowers(i)/2) * (randn + 1j*randn);
        end

        rxChan = apply_tdla_channel( ...          % Pass the frame through the TDL-A channel.
            txFrame, h_taps, tapDelays_samp);

        rxImp  = apply_cfo(rxChan, ...            % Apply the transmit carrier-frequency-offset phase ramp.
            epsilon_true, Nfft);

        noise  = sqrt(noiseVar/2) * ...           % Generate the complex additive noise realization.
            (randn(frameLen,1) + 1j*randn(frameLen,1));

        rxRaw  = rxImp + noise;                   % Form the received signal with impairment and noise.


        %% Timing detection:
        %%

        [Lambda, M_sc, ~, ~] = schmidl_cox_metric( ...  % Compute the normalized Schmidl-Cox timing metric.
            rxRaw, L, preambleLen, cpLen, frameLen);

        [~, d_hat] = max(Lambda);                 % Detect the timing position from the metric peak.

        d_true = cpLen + 1;                       % True preamble-body start position.

        tim_sq = tim_sq + (d_hat - d_true)^2;     % Accumulate the squared timing error.


        %% Coarse carrier-offset estimation:
        %%

        eps_coarse    = estimate_coarse_cfo(M_sc, d_hat);       % Estimate the coarse offset from the autocorrelation phase.

        cfo_sq_coarse = cfo_sq_coarse + (eps_coarse - epsilon_true)^2;  % Accumulate the squared coarse error.

        rxCoarse = apply_cfo(rxRaw, -eps_coarse, Nfft);         % Compensate the coarse offset.


        %% Fine carrier-offset estimation:
        %%

        eps_fine  = estimate_fine_cfo( ...        % Estimate the residual offset from pilot phase drift.
            rxCoarse, preambleLen, symbolLen, Nfft, pilotIdx_sync);

        eps_total = eps_coarse + eps_fine;        % Combine the coarse and fine estimates.

        cfo_sq_fine = cfo_sq_fine + (eps_total - epsilon_true)^2;  % Accumulate the squared combined error.

        rxSync = apply_cfo(rxRaw, -eps_total, Nfft);            % Compensate the combined offset.

        dataStartIdx = preambleLen + 1;           % First sample of the first data symbol.


        %% Three-case demodulation:
        %%

        rxPerfect = apply_cfo(rxRaw, ...          % Perfect-sync reference: compensate the received signal with the true offset.
            -epsilon_true, Nfft);

        [bA, evmA] = demod_ofdm_symbol( ...       % Demodulate the perfect-sync case.
            rxPerfect, dataStartIdx, numDataSyms_sync, ...
            Nfft, cpLen, pilotIdx_sync, dataIdx_sync, M_sync, txQAM);

        bB = demod_ofdm_symbol( ...               % Demodulate the uncompensated case.
            rxRaw, dataStartIdx, numDataSyms_sync, ...
            Nfft, cpLen, pilotIdx_sync, dataIdx_sync, M_sync, txQAM);

        [bC, evmC] = demod_ofdm_symbol( ...       % Demodulate the recovered case.
            rxSync, dataStartIdx, numDataSyms_sync, ...
            Nfft, cpLen, pilotIdx_sync, dataIdx_sync, M_sync, txQAM);

        nB = min([length(txBits), length(bA), ...  % Use the common bit length across the three cases.
            length(bB), length(bC)]);

        err_perf = err_perf + sum(txBits(1:nB) ~= bA(1:nB));   % Accumulate perfect-sync bit errors.

        err_cfo  = err_cfo  + sum(txBits(1:nB) ~= bB(1:nB));   % Accumulate uncompensated bit errors.

        err_sync = err_sync + sum(txBits(1:nB) ~= bC(1:nB));   % Accumulate recovered bit errors.

        tot_bits = tot_bits + nB;                 % Accumulate the number of evaluated bits.

        evm_sq_perf = evm_sq_perf + evmA^2;       % Accumulate the perfect-sync squared EVM.

        evm_sq_sync = evm_sq_sync + evmC^2;       % Accumulate the recovered squared EVM.

    end


    %% Part A aggregation:
    %%

    BER_perfect(snrIdx)    = err_perf / tot_bits;             % Aggregate the perfect-sync BER.

    BER_cfo_only(snrIdx)   = err_cfo  / tot_bits;             % Aggregate the uncompensated BER.

    BER_after_sync(snrIdx) = err_sync / tot_bits;            % Aggregate the recovered BER.

    EVM_perfect(snrIdx)    = sqrt(evm_sq_perf / numTrials) * 100;  % Aggregate the perfect-sync EVM in percent.

    EVM_after_sync(snrIdx) = sqrt(evm_sq_sync / numTrials) * 100;  % Aggregate the recovered EVM in percent.

    CFO_RMSE_coarse(snrIdx) = sqrt(cfo_sq_coarse / numTrials);    % Aggregate the coarse carrier-offset RMSE.

    CFO_RMSE_fine(snrIdx)   = sqrt(cfo_sq_fine / numTrials);      % Aggregate the combined carrier-offset RMSE.

    Timing_RMSE(snrIdx)     = sqrt(tim_sq / numTrials);          % Aggregate the timing RMSE.

    fprintf('SNR %2d dB  BER_perf %.3e  BER_sync %.3e  CFO_RMSE %.4f  Tim_RMSE %.2f\n', ...
        SNRdB, BER_perfect(snrIdx), BER_after_sync(snrIdx), ...
        CFO_RMSE_fine(snrIdx), Timing_RMSE(snrIdx));

end


%% Part B MIMO parameters:
%%

fprintf('\nPart B: 8x8 MIMO-OFDM\n');

Nt             = 8;                               % Number of transmit antennas.

Nr             = 8;                               % Number of receive antennas.

numDataSymbols = 13;                              % Number of data OFDM symbols per slot.

numSlots       = 100;                             % Number of Monte Carlo slots per SNR point.

assert(mod(Nfft, Nt) == 0, ...                    % Confirm the subcarrier count divides evenly among the transmit antennas.
    'FFT size must divide evenly among the transmit antennas');

numPilots_per_tx = Nfft / Nt;                     % Number of pilot subcarriers per transmit antenna.


%% Comb pilot pattern:
%%

pilotIdx_mimo = cell(Nt, 1);                      % Pilot subcarrier indices per transmit antenna.

pilotSC_tx    = zeros(Nfft, 1);                   % Active transmit antenna at each subcarrier.

for n = 1:Nt                                      % Assign a non-overlapping pilot comb to each transmit antenna.
    pilotIdx_mimo{n} = (n:Nt:Nfft).';            % Subcarriers used by transmit antenna n.
    pilotSC_tx(pilotIdx_mimo{n}) = n;             % Record the active antenna at those subcarriers.
end


%% Convolutional code:
%%

trellis  = poly2trellis(7, [133 171]);           % Rate-1/2 constraint-length-7 convolutional code.

codeRate = 1/2;                                   % Code rate.

tbDepth  = 5 * 7;                                 % Viterbi traceback depth.


%% Wiener correlation matrices:
%%

[R_PP, R_FP, ~] = compute_wiener_matrices( ...    % Precompute the pilot and all-to-pilot correlation matrices.
    tapPowers, tapDelays_samp, Nfft, pilotIdx_mimo, Nt);


%% Part B result arrays:
%%

BER_ZF      = zeros(numSNR, 1);                   % BER of the LS plus zero-forcing chain.

BER_MMSE    = zeros(numSNR, 1);                   % BER of the Wiener plus MMSE chain.

BER_coded   = zeros(numSNR, 1);                   % BER of the coded chain after hard-decision Viterbi decoding.

BER_coded_soft = zeros(numSNR, 1);                % BER of the coded chain after soft-decision Viterbi decoding.

EVM_ZF      = zeros(numSNR, 1);                   % EVM of the zero-forcing chain.

EVM_MMSE    = zeros(numSNR, 1);                   % EVM of the MMSE chain.

SINR_ZF     = zeros(numSNR, 1);                   % Post-equalization SINR of the zero-forcing chain.

SINR_MMSE   = zeros(numSNR, 1);                   % Post-equalization SINR of the MMSE chain.

MSE_LS      = zeros(numSNR, 1);                   % Channel-estimation MSE of the LS estimator.

MSE_Wiener  = zeros(numSNR, 1);                   % Channel-estimation MSE of the Wiener estimator.

Capacity    = zeros(numSNR, 1);                   % Ergodic capacity.

Throughput  = zeros(numSNR, 1);                   % Hard-decision coded goodput proxy.

SpectralEff = zeros(numSNR, 1);                   % Spectral efficiency.

selectedMod = strings(numSNR, 1);                 % Modulation selected at each SNR point.


%% Part B SNR sweep:
%%

for snrIdx = 1:numSNR                             % Process every SNR point in the MIMO sweep.

    SNRdB     = SNRdB_list(snrIdx);               % Select the current SNR value.

    SNRlinear = 10^(SNRdB/10);                    % Convert the SNR to the linear scale.

    noiseVar  = 1 / SNRlinear;                    % Convert the SNR to a noise variance.


    %% Adaptive modulation:
    %%

    [M, modName, bitsPerSym] = amc_select_modulation(SNRdB);  % Select the modulation order from the SNR.

    selectedMod(snrIdx) = modName;                % Record the selected modulation.

    numTxBits   = Nt * Nfft * bitsPerSym * numDataSymbols;   % Number of transmit bits per slot.

    numInfoBits = floor(numTxBits * codeRate);    % Number of information bits before coding.

    numInfoBits = numInfoBits - mod(numInfoBits, 8);         % Align the information length to a byte boundary.


    %% Wiener filter for the current SNR:
    %%

    W = cell(Nt, 1);                              % Wiener filter per transmit antenna.

    for n = 1:Nt                                  % Build the filter from the correlation matrices and noise variance.
        W{n} = R_FP{n} / (R_PP{n} + noiseVar * eye(numPilots_per_tx));
    end


    %% Monte Carlo accumulators:
    %%

    eBits_ZF = 0;                                 % Accumulated zero-forcing bit errors.
    eBits_MMSE = 0;                               % Accumulated MMSE bit errors.
    eBits_coded = 0;                              % Accumulated hard-decision coded bit errors.
    eBits_coded_soft = 0;                         % Accumulated soft-decision coded bit errors.
    tBits_unc = 0;                                % Accumulated uncoded evaluated bits.
    tBits_info = 0;                               % Accumulated information evaluated bits.

    evmS_ZF = 0;                                  % Accumulated zero-forcing EVM.
    evmS_MMSE = 0;                                % Accumulated MMSE EVM.
    sinrS_ZF = 0;                                 % Accumulated zero-forcing SINR.
    sinrS_MMSE = 0;                               % Accumulated MMSE SINR.
    mseS_LS = 0;                                  % Accumulated LS estimation MSE.
    mseS_W = 0;                                   % Accumulated Wiener estimation MSE.
    capS = 0;                                     % Accumulated capacity.

    for slotIdx = 1:numSlots                      % Process every Monte Carlo slot at the current SNR.


        %% Channel realization:
        %%

        initG  = zeros(Nr, Nt, numTaps);          % Preallocate the initial complex tap gains.

        initPh = 2*pi*rand(Nr, Nt, numTaps);      % Draw the initial random tap phases.

        for i = 1:numTaps                         % Draw one Rayleigh tap-gain matrix per path.
            initG(:,:,i) = sqrt(tapPowers(i)) * ...
                (randn(Nr,Nt) + 1j*randn(Nr,Nt)) / sqrt(2);
        end


        %% Source bits and encoding:
        %%

        infoBits  = randi([0 1], numInfoBits, 1); % Generate the information bits.

        codedBits = convenc(infoBits, trellis);   % Encode the information bits.

        if numel(codedBits) < numTxBits           % Pad the coded stream when it is shorter than one slot.
            txBits = [codedBits; ...
                randi([0 1], numTxBits-numel(codedBits), 1)];
        else                                      % Truncate the coded stream when it is longer than one slot.
            txBits = codedBits(1:numTxBits);
        end

        txQAM  = qammod(txBits, M, ...            % Map the transmit bits to unit-power QAM symbols.
            'InputType', 'bit', 'UnitAveragePower', true);

        txGrid = reshape(txQAM, Nt, Nfft, numDataSymbols);  % Arrange symbols by antenna, subcarrier, and OFDM symbol.


        %% Pilot reception:
        %%

        H_freq_pilot = mimo_freq_response( ...    % Build the channel matrix at the pilot symbol time.
            initG, initPh, tapDelays_samp, numTaps, Nfft, fd_max, 0);

        Y_pilot = zeros(Nr, Nfft);                % Preallocate the received pilot grid.

        for k = 1:Nfft                            % Receive the pilot symbol at each subcarrier.
            n_active = pilotSC_tx(k);             % Active transmit antenna at this subcarrier.
            H_k      = H_freq_pilot(:, n_active, k);  % Channel column of the active antenna.
            noise_k  = sqrt(noiseVar/2) * (randn(Nr,1) + 1j*randn(Nr,1));  % Pilot noise realization.
            Y_pilot(:,k) = H_k * 1 + noise_k;    % Received pilot with a unit pilot symbol.
        end


        %% Channel estimation:
        %%

        H_LS_est   = ls_pilot_estimate( ...       % Form the LS channel estimate from the pilot grid.
            Y_pilot, pilotIdx_mimo, Nr, Nt, Nfft);

        H_MMSE_est = wiener_mmse_estimate( ...     % Form the Wiener MMSE channel estimate.
            Y_pilot, pilotIdx_mimo, W, Nr, Nt, Nfft);

        H_true_est = H_freq_pilot;                % True channel used for the estimation-error metric.

        mseS_LS = mseS_LS + ...                   % Accumulate the LS estimation MSE.
            mean(abs(H_true_est(:) - H_LS_est(:)).^2);

        mseS_W  = mseS_W + ...                    % Accumulate the Wiener estimation MSE.
            mean(abs(H_true_est(:) - H_MMSE_est(:)).^2);


        %% Ergodic capacity:
        %%

        capS = capS + compute_mimo_capacity( ...  % Accumulate the capacity of the pilot-time channel.
            H_freq_pilot, SNRlinear, Nfft, Nt);


        %% Data equalization:
        %%

        rxGrid_ZF   = zeros(Nt, Nfft, numDataSymbols);  % Preallocate the zero-forcing output grid.

        rxGrid_MMSE = zeros(Nt, Nfft, numDataSymbols);  % Preallocate the biased MMSE output grid.

        rxGrid_MMSE_soft = zeros(Nt, Nfft, numDataSymbols);  % Preallocate the unbiased MMSE output grid.

        nvarGrid    = zeros(Nt, Nfft, numDataSymbols);  % Preallocate the per-stream effective noise variance.

        for symD = 1:numDataSymbols               % Equalize each data OFDM symbol.

            sym_t = symD * symbolDur;             % Symbol time offset used for Doppler evolution.

            H_freq_data = mimo_freq_response( ...  % Build the channel matrix at the data symbol time.
                initG, initPh, tapDelays_samp, numTaps, Nfft, fd_max, sym_t);

            X_sym = squeeze(txGrid(:,:,symD));    % Transmit symbols of the current OFDM symbol.

            for k = 1:Nfft                        % Equalize each subcarrier.

                H_true_k = squeeze(H_freq_data(:,:,k)) / sqrt(Nt);  % True channel scaled for the transmit-power split.

                x_k = X_sym(:, k);                % Transmit symbol vector at this subcarrier.

                n_k = sqrt(noiseVar/2) * (randn(Nr,1) + 1j*randn(Nr,1));  % Data noise realization.

                y_k = H_true_k * x_k + n_k;       % Received data vector at this subcarrier.

                H_ZF_k = squeeze(H_LS_est(:,:,k)) / sqrt(Nt);       % LS estimate scaled to match the data channel.

                rxGrid_ZF(:,k,symD) = zf_equalize_mimo(H_ZF_k, y_k);  % Apply the zero-forcing equalizer.

                H_MK = squeeze(H_MMSE_est(:,:,k)) / sqrt(Nt);       % Wiener estimate scaled to match the data channel.

                [xb, xs, nv] = mmse_equalize_soft( ...  % Apply the soft-output MMSE equalizer.
                    H_MK, y_k, noiseVar, Nt);

                rxGrid_MMSE(:,k,symD)      = xb;   % Biased MMSE output retained only for diagnostic or reference analysis.

                rxGrid_MMSE_soft(:,k,symD) = xs;  % Store the common unbiased estimate for metrics and both decoder paths.

                nvarGrid(:,k,symD)         = nv;  % Store the per-stream effective noise variance.

            end
        end


        %% Uncoded demodulation:
        %%

        txData_all = txGrid(:);                   % Reference transmit symbols for the metric calculation.

        rxZF_all   = rxGrid_ZF(:);                % Zero-forcing equalized symbols.

        % Use the common gain-corrected unbiased MMSE output for BER, EVM, SINR, and decoder comparisons.
        rxMM_all   = rxGrid_MMSE_soft(:);         % Common unbiased MMSE stream for the uncoded MMSE metrics.

        rxBits_ZF   = qamdemod(rxZF_all, M, ...   % Demodulate the zero-forcing symbols.
            'OutputType', 'bit', 'UnitAveragePower', true);

        rxBits_MMSE = qamdemod(rxGrid_MMSE_soft(:), M, ...   % Demodulate the common unbiased MMSE stream for the hard branch.
            'OutputType', 'bit', 'UnitAveragePower', true);

        eBits_ZF   = eBits_ZF + sum(txBits ~= rxBits_ZF);      % Accumulate zero-forcing bit errors.

        eBits_MMSE = eBits_MMSE + sum(txBits ~= rxBits_MMSE);  % Accumulate MMSE bit errors.

        tBits_unc  = tBits_unc + numel(txBits);   % Accumulate the number of uncoded bits.


        %% Viterbi decoding:
        %%

        nCoded = numel(codedBits);                % Number of coded bits produced by the encoder.

        rxDec  = vitdec(rxBits_MMSE(1:nCoded), ...  % Decode the MMSE bit stream.
            trellis, tbDepth, 'trunc', 'hard');

        rxDec  = rxDec(1:numInfoBits);            % Keep the information bits.

        eBits_coded = eBits_coded + sum(infoBits ~= rxDec);   % Accumulate hard-decision coded bit errors.

        tBits_info  = tBits_info + numInfoBits;   % Accumulate the number of information bits.


        %% Soft Viterbi decoding:
        %%

        llr_all = qamdemod(rxGrid_MMSE_soft(:), M, ...  % Compute per-bit log-likelihood ratios from the unbiased symbols.
            'OutputType', 'approxllr', 'UnitAveragePower', true, ...
            'NoiseVariance', nvarGrid(:));

        rxDec_soft = vitdec(llr_all(1:nCoded), ...  % Decode the log-likelihood ratios with the unquantized soft metric.
            trellis, tbDepth, 'trunc', 'unquant');

        rxDec_soft = rxDec_soft(1:numInfoBits);   % Keep the information bits.

        eBits_coded_soft = eBits_coded_soft + ... % Accumulate soft-decision coded bit errors.
            sum(infoBits ~= rxDec_soft);


        %% Modulation-quality metrics:
        %%

        evmS_ZF    = evmS_ZF + compute_evm(txData_all, rxZF_all);      % Accumulate the zero-forcing EVM.

        evmS_MMSE  = evmS_MMSE + compute_evm(txData_all, rxMM_all);    % Accumulate the MMSE EVM.

        sinrS_ZF   = sinrS_ZF + compute_sinr(txData_all, rxZF_all);   % Accumulate the zero-forcing SINR.

        sinrS_MMSE = sinrS_MMSE + compute_sinr(txData_all, rxMM_all); % Accumulate the MMSE SINR.

    end


    %% Part B aggregation:
    %%

    BER_ZF(snrIdx)      = eBits_ZF / tBits_unc;              % Aggregate the zero-forcing BER.

    BER_MMSE(snrIdx)    = eBits_MMSE / tBits_unc;            % Aggregate the MMSE BER.

    BER_coded(snrIdx)      = eBits_coded / tBits_info;      % Aggregate the hard-decision coded BER.

    BER_coded_soft(snrIdx) = eBits_coded_soft / tBits_info; % Aggregate the soft-decision coded BER.

    EVM_ZF(snrIdx)      = evmS_ZF / numSlots;               % Aggregate the zero-forcing EVM.

    EVM_MMSE(snrIdx)    = evmS_MMSE / numSlots;             % Aggregate the MMSE EVM.

    SINR_ZF(snrIdx)     = sinrS_ZF / numSlots;              % Aggregate the zero-forcing SINR.

    SINR_MMSE(snrIdx)   = sinrS_MMSE / numSlots;            % Aggregate the MMSE SINR.

    MSE_LS(snrIdx)      = mseS_LS / numSlots;               % Aggregate the LS estimation MSE.

    MSE_Wiener(snrIdx)  = mseS_W / numSlots;                % Aggregate the Wiener estimation MSE.

    Capacity(snrIdx)    = capS / numSlots;                  % Aggregate the capacity.

    Throughput(snrIdx)  = (1-BER_coded(snrIdx)) * ...       % Compute the hard-decision coded goodput per OFDM symbol.
        bitsPerSym * codeRate * Nt * Nfft;

    SpectralEff(snrIdx) = Throughput(snrIdx) / Nfft;       % Compute the spectral efficiency per subcarrier.

    fprintf('SNR %2d dB  %-6s  BER_MMSE %.3e  Coded_hard %.3e  Coded_soft %.3e  Cap %.2f\n', ...
        SNRdB, selectedMod(snrIdx), BER_MMSE(snrIdx), ...
        BER_coded(snrIdx), BER_coded_soft(snrIdx), Capacity(snrIdx));

end


%% Result CSV storage:
%%

T = table(SNRdB_list.', selectedMod, BER_ZF, BER_MMSE, ...          % Collect the Part B results in a table.
    BER_coded, BER_coded_soft, EVM_ZF, EVM_MMSE, SINR_ZF, ...
    SINR_MMSE, MSE_LS, MSE_Wiener, Capacity, Throughput, ...
    SpectralEff, 'VariableNames', {'snrDb', 'modulation', ...
    'berZf', 'berMmse', 'berCodedHard', 'berCodedSoft', ...
    'evmZf', 'evmMmse', 'sinrZf', 'sinrMmse', 'mseLs', ...
    'mseWiener', 'capacityBpsHz', 'throughputBits', 'spectralEff'});

writetable(T, 'results_8x8.csv');                 % Store the results for the size-comparison overlay.

fprintf('Saved results_8x8.csv\n');

%% Run configuration identifier:
%%

cfg.projectVersion    = "Baseline-v1.1";          % Version of the baseline package.
cfg.adaptationMode    = "snr-threshold-modulation";  % Threshold-based modulation selection; code rate fixed.
cfg.codingMode        = "convolutional-rate-1-2"; % Fixed rate-1/2 convolutional code.
cfg.decoderComparison = "common-unbiased-mmse-stream";  % Hard and soft branches share the unbiased stream.

writetable(struct2table(cfg), 'run_config_8x8.csv');  % Store the configuration identifier beside the results.



%% Synchronization figures:
%%

fprintf('\nGenerating figures\n');

SNR_demo  = 20;                                   % SNR used for the timing-metric example figure.

nVar_demo = 1 / (Nfft * 10^(SNR_demo/10));        % Noise variance for the example figure scaled by the FFT gain.

h_demo = zeros(numTaps, 1);                       % Preallocate the example channel taps.

for i = 1:numTaps                                 % Draw the example channel taps.
    h_demo(i) = sqrt(tapPowers(i)/2) * (randn + 1j*randn);
end

demoTail = zeros(2*symbolLen, 1);                 % Preallocate two trailing OFDM symbols for the demo frame.

for s = 1:2                                        % Build the trailing symbols so the search range covers the plateau.
    Xd = zeros(Nfft, 1);
    Xd(pilotIdx_sync) = 1 + 0j;
    Xd(dataIdx_sync)  = qammod(randi([0 1], numDataSC_sync*bpsSym_sync, 1), ...
        M_sync, 'InputType', 'bit', 'UnitAveragePower', true);
    xd = ifft(Xd, Nfft);
    demoTail((s-1)*symbolLen+1 : s*symbolLen) = [xd(end-cpLen+1:end); xd];
end

demoFrame = [preamble; demoTail];                 % Preamble followed by trailing symbols.

rxDemo = apply_tdla_channel(demoFrame, h_demo, tapDelays_samp);  % Pass the demo frame through the example channel.

rxDemo = apply_cfo(rxDemo, epsilon_true, Nfft);   % Apply the example carrier offset.

rxDemo = rxDemo + sqrt(nVar_demo/2) * ...         % Add the example noise realization.
    (randn(length(rxDemo),1) + 1j*randn(length(rxDemo),1));

[Lambda_demo, ~, ~, ~] = schmidl_cox_metric( ...  % Compute the example timing metric.
    rxDemo, L, preambleLen, cpLen, length(rxDemo));

figure(1);
plot(1:length(Lambda_demo), Lambda_demo, 'b-', 'LineWidth', 2);
hold on;
xline(cpLen+1, 'r--', 'LineWidth', 2, ...
    'Label', sprintf('True timing (d=%d)', cpLen+1));
grid on;
xlabel('Sample index d');
ylabel('Timing metric');
title('A1: Schmidl-Cox Timing Metric');
legend('Timing metric', 'True timing', 'Location', 'best');
xlim([0, 100]);
ylim([0, 1.2]);
hold off;

figure(2);
semilogy(SNRdB_list, max(BER_perfect, 1e-6), 'o-', 'LineWidth', 2);
hold on;
semilogy(SNRdB_list, max(BER_cfo_only, 1e-6), 's--', 'LineWidth', 2);
semilogy(SNRdB_list, max(BER_after_sync, 1e-6), '^-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('BER');
title('A2: BER vs SNR - Synchronization Impact');
legend('Perfect sync', 'Uncompensated CFO', 'After sync', 'Location', 'southwest');
hold off;

figure(3);
semilogy(SNRdB_list, CFO_RMSE_coarse, 'o-', 'LineWidth', 2);
hold on;
semilogy(SNRdB_list, CFO_RMSE_fine, 's-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('CFO estimation RMSE (subcarrier spacings)');
title('A3: CFO Estimation Accuracy');
legend('Coarse only', 'Coarse and fine', 'Location', 'northeast');
hold off;

figure(4);
plot(SNRdB_list, Timing_RMSE, 'o-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('Timing RMSE (samples)');
title('A4: Timing Detection Accuracy vs SNR');

figure(5);
plot(SNRdB_list, EVM_perfect, 'o-', 'LineWidth', 2);
hold on;
plot(SNRdB_list, EVM_after_sync, 's-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('EVM (%)');
title('A5: EVM After Synchronization');
legend('Perfect sync', 'After sync', 'Location', 'northeast');
hold off;


%% MIMO figures:
%%

figure(6);
semilogy(SNRdB_list, max(BER_ZF, 1e-6), 'o--', 'LineWidth', 2);
hold on;
semilogy(SNRdB_list, max(BER_MMSE, 1e-6), 's-', 'LineWidth', 2);
semilogy(SNRdB_list, max(BER_coded, 1e-6), '^-', 'LineWidth', 2);
semilogy(SNRdB_list, max(BER_coded_soft, 1e-6), 'd-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('BER');
title('B1: BER - 8x8 MIMO-OFDM');
legend('LS and ZF', 'Wiener and MMSE', ...
    'Coded MMSE hard Viterbi', 'Coded MMSE soft Viterbi', 'Location', 'southwest');
hold off;

figure(7);
semilogy(SNRdB_list, MSE_LS, 'o-', 'LineWidth', 2);
hold on;
semilogy(SNRdB_list, MSE_Wiener, 's-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('Channel estimation MSE');
title('B2: Channel Estimation MSE - LS vs Wiener');
legend('LS estimate', 'Wiener MMSE', 'Location', 'northeast');
hold off;

figure(8);
plot(SNRdB_list, SINR_ZF, 'o-', 'LineWidth', 2);
hold on;
plot(SNRdB_list, SINR_MMSE, 's-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('Post-equalization SINR (dB)');
title('B3: Post-Equalization SINR - ZF vs MMSE');
legend('ZF', 'MMSE', 'Location', 'northwest');
hold off;

figure(9);
plot(SNRdB_list, EVM_ZF, 'o-', 'LineWidth', 2);
hold on;
plot(SNRdB_list, EVM_MMSE, 's-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('EVM (%)');
title('B4: EVM After Equalization');
legend('LS and ZF', 'Wiener and MMSE', 'Location', 'northeast');
hold off;

figure(10);
plot(SNRdB_list, Capacity, 'o-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('Ergodic capacity (bit/s/Hz)');
title('B5: 8x8 MIMO Ergodic Capacity');

figure(11);
yyaxis left;
plot(SNRdB_list, Throughput, 'o-', 'LineWidth', 2);
ylabel('Hard-decision coded goodput (bit/OFDM symbol)');
yyaxis right;
plot(SNRdB_list, SpectralEff, 's--', 'LineWidth', 2);
ylabel('Spectral efficiency (bit/subcarrier)');
xlabel('SNR (dB)');
title('B6: Hard-Decision Coded Goodput and Spectral Efficiency');
grid on;

modOrd = zeros(numSNR, 1);                         % Bits per symbol used for the AMC decision figure.

for i = 1:numSNR                                   % Map each selected modulation to its bits per symbol.
    if     selectedMod(i) == "QPSK",   modOrd(i) = 2;
    elseif selectedMod(i) == "16-QAM", modOrd(i) = 4;
    else                               modOrd(i) = 6;
    end
end

figure(12);
stairs(SNRdB_list, modOrd, 'LineWidth', 2.5);
grid on;
xlabel('SNR (dB)');
ylabel('Bits per QAM symbol');
title('B7: Adaptive Modulation Selection');
yticks([2 4 6]);
yticklabels({'QPSK', '16-QAM', '64-QAM'});
ylim([1 7]);

figure(13);
semilogy(SNRdB_list, max(BER_coded, 1e-6), '^-', 'LineWidth', 2);
hold on;
semilogy(SNRdB_list, max(BER_coded_soft, 1e-6), 'd-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('Coded BER');
title('B8: Hard vs Soft Viterbi - Coded BER');
legend('Hard-decision Viterbi', 'Soft-decision Viterbi', 'Location', 'southwest');
hold off;


%% Coding-gain readout:
%%

topMask = (selectedMod == selectedMod(numSNR));   % Select the SNR points that use the highest modulation order.

targetBER = 5e-2;                                 % Target coded BER used for the gain comparison in the top-modulation region.

snr_hard = interp_snr_at_ber( ...                 % SNR reaching the target with hard decisions in the top-modulation region.
    SNRdB_list(topMask), BER_coded(topMask), targetBER);

snr_soft = interp_snr_at_ber( ...                 % SNR reaching the target with soft decisions in the top-modulation region.
    SNRdB_list(topMask), BER_coded_soft(topMask), targetBER);

if ~isnan(snr_hard) && ~isnan(snr_soft)           % Report the gain only when both curves cross the target.
    fprintf('Soft-decision coding gain at BER %.0e (%s region): %.2f dB\n', ...
        targetBER, selectedMod(numSNR), snr_hard - snr_soft);
else
    fprintf('Target BER not crossed by both curves in the top-modulation region.\n');
end

fprintf('Simulation complete\n');
