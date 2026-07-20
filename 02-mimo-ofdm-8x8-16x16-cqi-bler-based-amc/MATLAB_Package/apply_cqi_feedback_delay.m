%{
=========================================================================================================================
 apply_cqi_feedback_delay.m — Causal feedback buffer for the per-layer quality report
=========================================================================================================================

The function implements the CQI feedback delay as a first-in-first-out buffer of quality reports. The report measured
in slot t becomes available to the transmitter only in slot t plus the configured delay; before the first report has
propagated through the buffer, an empty report is returned and the transmitter falls back to the configured initial
MCS. The buffered payload is the uncorrected per-layer, per-candidate quality report, so the transmitter can apply
its current outer-loop offset and rerun the BLER-constrained selection at transmission time. The buffer enforces
causality structurally: the payload returned for the current slot was inserted at least cqiDelaySlots slots earlier.
=========================================================================================================================
%}

function [delayedReport, state] = apply_cqi_feedback_delay(state, newReport, cfg)

if ~isfield(state, 'buffer') || isempty(state.buffer)     % Initialize the buffer on first use.
    state.buffer = cell(cfg.cqiDelaySlots, 1);            % Empty payloads mark the initial-MCS slots.
end

delayedReport = state.buffer{1};                  % The oldest buffered report drives this slot; empty means none yet.

state.buffer = [state.buffer(2:end); {newReport}];  % Shift the buffer and insert the newest report.

end
