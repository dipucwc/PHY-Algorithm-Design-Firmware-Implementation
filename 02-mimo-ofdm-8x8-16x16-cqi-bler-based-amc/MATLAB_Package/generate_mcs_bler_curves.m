%{
=========================================================================================================================
 generate_mcs_bler_curves.m — Fixed-MCS BLER calibration with per-layer effective SINR and per-mapping curve files
=========================================================================================================================

The script measures the block-error-rate curve of every MCS by transmitting CRC-protected blocks through the actual
MIMO-OFDM link at a fixed modulation and coding rate over a per-MCS SNR window. Each slot carries one codeword per
spatial layer, so one slot yields Nt block verdicts, and the effective SINR of every point is accumulated per layer
codeword: for each mapping the per-layer profile of every layer is collapsed with that mapping and the calibrated
MCS's parameter, and the stored point carries the mean of the per-layer values, so the curve axis is a codeword-level
quantity rather than a slot-wide scalar. Every SNR point uses adaptive Monte Carlo stopping: the point ends when the
minimum number of block errors has been observed or the maximum number of blocks has been simulated, whichever comes
first. For each point the script records the measured BLER with block counts and a 95 percent Wilson confidence
interval against the per-layer effective SINR of every configured mapping, and writes one calibration file per
mapping, mcs_bler_curves_<mapping>_<array>.csv, so that every online controller queries the curve calibrated with
its own mapping. It is needed Run this script once per array size before the online-adaptation mains; set
arraySizeToCalibrate below.

Configure the array size here, then run the script.
=========================================================================================================================
%}

% arraySizeToCalibrate = 8;                          % Set 8 for the 8x8 calibration or 16 for the 16x16 calibration.
arraySizeToCalibrate = 16;  

cfg      = create_cqi_amc_config(arraySizeToCalibrate);  % Central configuration.

mcsTable = create_mcs_table();                    % Simplified research MCS table.

trellis  = poly2trellis(cfg.constraintLength, cfg.codePolynomials);  % Mother-code trellis.

rng(cfg.randomSeed);                              % Master seed of the calibration run.

fprintf('MCS BLER calibration, %s array\n', cfg.arrayLabel);


%% Link precomputation shared across the calibration:
%%

link = build_link_precompute(cfg);                % Pilot pattern, tap powers, and Wiener correlation matrices.

mappings = cfg.effectiveSinrMappings;             % Mappings receiving their own calibration files.

numMappings = numel(mappings);

rowsMap = cell(numMappings, 1);                   % Calibration output rows per mapping.

for u = 1:numMappings
    rowsMap{u} = [];
end

for m = 1:height(mcsTable)                        % Calibrate every MCS.

    mcsRow    = mcsTable(m, :);

    snrWindow = cfg.calibrationSnrWindows{m};     % SNR window of this MCS.

    beta      = cfg.eesmBeta(m);                  % EESM parameter of this MCS.

    for SNRdB = snrWindow                         % Sweep the window.

        link.noiseVar = 1 / 10^(SNRdB/10);        % Noise variance of this point.

        link.W_wiener = build_wiener_filter(link, cfg);  % Wiener filter at this noise variance.

        totalBlocks = 0;  failedBlocks = 0;       % Adaptive-stopping counters.

        effSum = zeros(numMappings, 1);           % Per-mapping accumulator of the mean per-layer effective SINR.

        slotCount = 0;

        while failedBlocks < cfg.minimumBlockErrors && totalBlocks < cfg.maximumBlocks

            slotCount = slotCount + 1;            % One more calibration slot.

            seed = cfg.randomSeed + 7919*m + 977*find(snrWindow==SNRdB,1) + slotCount;  % Deterministic slot seed.

            realizationStream = RandStream('mt19937ar', 'Seed', seed);       % Channel-and-noise stream.

            payloadStream     = RandStream('mt19937ar', 'Seed', seed + 5e5); % Payload stream.

            shared = prepare_slot_shared(cfg, link, realizationStream);      % Shared slot realization.

            res = run_slot_link(shared, mcsRow, cfg, trellis, payloadStream);  % Fixed-MCS transmission.

            totalBlocks  = totalBlocks + res.totalBlocks;    % Update the counters.

            failedBlocks = failedBlocks + res.failedBlocks;

            for u = 1:numMappings                 % Accumulate the per-layer effective SINR of every mapping.

                layerEff = zeros(cfg.Nt, 1);      % One effective SINR per layer codeword.

                for l = 1:cfg.Nt
                    layerEff(l) = calculate_effective_sinr(shared.sinrEst(l,:), mappings(u), beta);
                end

                effSum(u) = effSum(u) + mean(layerEff);

            end

        end

        [bler, ciLow, ciHigh] = compute_bler(failedBlocks, totalBlocks);  % BLER with the Wilson interval.

        for u = 1:numMappings                     % Append the calibration point of every mapping.
            rowsMap{u} = [rowsMap{u}; { ...
                mcsRow.McsIndex, SNRdB, effSum(u)/slotCount, bler, ...
                totalBlocks, failedBlocks, totalBlocks - failedBlocks, ...
                ciLow, ciHigh, beta, char(mappings(u))}]; 
        end

        fprintf('MCS %d  SNR %2d dB  effSINR %6.2f dB  BLER %.4f  blocks %5d  errors %4d\n', ...
            mcsRow.McsIndex, SNRdB, effSum(1)/slotCount, bler, totalBlocks, failedBlocks);

    end
end

varNames = { ...
    'McsIndex', 'SnrDb', 'EffectiveSinrDb', 'MeasuredBler', ...
    'TotalBlocks', 'FailedBlocks', 'SuccessfulBlocks', 'CiLow95', 'CiHigh95', 'EesmBeta', 'Mapping'};

for u = 1:numMappings                             % Persist one calibration file per mapping.

    curveTable = cell2table(rowsMap{u}, 'VariableNames', varNames);

    curveFile  = sprintf('mcs_bler_curves_%s_%s.csv', mappings(u), cfg.arrayLabel);

    writetable(curveTable, curveFile);

    fprintf('Saved %s\n', curveFile);

end

blerCurves = cell2table(rowsMap{1}, 'VariableNames', varNames);  % EESM curves drive the calibration figures.


%% Calibration figures:
%%

figure('Name', 'P2-C1');                          % BLER versus effective SINR for every MCS.
colors = lines(height(mcsTable));
hold on;
for m = 1:height(mcsTable)
    r = blerCurves.McsIndex == m-1;
    semilogy(blerCurves.EffectiveSinrDb(r), max(blerCurves.MeasuredBler(r), 1e-4), ...
        '-o', 'Color', colors(m,:), 'LineWidth', 1.5);
end
yline(cfg.targetBler, 'k--', 'LineWidth', 1.2);
set(gca, 'YScale', 'log'); grid on;
xlabel('Effective SINR (dB)'); ylabel('Measured BLER');
title(sprintf('P2-C1: MCS BLER Calibration Curves (%s)', cfg.arrayLabel));
legend([compose('MCS %d', 0:height(mcsTable)-1), {'Target BLER'}], 'Location', 'southwest');
saveas(gcf, sprintf('P2C1_bler_curves_%s.png', cfg.arrayLabel));

figure('Name', 'P2-C2');                          % EESM calibration parameter versus MCS.
plot(0:height(mcsTable)-1, cfg.eesmBeta, '-s', 'LineWidth', 1.5);
grid on; xlabel('MCS index'); ylabel('EESM \beta');
title(sprintf('P2-C2: EESM Calibration Parameter versus MCS (%s)', cfg.arrayLabel));
saveas(gcf, sprintf('P2C2_eesm_beta_%s.png', cfg.arrayLabel));

figure('Name', 'P2-C3');                          % Predicted versus measured BLER self-consistency.
pred = zeros(height(blerCurves), 1);
for i = 1:height(blerCurves)
    others = blerCurves(setdiff(1:height(blerCurves), i), :);  % Leave-one-out prediction.
    pred(i) = interpolate_bler_curve(others, blerCurves.McsIndex(i), blerCurves.EffectiveSinrDb(i));
end
loglog(max(blerCurves.MeasuredBler,1e-4), max(pred,1e-4), 'o'); hold on;
loglog([1e-4 1], [1e-4 1], 'k--'); grid on;
xlabel('Measured BLER'); ylabel('Predicted BLER (leave-one-out)');
title(sprintf('P2-C3: Predicted versus Measured BLER (%s)', cfg.arrayLabel));
saveas(gcf, sprintf('P2C3_pred_vs_meas_%s.png', cfg.arrayLabel));

fprintf('Calibration complete\n');
