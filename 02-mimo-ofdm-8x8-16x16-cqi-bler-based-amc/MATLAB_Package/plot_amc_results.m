%{
=========================================================================================================================
 plot_amc_results.m — Link-adaptation and convergence figures for one array size
=========================================================================================================================

The function generates the per-array figures of the online study: selected MCS, average CQI, measured BLER against
the target line, goodput, spectral efficiency, primary-method MCS selection probability, MCS switching rate, and the
four per-slot convergence traces at the configured convergence SNR. Figure files carry the P2-A prefix for the 8x8
array and the P2-B prefix for the 16x16 array.
=========================================================================================================================
%}

function plot_amc_results(results, mcsResults, conv, convMethods, mcsCounts, mcsTable, cfg) %#ok<INUSD>

pfx = 'P2A';  if cfg.Nt == 16, pfx = 'P2B'; end   % Figure prefix per array.

methods = unique(string(results.Adaptation_Method), 'stable');

colors  = lines(numel(methods));

pick = @(m) results(string(results.Adaptation_Method) == m, :);

snr  = unique(results.SNR_dB);


figure('Name', [pfx '1']);                        % Selected MCS versus SNR.
hold on;
for i = 1:numel(methods)
    r = pick(methods(i));
    plot(r.SNR_dB, r.Average_MCS, '-o', 'Color', colors(i,:), 'LineWidth', 1.4);
end
grid on; xlabel('SNR (dB)'); ylabel('Average selected MCS');
title(sprintf('%s1: Average Selected MCS versus SNR (%s)', pfx, cfg.arrayLabel));
legend(methods, 'Interpreter', 'none', 'Location', 'northwest');
saveas(gcf, sprintf('%s1_mcs_vs_snr_%s.png', pfx, cfg.arrayLabel));


figure('Name', [pfx '2']);                        % Average CQI versus SNR.
hold on;
for i = 1:numel(methods)
    r = pick(methods(i));
    plot(r.SNR_dB, r.Average_CQI, '-o', 'Color', colors(i,:), 'LineWidth', 1.4);
end
grid on; xlabel('SNR (dB)'); ylabel('Average CQI');
title(sprintf('%s2: Average CQI versus SNR (%s)', pfx, cfg.arrayLabel));
legend(methods, 'Interpreter', 'none', 'Location', 'northwest');
saveas(gcf, sprintf('%s2_cqi_vs_snr_%s.png', pfx, cfg.arrayLabel));


figure('Name', [pfx '3']);                        % Measured BLER versus SNR with the target line.
hold on;
for i = 1:numel(methods)
    r = pick(methods(i));
    semilogy(r.SNR_dB, max(r.Measured_BLER, 1e-4), '-o', 'Color', colors(i,:), 'LineWidth', 1.4);
end
yline(cfg.targetBler, 'k--', 'LineWidth', 1.4);
set(gca, 'YScale', 'log'); grid on;
xlabel('SNR (dB)'); ylabel('Measured BLER');
title(sprintf('%s3: Measured BLER versus SNR (%s)', pfx, cfg.arrayLabel));
legend([methods; "Target BLER"], 'Interpreter', 'none', 'Location', 'southwest');
saveas(gcf, sprintf('%s3_bler_vs_snr_%s.png', pfx, cfg.arrayLabel));


figure('Name', [pfx '4']);                        % Goodput versus SNR.
hold on;
for i = 1:numel(methods)
    r = pick(methods(i));
    plot(r.SNR_dB, r.Goodput_Bits_Per_Slot, '-o', 'Color', colors(i,:), 'LineWidth', 1.4);
end
grid on; xlabel('SNR (dB)'); ylabel('CRC-qualified goodput (bit/slot)');
title(sprintf('%s4: Measured Goodput versus SNR (%s)', pfx, cfg.arrayLabel));
legend(methods, 'Interpreter', 'none', 'Location', 'northwest');
saveas(gcf, sprintf('%s4_goodput_vs_snr_%s.png', pfx, cfg.arrayLabel));


figure('Name', [pfx '5']);                        % Spectral efficiency versus SNR.
hold on;
for i = 1:numel(methods)
    r = pick(methods(i));
    plot(r.SNR_dB, r.Spectral_Efficiency, '-o', 'Color', colors(i,:), 'LineWidth', 1.4);
end
grid on; xlabel('SNR (dB)'); ylabel('Delivered bits per subcarrier per OFDM symbol');
title(sprintf('%s5: Spectral Efficiency versus SNR (%s)', pfx, cfg.arrayLabel));
legend(methods, 'Interpreter', 'none', 'Location', 'northwest');
saveas(gcf, sprintf('%s5_speff_vs_snr_%s.png', pfx, cfg.arrayLabel));


figure('Name', [pfx '6']);                        % Primary-method MCS selection probability versus SNR.
sel = mcsCounts ./ max(sum(mcsCounts, 1), 1);
imagesc(snr, 0:height(mcsTable)-1, sel);
axis xy; colorbar;
xlabel('SNR (dB)'); ylabel('MCS index');
title(sprintf('%s6: MCS Selection Probability, primary method (%s)', pfx, cfg.arrayLabel));
saveas(gcf, sprintf('%s6_mcs_selection_%s.png', pfx, cfg.arrayLabel));


figure('Name', [pfx '7']);                        % MCS switching rate versus SNR.
hold on;
for i = 1:numel(methods)
    r = pick(methods(i));
    plot(r.SNR_dB, r.MCS_Switching_Rate, '-o', 'Color', colors(i,:), 'LineWidth', 1.4);
end
grid on; xlabel('SNR (dB)'); ylabel('MCS switching rate');
title(sprintf('%s7: MCS Switching Rate versus SNR (%s)', pfx, cfg.arrayLabel));
legend(methods, 'Interpreter', 'none', 'Location', 'northeast');
saveas(gcf, sprintf('%s7_switching_%s.png', pfx, cfg.arrayLabel));


%% Convergence traces at the configured SNR:
%%

ollaIdx = find(convMethods == "cqi_eesm_olla_delayed");
primIdx = find(convMethods == "cqi_eesm_delayed");

figure('Name', [pfx '8']);                        % OLLA offset versus slot index.
plot(1:cfg.numSlots, conv(ollaIdx).ollaTrace, 'LineWidth', 1.4);
grid on; xlabel('Slot index'); ylabel('OLLA offset (dB)');
title(sprintf('%s8: OLLA Offset Convergence at %d dB (%s)', pfx, cfg.convergenceSnrDb, cfg.arrayLabel));
saveas(gcf, sprintf('%s8_olla_convergence_%s.png', pfx, cfg.arrayLabel));

figure('Name', [pfx '9']);                        % Running BLER versus slot index.
runBler = cumsum(conv(ollaIdx).failTrace) ./ cumsum(conv(ollaIdx).blockTrace);
plot(1:cfg.numSlots, runBler, 'LineWidth', 1.4); hold on;
yline(cfg.targetBler, 'k--', 'LineWidth', 1.2);
grid on; xlabel('Slot index'); ylabel('Running BLER');
title(sprintf('%s9: Running BLER at %d dB, OLLA method (%s)', pfx, cfg.convergenceSnrDb, cfg.arrayLabel));
legend({'Running BLER', 'Target'}, 'Location', 'northeast');
saveas(gcf, sprintf('%s9_running_bler_%s.png', pfx, cfg.arrayLabel));

figure('Name', [pfx '10']);                       % Selected MCS versus slot index.
stairs(1:cfg.numSlots, conv(primIdx).mcsTrace, 'LineWidth', 1.2);
grid on; xlabel('Slot index'); ylabel('Selected MCS');
title(sprintf('%s10: Selected MCS versus Slot at %d dB, primary method (%s)', pfx, cfg.convergenceSnrDb, cfg.arrayLabel));
saveas(gcf, sprintf('%s10_mcs_trace_%s.png', pfx, cfg.arrayLabel));

figure('Name', [pfx '11']);                       % CQI report and delayed application versus slot index.
stairs(1:cfg.numSlots, conv(primIdx).cqiTrace, 'LineWidth', 1.2); hold on;
stairs(1:cfg.numSlots, conv(primIdx).mcsTrace, '--', 'LineWidth', 1.2);
grid on; xlabel('Slot index'); ylabel('Index');
title(sprintf('%s11: CQI Report and Delayed MCS at %d dB (%s)', pfx, cfg.convergenceSnrDb, cfg.arrayLabel));
legend({'CQI report (slot t)', 'Applied MCS (delayed)'}, 'Location', 'northeast');
saveas(gcf, sprintf('%s11_cqi_delay_trace_%s.png', pfx, cfg.arrayLabel));

end
