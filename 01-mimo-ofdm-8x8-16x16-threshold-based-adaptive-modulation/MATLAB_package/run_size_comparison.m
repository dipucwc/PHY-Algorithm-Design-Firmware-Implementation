
%% *** run_size_comparison ***:
%% This is the 8x8 versus 16x16 size-comparison overlay:
%{
The script loads the stored 8x8 and 16x16 result tables and overlays the two configurations on shared axes. Both runs use
the same TDL-A profile, Doppler model, SNR grid, adaptive-modulation thresholds, convolutional code, and Monte Carlo depth,
so antenna count is the only changed variable and the differences between the curves are attributable to array size alone.

Four comparison figures are produced. The capacity overlay shows the spatial-multiplexing scaling of the ergodic capacity
with the antenna count. The channel-estimation overlay shows the estimation cost of the sparser pilot comb, since the
per-antenna pilot count halves when the antenna count doubles at a fixed FFT size. The post-equalization SINR overlay shows
the growth of the zero-forcing noise-enhancement penalty with array size against the stability of the MMSE detector. The
coded-BER overlay shows the hard-decision and soft-decision Viterbi curves for both sizes, and the script prints the SNR
at which each coded curve crosses the target BER in the top-modulation region.

The script stops with an instruction when either result CSV is missing, because the overlay is only valid when both
simulations have been executed.

Input:

    results_8x8.csv     Stored result table produced by the 8x8 main script.
    results_16x16.csv   Stored result table produced by the 16x16 main script.

Output:

    Four overlay figures comparing the two array sizes.
    Console readout of the target-BER crossings for both sizes.
%}


%% Initialization:
%%

clc;
clear;
close all;

addpath(pwd);                                     % Add the project directory so every function file is on the path.


%% Result loading:
%%

if ~isfile('results_8x8.csv')                     % Confirm the 8x8 results exist before comparing.
    error('results_8x8.csv not found. Run main_phy_simulation first.');
end

if ~isfile('results_16x16.csv')                   % Confirm the 16x16 results exist before comparing.
    error('results_16x16.csv not found. Run main_phy_simulation_16x16 first.');
end

T8  = readtable('results_8x8.csv');               % Load the 8x8 result table.

T16 = readtable('results_16x16.csv');             % Load the 16x16 result table.

if ~isequal(T8.snrDb, T16.snrDb)                  % Confirm both runs used the same SNR grid.
    error('SNR grids differ between the two result files.');
end

snr = T8.snrDb;                                   % Shared SNR axis.


%% Configuration cross-check:
%%

if ~isfile('run_config_8x8.csv') || ~isfile('run_config_16x16.csv')   % Confirm both configuration records exist.
    error('run_config CSV files not found. Rerun the main scripts to regenerate them.');
end

cfg8  = readtable('run_config_8x8.csv',  'TextType', 'string');   % Load the 8x8 configuration record.

cfg16 = readtable('run_config_16x16.csv', 'TextType', 'string');  % Load the 16x16 configuration record.

if cfg8.projectVersion ~= cfg16.projectVersion    % Confirm both runs share the same project version.
    error('Project versions do not match between the two configurations.');
end

if cfg8.adaptationMode ~= cfg16.adaptationMode    % Confirm both runs share the same adaptation mode.
    error('Adaptation modes do not match between the two configurations.');
end

if cfg8.codingMode ~= cfg16.codingMode            % Confirm both runs share the same coding mode.
    error('Coding modes do not match between the two configurations.');
end

if cfg8.decoderComparison ~= cfg16.decoderComparison   % Confirm both runs share the same decoder comparison mode.
    error('Decoder comparison modes do not match between the two configurations.');
end


%% Capacity overlay:
%%

figure(1);
plot(snr, T8.capacityBpsHz, 'o-', 'LineWidth', 2);
hold on;
plot(snr, T16.capacityBpsHz, 's-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('Ergodic capacity (bit/s/Hz)');
title('D1: Ergodic Capacity - 8x8 vs 16x16');
legend('8x8', '16x16', 'Location', 'northwest');
hold off;


%% Channel-estimation overlay:
%%

figure(2);
semilogy(snr, T8.mseLs, 'o--', 'LineWidth', 2);
hold on;
semilogy(snr, T8.mseWiener, 'o-', 'LineWidth', 2);
semilogy(snr, T16.mseLs, 's--', 'LineWidth', 2);
semilogy(snr, T16.mseWiener, 's-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('Channel estimation MSE');
title('D2: Channel Estimation MSE - 8x8 vs 16x16');
legend('8x8 LS', '8x8 Wiener', '16x16 LS', '16x16 Wiener', 'Location', 'southwest');
hold off;


%% SINR overlay:
%%

figure(3);
plot(snr, T8.sinrZf, 'o--', 'LineWidth', 2);
hold on;
plot(snr, T8.sinrMmse, 'o-', 'LineWidth', 2);
plot(snr, T16.sinrZf, 's--', 'LineWidth', 2);
plot(snr, T16.sinrMmse, 's-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('Post-equalization SINR (dB)');
title('D3: Post-Equalization SINR - 8x8 vs 16x16');
legend('8x8 ZF', '8x8 MMSE', '16x16 ZF', '16x16 MMSE', 'Location', 'northwest');
hold off;


%% Coded-BER overlay:
%%

figure(4);
semilogy(snr, max(T8.berCodedHard, 1e-6), '^--', 'LineWidth', 2);
hold on;
semilogy(snr, max(T8.berCodedSoft, 1e-6), '^-', 'LineWidth', 2);
semilogy(snr, max(T16.berCodedHard, 1e-6), 'd--', 'LineWidth', 2);
semilogy(snr, max(T16.berCodedSoft, 1e-6), 'd-', 'LineWidth', 2);
grid on;
xlabel('SNR (dB)');
ylabel('Coded BER');
title('D4: Coded BER Hard and Soft Viterbi - 8x8 vs 16x16');
legend('8x8 hard', '8x8 soft', '16x16 hard', '16x16 soft', 'Location', 'southwest');
hold off;


%% Target-BER readout:
%%

targetBerList = [5e-2, 1e-1];                     % Both coded-BER targets reported in the comparison table.

mask8  = strcmp(T8.modulation,  T8.modulation{end});   % Top-modulation region of the 8x8 run.

mask16 = strcmp(T16.modulation, T16.modulation{end});  % Top-modulation region of the 16x16 run.

for targetBER = targetBerList                     % Report the crossings and soft-decision gain at each target.

    s8h  = interp_snr_at_ber(snr(mask8),  T8.berCodedHard(mask8),  targetBER);   % 8x8 hard-decision crossing.
    s8s  = interp_snr_at_ber(snr(mask8),  T8.berCodedSoft(mask8),  targetBER);   % 8x8 soft-decision crossing.
    s16h = interp_snr_at_ber(snr(mask16), T16.berCodedHard(mask16), targetBER);  % 16x16 hard-decision crossing.
    s16s = interp_snr_at_ber(snr(mask16), T16.berCodedSoft(mask16), targetBER);  % 16x16 soft-decision crossing.

    fprintf('Target coded BER %.0e in the top-modulation region:\n', targetBER);
    report_crossing('8x8',   s8h,  s8s);
    report_crossing('16x16', s16h, s16s);

end

fprintf('Comparison complete\n');


%% Local functions:
%%

function report_crossing(label, sHard, sSoft)     % Print one size's hard and soft crossings and their gain.
    if isnan(sHard) || isnan(sSoft)               % Report a missing gain when either curve does not cross.
        gainStr = 'not reported';
    else
        gainStr = sprintf('%.2f dB', sHard - sSoft);
    end
    fprintf('  %-5s hard %s   soft %s   gain %s\n', ...
        label, crossing_string(sHard), crossing_string(sSoft), gainStr);
end

function str = crossing_string(v)                 % Format a crossing as decibels or as not reached.
    if isnan(v)
        str = 'not reached';
    else
        str = sprintf('%.2f dB', v);
    end
end
