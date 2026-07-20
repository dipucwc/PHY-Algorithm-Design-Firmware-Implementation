
%% *** PHY/Modem Algorithm Simulation - 16x16 MIMO-OFDM ***:
%% This is the main code for the 16x16 MIMO simulation:
%{
The main script executes the 16x16 MIMO-OFDM link simulation over the shared total-SNR range. The synchronization study is
single-antenna and antenna-count independent, so it is executed once by the 8x8 main script and is not repeated here. This
script runs the MIMO part only, with sixteen transmit and sixteen receive antennas, and holds every other parameter
identical to the 8x8 run: the same TDL-A profile, the same common-Doppler phase-evolution model, the same SNR grid, the same adaptive
modulation thresholds, the same convolutional code, and the same number of Monte Carlo slots. Antenna count is therefore
the only changed variable, which makes the two result sets directly comparable.

The comb pilot pattern assigns each transmit antenna a non-overlapping subset of subcarriers, so with sixteen antennas each
antenna carries sixteen pilot subcarriers instead of thirty-two. The receiver forms a least-squares channel estimate and a
Wiener MMSE estimate from the pilot symbol, equalizes the data symbols per subcarrier with zero-forcing and MMSE detectors,
and decodes the rate-1/2 convolutional code twice, once with hard-decision Viterbi and once with soft-decision Viterbi on
per-stream scaled log-likelihood ratios. The script accumulates bit-error rate, channel-estimation mean-square error,
post-equalization signal-to-interference-plus-noise ratio, error vector magnitude, ergodic capacity, and throughput, writes
the results to a CSV file for the size-comparison overlay, and generates the result figures.

Auxiliary functions:

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

    mmse_equalize_soft
        Recovers the transmit symbols at one subcarrier and returns the biased estimate, the unbiased estimate, and the
        per-stream effective noise variance used for soft-decision log-likelihood ratios.

    amc_select_modulation
        Selects the QAM modulation order from the operating SNR.

    compute_mimo_capacity
        Computes the ergodic capacity from the singular values of the per-subcarrier channel.

    compute_evm
        Computes the RMS error vector magnitude as a percentage.

    compute_sinr
        Computes the post-equalization signal-to-interference-plus-noise ratio in decibels.

    interp_snr_at_ber
        Returns the SNR at which a BER curve crosses a target value by interpolation on the logarithmic axis.

Input:

    randomSeed        Random-number-generator seed used for reproducible Monte Carlo runs.
    Nfft              FFT size and number of subcarriers.
    SNRdB_list        Vector of total-SNR points in decibels.
    tapDelays_samp    Integer TDL-A tap delays in samples.
    tapPowers_dB      TDL-A tap powers in decibels.
    velocity_kmh      Terminal velocity used for the maximum Doppler frequency.
    Nt                Number of transmit antennas.
    Nr                Number of receive antennas.

Output:

    Result arrays     BER, channel-estimation MSE, SINR, EVM, capacity, and throughput versus SNR.
    results_16x16.csv Stored result table for the size-comparison overlay.
    Figures           Seven 16x16 MIMO performance figures.
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

assert(maxDelay < cpLen, ...                      % Confirm the cyclic prefix covers the maximum delay spread.
    'Cyclic prefix must exceed the maximum channel delay spread');


%% Doppler parameters:
%%

velocity_kmh = 30;                                % Terminal velocity in kilometres per hour.

fc           = 3.5e9;                             % Carrier frequency in hertz.

fd_max       = (velocity_kmh/3.6) * fc / 3e8;     % Maximum Doppler frequency in hertz.

symbolDur    = symbolLen / 30.72e6;               % OFDM symbol duration in seconds.


%% MIMO parameters:
%%

fprintf('16x16 MIMO-OFDM simulation\n');

Nt             = 16;                              % Number of transmit antennas.

Nr             = 16;                              % Number of receive antennas.

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


%% Result arrays:
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


%% SNR sweep:
%%

for snrIdx = 1:numSNR                             % Process every SNR point in the sweep.

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


        %% Hard Viterbi decoding:
        %%

        nCoded = numel(codedBits);                % Number of coded bits produced by the encoder.

        rxDec  = vitdec(rxBits_MMSE(1:nCoded), ...  % Decode the demodulated bit stream with hard decisions.
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


    %% Aggregation:
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

T = table(SNRdB_list.', selectedMod, BER_ZF, BER_MMSE, ...          % Collect the results in a table.
    BER_coded, BER_coded_soft, EVM_ZF, EVM_MMSE, SINR_ZF, ...
    SINR_MMSE, MSE_LS, MSE_Wiener, Capacity, Throughput, ...
    SpectralEff, 'VariableNames', {'snrDb', 'modulation', ...
    'berZf', 'berMmse', 'berCodedHard', 'berCodedSoft', ...
    'evmZf', 'evmMmse', 'sinrZf', 'sinrMmse', 'mseLs', ...
    'mseWiener', 'capacityBpsHz', 'throughputBits', 'spectralEff'});

writetable(T, 'results_16x16.csv');               % Store the results for the size-comparison overlay.

fprintf('Saved results_16x16.csv\n');

%% Run configuration identifier:
%%

cfg.projectVersion    = "Baseline-v1.1";          % Version of the baseline package.
cfg.adaptationMode    = "snr-threshold-modulation";  % Threshold-based modulation selection; code rate fixed.
cfg.codingMode        = "convolutional-rate-1-2"; % Fixed rate-1/2 convolutional code.
cfg.decoderComparison = "common-unbiased-mmse-stream";  % Hard and soft branches share the unbiased stream.

writetable(struct2table(cfg), 'run_config_16x16.csv');  % Store the configuration identifier beside the results.



%% Result figures:
%%

fprintf('Generating figures\n');

figure(1);
semilogy(SNRdB_list, max(BER_ZF, 1e-6), 'o--', 'LineWidth', 2);
hold on;
semilogy(SNRdB_list, max(BER_MMSE, 1e-6), 's-', 'LineWidth', 2);
semilogy(SNRdB_list, max(BER_coded, 1e-6), '^-', 'LineWidth', 2);
semilogy(SNRdB_list, max(BER_coded_soft, 1e-6), 'd-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('BER');
title('C1: BER - 16x16 MIMO-OFDM');
legend('LS and ZF', 'Wiener and MMSE', ...
    'Coded MMSE hard Viterbi', 'Coded MMSE soft Viterbi', 'Location', 'southwest');
hold off;

figure(2);
semilogy(SNRdB_list, MSE_LS, 'o-', 'LineWidth', 2);
hold on;
semilogy(SNRdB_list, MSE_Wiener, 's-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('Channel estimation MSE');
title('C2: Channel Estimation MSE - LS vs Wiener (16x16)');
legend('LS estimate', 'Wiener MMSE', 'Location', 'northeast');
hold off;

figure(3);
plot(SNRdB_list, SINR_ZF, 'o-', 'LineWidth', 2);
hold on;
plot(SNRdB_list, SINR_MMSE, 's-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('Post-equalization SINR (dB)');
title('C3: Post-Equalization SINR - ZF vs MMSE (16x16)');
legend('ZF', 'MMSE', 'Location', 'northwest');
hold off;

figure(4);
plot(SNRdB_list, EVM_ZF, 'o-', 'LineWidth', 2);
hold on;
plot(SNRdB_list, EVM_MMSE, 's-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('EVM (%)');
title('C4: EVM After Equalization (16x16)');
legend('LS and ZF', 'Wiener and MMSE', 'Location', 'northeast');
hold off;

figure(5);
plot(SNRdB_list, Capacity, 'o-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('Ergodic capacity (bit/s/Hz)');
title('C5: 16x16 MIMO Ergodic Capacity');

figure(6);
yyaxis left;
plot(SNRdB_list, Throughput, 'o-', 'LineWidth', 2);
ylabel('Hard-decision coded goodput (bit/OFDM symbol)');
yyaxis right;
plot(SNRdB_list, SpectralEff, 's--', 'LineWidth', 2);
ylabel('Spectral efficiency (bit/subcarrier)');
xlabel('SNR (dB)');
title('C6: Hard-Decision Coded Goodput and Spectral Efficiency (16x16)');
grid on;

figure(7);
semilogy(SNRdB_list, max(BER_coded, 1e-6), '^-', 'LineWidth', 2);
hold on;
semilogy(SNRdB_list, max(BER_coded_soft, 1e-6), 'd-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('Coded BER');
title('C7: Hard vs Soft Viterbi - Coded BER (16x16)');
legend('Hard-decision Viterbi', 'Soft-decision Viterbi', 'Location', 'southwest');
hold off;


%% Coding-gain readout:
%%

topMask = (selectedMod == selectedMod(numSNR));   % Select the SNR points that use the highest modulation order.

targetBER = 1e-1;                                 % Target coded BER crossed by both decoders within the swept SNR range.

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
