%{
=========================================================================================================================
 run_cqi_amc_comparison.m — 8x8 versus 16x16 comparison of the CQI-based AMC study
=========================================================================================================================

The script overlays the stored 8x8 and 16x16 results of the online study. Before any comparison it validates that
both runs used the same project version, target BLER, feedback delay, CQI error probability, slot count, and random
seed, so that the array size is enforced as the only changed input. It then generates the cross-array BLER, goodput,
and selected-MCS overlays and the oracle-versus-practical comparison, and prints the goodput of every method at the
top of the sweep for both arrays.
=========================================================================================================================
%}

f8  = 'results_cqi_amc_8x8.csv';    f16 = 'results_cqi_amc_16x16.csv';

c8  = 'run_config_cqi_8x8.csv';     c16 = 'run_config_cqi_16x16.csv';

assert(isfile(f8) && isfile(f16), 'Result files not found. Run both main scripts first.');

assert(isfile(c8) && isfile(c16), 'Run-configuration files not found. Rerun the main scripts.');


%% Configuration cross-check:
%%

cfg8  = readtable(c8,  'TextType', 'string');

cfg16 = readtable(c16, 'TextType', 'string');

if cfg8.projectVersion ~= cfg16.projectVersion,       error('Project versions do not match.');       end
if cfg8.targetBler ~= cfg16.targetBler,               error('Target BLERs do not match.');           end
if cfg8.cqiDelaySlots ~= cfg16.cqiDelaySlots,         error('CQI delays do not match.');             end
if cfg8.cqiErrorProbability ~= cfg16.cqiErrorProbability, error('CQI error probabilities do not match.'); end
if cfg8.numSlots ~= cfg16.numSlots,                   error('Slot counts do not match.');            end
if cfg8.randomSeed ~= cfg16.randomSeed,               error('Random seeds do not match.');           end

T8  = readtable(f8);   T16 = readtable(f16);

pick = @(T, m) T(string(T.Adaptation_Method) == m, :);

primary = "cqi_eesm_delayed";


%% Cross-array overlays:
%%

figure('Name', 'P2-D1');                          % 8x8 versus 16x16 BLER of the primary method.
r8 = pick(T8, primary);  r16 = pick(T16, primary);
semilogy(r8.SNR_dB,  max(r8.Measured_BLER, 1e-4), '-o', 'LineWidth', 1.5); hold on;
semilogy(r16.SNR_dB, max(r16.Measured_BLER, 1e-4), '-s', 'LineWidth', 1.5);
yline(r8.Target_BLER(1), 'k--', 'LineWidth', 1.3);
grid on; xlabel('SNR (dB)'); ylabel('Measured BLER');
title('P2-D1: Measured BLER, primary method, 8x8 versus 16x16');
legend({'8x8', '16x16', 'Target'}, 'Location', 'southwest');
saveas(gcf, 'P2D1_bler_8x8_vs_16x16.png');

figure('Name', 'P2-D2');                          % 8x8 versus 16x16 goodput of the primary method.
plot(r8.SNR_dB,  r8.Goodput_Bits_Per_Slot,  '-o', 'LineWidth', 1.5); hold on;
plot(r16.SNR_dB, r16.Goodput_Bits_Per_Slot, '-s', 'LineWidth', 1.5);
grid on; xlabel('SNR (dB)'); ylabel('CRC-qualified goodput (bit/slot)');
title('P2-D2: Measured Goodput, primary method, 8x8 versus 16x16');
legend({'8x8', '16x16'}, 'Location', 'northwest');
saveas(gcf, 'P2D2_goodput_8x8_vs_16x16.png');

figure('Name', 'P2-D3');                          % 8x8 versus 16x16 selected MCS of the primary method.
plot(r8.SNR_dB,  r8.Average_MCS,  '-o', 'LineWidth', 1.5); hold on;
plot(r16.SNR_dB, r16.Average_MCS, '-s', 'LineWidth', 1.5);
grid on; xlabel('SNR (dB)'); ylabel('Average selected MCS');
title('P2-D3: Average Selected MCS, primary method, 8x8 versus 16x16');
legend({'8x8', '16x16'}, 'Location', 'northwest');
saveas(gcf, 'P2D3_mcs_8x8_vs_16x16.png');

figure('Name', 'P2-D4');                          % Oracle versus practical goodput at both arrays.
o8 = pick(T8, "oracle");  o16 = pick(T16, "oracle");
plot(r8.SNR_dB,  r8.Goodput_Bits_Per_Slot,  '-o', 'LineWidth', 1.5); hold on;
plot(o8.SNR_dB,  o8.Goodput_Bits_Per_Slot,  '--o', 'LineWidth', 1.5);
plot(r16.SNR_dB, r16.Goodput_Bits_Per_Slot, '-s', 'LineWidth', 1.5);
plot(o16.SNR_dB, o16.Goodput_Bits_Per_Slot, '--s', 'LineWidth', 1.5);
grid on; xlabel('SNR (dB)'); ylabel('CRC-qualified goodput (bit/slot)');
title('P2-D4: Practical (delayed EESM) versus Oracle Goodput');
legend({'8x8 practical', '8x8 oracle', '16x16 practical', '16x16 oracle'}, 'Location', 'northwest');
saveas(gcf, 'P2D4_oracle_vs_practical.png');


%% Top-of-sweep summary:
%%

fprintf('Goodput at %d dB (bit/slot):\n', max(T8.SNR_dB));
for m = unique(string(T8.Adaptation_Method), 'stable').'
    g8  = pick(T8, m);   g16 = pick(T16, m);
    fprintf('  %-24s 8x8 %8.0f    16x16 %8.0f\n', m, ...
        g8.Goodput_Bits_Per_Slot(end), g16.Goodput_Bits_Per_Slot(end));
end

fprintf('Comparison complete\n');
