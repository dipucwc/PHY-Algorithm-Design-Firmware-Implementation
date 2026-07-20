%{
=========================================================================================================================
 select_mcs_for_target_bler.m — BLER-constrained MCS selection from the per-layer quality report
=========================================================================================================================

The function selects the common transmission MCS of the slot from the per-layer, per-candidate quality report. For
every candidate the calibrated curve of that candidate predicts one BLER per spatial-layer codeword at the offset-
corrected per-layer effective SINR, and the candidate's criterion value is the average of the per-layer predictions,
which aligns with the measured BLER aggregated over all layer blocks; the configuration can instead request the
worst-layer prediction as a conservative criterion. Among the candidates satisfying the target, the selection takes
the highest nominal spectral efficiency, breaks efficiency ties by the lowest criterion BLER, and breaks remaining
ties by the lower modulation order, so an entry that adds robustness cost without nominal throughput is never
preferred. When no candidate satisfies the target, the selection falls back to the lowest MCS. The status output
records whether the target was met, whether the fallback was taken, whether the top of the table was reached, or
whether no valid prediction existed.
=========================================================================================================================
%}

function [selectedMcs, criterionBler, selectionStatus] = select_mcs_for_target_bler( ...
    qualityReport, blerCurves, mcsTable, cfg, ollaOffsetDb)

numMcs = height(mcsTable);                        % Number of candidate MCS entries.

Nt = size(qualityReport, 1);                      % One codeword per spatial layer.

criterionAll = nan(numMcs, 1);                    % Criterion BLER of every candidate.

for m = 1:numMcs                                  % Predict every candidate from its own calibrated curve.

    layerBler = zeros(Nt, 1);                     % Per-layer predicted BLER of this candidate.

    valid = true;                                 % Whether every layer produced a prediction.

    for l = 1:Nt
        p = interpolate_bler_curve(blerCurves, mcsTable.McsIndex(m), qualityReport(l, m) + ollaOffsetDb);
        if isnan(p)
            valid = false;
            break;
        end
        layerBler(l) = p;
    end

    if valid                                      % Collapse the per-layer predictions into the selection criterion.
        if cfg.selectionCriterion == "worst"
            criterionAll(m) = max(layerBler);
        else
            criterionAll(m) = mean(layerBler);
        end
    end

end

if all(isnan(criterionAll))                       % No curve produced a prediction.
    selectedMcs = 0;  criterionBler = NaN;  selectionStatus = "no_valid_prediction";
    return;
end

satisfying = find(~isnan(criterionAll) & criterionAll <= cfg.targetBler);  % Candidates meeting the target.

if isempty(satisfying)                            % Nothing satisfied the target: lowest-MCS fallback.
    selectedMcs = 0;  criterionBler = criterionAll(1);  selectionStatus = "lowest_mcs_fallback";
    return;
end

se = mcsTable.NominalSpectralEfficiency(satisfying);      % Tie-break 1: highest nominal spectral efficiency.

best = satisfying(se == max(se));

if numel(best) > 1                                % Tie-break 2: lowest criterion BLER among equal efficiencies.
    cb = criterionAll(best);
    best = best(cb == min(cb));
end

if numel(best) > 1                                % Tie-break 3: lower modulation order.
    mo = mcsTable.ModulationOrder(best);
    best = best(mo == min(mo));
end

best = best(1);                                   % A unique candidate remains.

selectedMcs   = mcsTable.McsIndex(best);          % Selected common MCS of the slot.

criterionBler = criterionAll(best);               % Criterion prediction of the selection.

if best == numMcs                                 % Status reporting.
    selectionStatus = "highest_mcs_selected";
else
    selectionStatus = "target_met";
end

end
