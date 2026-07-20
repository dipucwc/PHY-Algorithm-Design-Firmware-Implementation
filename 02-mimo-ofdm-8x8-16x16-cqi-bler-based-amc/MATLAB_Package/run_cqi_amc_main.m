%{
=========================================================================================================================
 run_cqi_amc_main.m — Online CQI-based AMC study: all adaptation methods on identical channel and noise realizations
=========================================================================================================================

The function runs the complete online link-adaptation study for one array size. At every SNR point and every Monte
Carlo slot, one shared realization is prepared — one channel evolution, one pilot-noise draw, one data-noise tensor,
one channel estimate, one set of equalizer weights, and one receiver SINR estimate — and every adaptation method
transmits through that identical realization. The methods therefore differ only in how they choose the MCS:

    fixed_mcs0              Fixed QPSK rate-1/2 reference (baseline 1).
    threshold_p1            Project 1 configured-SNR threshold modulation at fixed rate 1/2 (baseline 2).
    cqi_mean_delayed        CQI-based AMC from the mean mapping and its own mean-calibrated curves, delayed feedback.
    cqi_min_delayed         CQI-based AMC from the minimum mapping and its own minimum-calibrated curves, delayed feedback.
    cqi_eesm_delayed        CQI-based AMC from the EESM mapping and its EESM-calibrated curves (primary), delayed feedback.
    cqi_eesm_olla_delayed   EESM with delayed feedback and the transmitter-side outer-loop offset.
    cqi_eesm_instant        EESM with instantaneous same-slot CQI: an ideal upper bound, not a causal implementation.
    oracle                  Pilot-time-CSI reference: perfect pilot-time channel knowledge for CQI generation.

Every mapping queries the calibration file generated with that mapping, so no controller reads a curve on a foreign
effective-SINR axis. The receiver reports the uncorrected per-layer, per-candidate quality report; the feedback
buffer carries the report through the configured delay; and the transmitter applies its current outer-loop offset
and reruns the BLER-constrained per-layer selection at transmission time, so the offset acts after the delay. The
outer loop is updated once per slot from the failed-block fraction over all layer codewords. Per-slot MCS/CQI traces
at the configured convergence SNR are stored for the convergence figures. The function writes the per-SNR result
table with the required columns including the 95 percent Wilson interval of every measured BLER, the MCS-specific
selection table of the primary method, and the run-configuration record, then generates the figures.
=========================================================================================================================
%}

function run_cqi_amc_main(arraySize)

cfg      = create_cqi_amc_config(arraySize);      % Central configuration.

mcsTable = create_mcs_table();                    % Simplified research MCS table.

trellis  = poly2trellis(cfg.constraintLength, cfg.codePolynomials);  % Mother-code trellis.

curves = struct();                                % Per-mapping calibration tables.

for mapping = cfg.effectiveSinrMappings           % Load the calibration file of every mapping.

    curveFile = sprintf('mcs_bler_curves_%s_%s.csv', mapping, cfg.arrayLabel);

    assert(isfile(curveFile), ...                 % All mapping calibrations must exist before online adaptation.
        'Calibration file %s not found. Run generate_mcs_bler_curves first.', curveFile);

    curves.(char(mapping)) = readtable(curveFile);  % Calibrated curves of this mapping.

    verify_curve_mapping(curves.(char(mapping)), mapping);  % Guard against a foreign effective-SINR axis.

end

rng(cfg.randomSeed);                              % Master seed.

fprintf('CQI-based AMC study, %s array\n', cfg.arrayLabel);

link = build_link_precompute(cfg);                % Array-size precomputation.

methods = ["fixed_mcs0", "threshold_p1", "cqi_mean_delayed", "cqi_min_delayed", ...
           "cqi_eesm_delayed", "cqi_eesm_olla_delayed", "cqi_eesm_instant", "oracle"];

numMethods = numel(methods);

primaryIdx = find(methods == "cqi_eesm_delayed"); % Primary method for the progress line and the MCS statistics.

numSNR = numel(cfg.snrGrid_dB);

thresholdMcsMap = containers.Map([4 16 64], [0 3 6]);  % Project 1 modulation orders to rate-1/2 MCS indices.


%% Result accumulators:
%%

out = [];                                         % Per-SNR, per-method result rows.

mcsCounts = zeros(height(mcsTable), numSNR);      % Primary-method MCS selection counts.

mcsBlockFail = zeros(height(mcsTable), numSNR);   % Primary-method failed blocks per MCS.

mcsBlockTot  = zeros(height(mcsTable), numSNR);   % Primary-method total blocks per MCS.

mcsEffSum    = zeros(height(mcsTable), numSNR);   % Primary-method effective-SINR sum per MCS.

conv = struct();                                  % Convergence traces at the configured SNR.


%% SNR sweep:
%%

for snrIdx = 1:numSNR

    SNRdB = cfg.snrGrid_dB(snrIdx);

    link.noiseVar = 1 / 10^(SNRdB/10);            % Noise variance of this point.

    link.W_wiener = build_wiener_filter(link, cfg);  % Wiener filter at this point.

    st = struct();                                % Per-method controller state.

    for mi = 1:numMethods
        st(mi).cqiBuffer  = struct('buffer', {{}});  % Feedback buffer of quality reports.
        st(mi).olla       = cfg.ollaOffsetInit;   % Outer-loop offset.
        st(mi).prevMcs    = NaN;                  % Previous MCS for the switching rate.
        st(mi).switches   = 0;                    % MCS switches.
        st(mi).mcsSum     = 0;  st(mi).cqiSum = 0;  st(mi).effSum = 0;  st(mi).ollaSum = 0;
        st(mi).totalBlocks = 0;  st(mi).failedBlocks = 0;
        st(mi).totalInfo   = 0;  st(mi).deliveredInfo = 0;
        st(mi).mcsTrace = zeros(cfg.numSlots,1);  st(mi).cqiTrace = zeros(cfg.numSlots,1);
        st(mi).ollaTrace = zeros(cfg.numSlots,1); st(mi).failTrace = zeros(cfg.numSlots,1);
        st(mi).blockTrace = zeros(cfg.numSlots,1);
    end

    for slotIdx = 1:cfg.numSlots

        seed = cfg.randomSeed + cfg.slotSeedStride*snrIdx + slotIdx;  % Deterministic slot seed.

        realizationStream = RandStream('mt19937ar', 'Seed', seed);    % Shared channel-and-noise stream.

        shared = prepare_slot_shared(cfg, link, realizationStream);   % One realization for every method.

        for mi = 1:numMethods                     % Every method transmits on the shared realization.

            method = methods(mi);

            %% MCS decision of this method:

            switch method

                case "fixed_mcs0"                 % Baseline 1: fixed lowest MCS.
                    mcsSel = 0;  cqiRep = 0;  effUsedDb = NaN;

                case "threshold_p1"               % Baseline 2: Project 1 threshold modulation at rate 1/2.
                    [Mmod, ~, ~] = amc_select_modulation(SNRdB);
                    mcsSel = thresholdMcsMap(Mmod);  cqiRep = mcsSel;  effUsedDb = NaN;

                otherwise                         % CQI family: receiver report, delay, transmitter-side selection.

                    switch method                 % Mapping, curves, delay, and offset of this method.
                        case "cqi_mean_delayed"
                            mapping = "mean";     useDelay = true;   sinrSource = shared.sinrEst;
                        case "cqi_min_delayed"
                            mapping = "minimum";  useDelay = true;   sinrSource = shared.sinrEst;
                        case "cqi_eesm_delayed"
                            mapping = "eesm";     useDelay = true;   sinrSource = shared.sinrEst;
                        case "cqi_eesm_olla_delayed"
                            mapping = "eesm";     useDelay = true;   sinrSource = shared.sinrEst;
                        case "cqi_eesm_instant"
                            mapping = "eesm";     useDelay = false;  sinrSource = shared.sinrEst;
                        case "oracle"
                            mapping = "eesm";     useDelay = false;  sinrSource = shared.sinrTrue;
                    end

                    curvesUse = curves.(char(mapping));  % The curve calibrated with this controller's own mapping.

                    offset = 0;                   % Transmitter-side outer-loop offset of this method.
                    if method == "cqi_eesm_olla_delayed"
                        offset = st(mi).olla;
                    end

                    [cqiRep, Q] = estimate_cqi(sinrSource, curvesUse, mcsTable, cfg, mapping);  % Uncorrected report.

                    if useDelay                   % The buffer carries the full quality report through the delay.

                        [Qdel, st(mi).cqiBuffer] = apply_cqi_feedback_delay(st(mi).cqiBuffer, Q, cfg);

                        if isempty(Qdel)          % No report has propagated yet: configured initial MCS.
                            mcsSel = cfg.initialMcsIndex;
                            effUsedDb = NaN;
                        else                      % Transmitter-side selection with the current offset.
                            [mcsSel, ~, ~] = select_mcs_for_target_bler(Qdel, curvesUse, mcsTable, cfg, offset);
                            if cfg.cqiErrorProbability > 0 && rand(realizationStream) < cfg.cqiErrorProbability
                                mcsSel = min(max(mcsSel + sign(rand(realizationStream)-0.5), 0), height(mcsTable)-1);
                            end               % Optional reporting error shifts the applied selection by one step.
                            effUsedDb = mean(Qdel(:, mcsSel+1));
                        end

                    else                          % Same-slot variants select from the current report directly.
                        [mcsSel, ~, ~] = select_mcs_for_target_bler(Q, curvesUse, mcsTable, cfg, 0);
                        effUsedDb = mean(Q(:, mcsSel+1));
                    end

            end

            mcsRow = mcsTable(mcsSel+1, :);

            payloadStream = RandStream('mt19937ar', 'Seed', seed + 1e6*mi);  % Method-specific payload.

            res = run_slot_link(shared, mcsRow, cfg, trellis, payloadStream);  % Transmit on the shared realization.

            if method == "cqi_eesm_olla_delayed"  % Outer-loop update from all block verdicts of the slot.
                st(mi).olla = update_olla_offset(st(mi).olla, res.failedBlocks, res.totalBlocks, cfg);
            end

            %% Accounting:

            st(mi).totalBlocks   = st(mi).totalBlocks + res.totalBlocks;
            st(mi).failedBlocks  = st(mi).failedBlocks + res.failedBlocks;
            st(mi).totalInfo     = st(mi).totalInfo + res.totalInfoBits;
            st(mi).deliveredInfo = st(mi).deliveredInfo + res.deliveredBits;
            st(mi).mcsSum        = st(mi).mcsSum + mcsSel;
            st(mi).cqiSum        = st(mi).cqiSum + cqiRep;
            st(mi).ollaSum       = st(mi).ollaSum + st(mi).olla;
            if ~isnan(effUsedDb),  st(mi).effSum = st(mi).effSum + effUsedDb;  end
            if ~isnan(st(mi).prevMcs) && mcsSel ~= st(mi).prevMcs
                st(mi).switches = st(mi).switches + 1;
            end
            st(mi).prevMcs = mcsSel;

            st(mi).mcsTrace(slotIdx)   = mcsSel;  % Convergence traces.
            st(mi).cqiTrace(slotIdx)   = cqiRep;
            st(mi).ollaTrace(slotIdx)  = st(mi).olla;
            st(mi).failTrace(slotIdx)  = res.failedBlocks;
            st(mi).blockTrace(slotIdx) = res.totalBlocks;

            if method == "cqi_eesm_delayed"       % Primary-method MCS-specific statistics.
                mcsCounts(mcsSel+1, snrIdx)   = mcsCounts(mcsSel+1, snrIdx) + 1;
                mcsBlockFail(mcsSel+1, snrIdx) = mcsBlockFail(mcsSel+1, snrIdx) + res.failedBlocks;
                mcsBlockTot(mcsSel+1, snrIdx)  = mcsBlockTot(mcsSel+1, snrIdx) + res.totalBlocks;
                if ~isnan(effUsedDb)
                    mcsEffSum(mcsSel+1, snrIdx) = mcsEffSum(mcsSel+1, snrIdx) + effUsedDb;
                end
            end

        end
    end

    %% Per-SNR result rows:

    for mi = 1:numMethods
        s = st(mi);
        [measuredBler, ciLow, ciHigh] = compute_bler(s.failedBlocks, s.totalBlocks);
        effMethodLabel = "eesm";
        if methods(mi) == "cqi_mean_delayed", effMethodLabel = "mean"; end
        if methods(mi) == "cqi_min_delayed",  effMethodLabel = "minimum"; end
        if any(methods(mi) == ["fixed_mcs0","threshold_p1"]), effMethodLabel = "none"; end
        out = [out; { ...
            SNRdB, cfg.arrayLabel, char(methods(mi)), char(effMethodLabel), ...
            s.effSum / cfg.numSlots, s.cqiSum / cfg.numSlots, s.mcsSum / cfg.numSlots, ...
            measuredBler, cfg.targetBler, measuredBler - cfg.targetBler, ciLow, ciHigh, ...
            s.deliveredInfo / cfg.numSlots, ...
            s.deliveredInfo / (cfg.numSlots * cfg.Nfft * cfg.numDataSymbols), ...
            s.switches / max(cfg.numSlots-1, 1), ...
            cfg.cqiDelaySlots * ~any(methods(mi) == ["cqi_eesm_instant","oracle","fixed_mcs0","threshold_p1"]), ...
            cfg.cqiErrorProbability, s.ollaSum / cfg.numSlots, ...
            s.totalBlocks, s.failedBlocks, s.totalBlocks - s.failedBlocks, ...
            s.totalInfo, s.deliveredInfo, cfg.randomSeed}]; %#ok<AGROW>
    end

    if SNRdB == cfg.convergenceSnrDb              % Keep the convergence traces of this SNR point.
        conv = st;
        convMethods = methods;
    end

    fprintf('SNR %2d dB done: primary BLER %.3f, goodput %.0f bits/slot\n', SNRdB, ...
        st(primaryIdx).failedBlocks/st(primaryIdx).totalBlocks, st(primaryIdx).deliveredInfo/cfg.numSlots);

end


%% Result tables:
%%

results = cell2table(out, 'VariableNames', { ...
    'SNR_dB', 'Array_Size', 'Adaptation_Method', 'Effective_SINR_Method', ...
    'Average_Effective_SINR_dB', 'Average_CQI', 'Average_MCS', ...
    'Measured_BLER', 'Target_BLER', 'BLER_Error', 'BLER_CI_Low_95', 'BLER_CI_High_95', ...
    'Goodput_Bits_Per_Slot', 'Spectral_Efficiency', 'MCS_Switching_Rate', ...
    'CQI_Delay_Slots', 'CQI_Error_Probability', 'Average_OLLA_Offset_dB', ...
    'Total_Blocks', 'Failed_Blocks', 'Successful_Blocks', ...
    'Total_Information_Bits', 'Delivered_Information_Bits', 'Random_Seed'});

resultFile = sprintf('results_cqi_amc_%s.csv', cfg.arrayLabel);

writetable(results, resultFile);

fprintf('Saved %s\n', resultFile);

mcsRows = [];                                     % MCS-specific table of the primary method.

for m = 1:height(mcsTable)
    nSel = sum(mcsCounts(m,:));
    mcsRows = [mcsRows; { ...
        mcsTable.McsIndex(m), mcsTable.ModulationOrder(m), mcsTable.CodeRate(m), ...
        mcsTable.NominalSpectralEfficiency(m), nSel, ...
        nSel / (numSNR * cfg.numSlots), ...
        sum(mcsBlockFail(m,:)) / max(sum(mcsBlockTot(m,:)), 1), ...
        sum(mcsEffSum(m,:)) / max(nSel, 1)}]; %#ok<AGROW>
end

mcsResults = cell2table(mcsRows, 'VariableNames', { ...
    'MCS_Index', 'Modulation_Order', 'Code_Rate', 'Nominal_Spectral_Efficiency', ...
    'Number_Of_Selections', 'Selection_Probability', 'Measured_BLER', 'Average_Effective_SINR_dB'});

mcsFile = sprintf('mcs_selection_%s.csv', cfg.arrayLabel);

writetable(mcsResults, mcsFile);

fprintf('Saved %s\n', mcsFile);

runConfig = table(string(cfg.projectVersion), string(cfg.arrayLabel), cfg.targetBler, ...
    cfg.cqiDelaySlots, cfg.cqiErrorProbability, cfg.numSlots, cfg.randomSeed, ...
    string(cfg.selectionCriterion), ...
    'VariableNames', {'projectVersion','arrayLabel','targetBler','cqiDelaySlots', ...
    'cqiErrorProbability','numSlots','randomSeed','selectionCriterion'});

writetable(runConfig, sprintf('run_config_cqi_%s.csv', cfg.arrayLabel));


%% Link-adaptation figures:
%%

plot_amc_results(results, mcsResults, conv, convMethods, mcsCounts, mcsTable, cfg);

fprintf('Simulation complete\n');

end
