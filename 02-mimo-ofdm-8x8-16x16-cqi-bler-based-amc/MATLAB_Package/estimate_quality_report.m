%{
=========================================================================================================================
 estimate_quality_report.m — Per-layer, per-candidate effective-SINR quality report
=========================================================================================================================

The function builds the uncorrected link-quality report of one slot: one effective SINR per spatial-layer codeword
and per candidate MCS. Each layer carries one independent codeword, so the mapping is evaluated over that layer's own
subcarrier SINR profile with the calibration parameter of each candidate, which restores the codeword-level meaning
of the effective SINR that a slot-wide scalar cannot provide. The report contains no outer-loop correction; the
transmitter applies its own current offset after the feedback delay.
=========================================================================================================================
%}

function qualityReport = estimate_quality_report(sinrLinear, mapping, cfg)

numMcs = numel(cfg.eesmBeta);                     % Number of candidate MCS entries.

Nt = size(sinrLinear, 1);                         % One codeword per spatial layer.

qualityReport = zeros(Nt, numMcs);                % Per-layer, per-candidate effective SINR in decibels.

for l = 1:Nt                                      % Evaluate every layer codeword separately.

    layerSinr = sinrLinear(l, :);                 % Subcarrier SINR profile of this layer's codeword.

    for m = 1:numMcs                              % Evaluate every candidate with its own calibration parameter.
        qualityReport(l, m) = calculate_effective_sinr(layerSinr, mapping, cfg.eesmBeta(m));
    end

end

end
