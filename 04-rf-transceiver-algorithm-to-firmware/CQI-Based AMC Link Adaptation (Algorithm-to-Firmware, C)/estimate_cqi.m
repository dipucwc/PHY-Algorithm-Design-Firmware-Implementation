%{
=========================================================================================================================
 estimate_cqi.m — Receiver-side uncorrected CQI from the per-layer quality report
=========================================================================================================================

The function generates the receiver's channel-quality indicator: it builds the per-layer, per-candidate quality
report of the slot and reports the BLER-constrained selection at zero outer-loop offset, so the report carries no
transmitter-side correction. The quality report is returned alongside the integer CQI, because the delayed feedback
carries the full report and the transmitter reruns the selection with its own current offset; the integer CQI serves
the result logging and the convergence traces. The simplified research model treats the CQI and the MCS index as
equal; no separate standardized CQI-to-MCS table is claimed.
=========================================================================================================================
%}

function [cqi, qualityReport] = estimate_cqi(sinrLinear, blerCurves, mcsTable, cfg, mapping)

qualityReport = estimate_quality_report(sinrLinear, mapping, cfg);   % Uncorrected per-layer, per-candidate report.

[cqi, ~, ~] = select_mcs_for_target_bler(qualityReport, blerCurves, mcsTable, cfg, 0);  % Zero-offset selection.

end
