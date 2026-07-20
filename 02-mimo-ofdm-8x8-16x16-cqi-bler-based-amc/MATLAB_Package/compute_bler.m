%{
=========================================================================================================================
 compute_bler.m — Block error rate with a 95 percent Wilson confidence interval
=========================================================================================================================

The function converts block counters into the measured block error rate together with a 95 percent Wilson score
confidence interval. The Wilson interval remains valid at very low and very high error counts, which matters near the
ends of the calibration curves where only a few failures or a few successes are observed.
=========================================================================================================================
%}

function [bler, ciLow, ciHigh] = compute_bler(failedBlocks, totalBlocks)

if totalBlocks == 0                               % Guard against an empty measurement.
    bler = NaN; ciLow = NaN; ciHigh = NaN;
    return;
end

bler = failedBlocks / totalBlocks;                % Measured block error rate.

z  = 1.96;                                        % 95 percent normal quantile.

n  = totalBlocks;                                 % Number of measured blocks.

center = (bler + z^2/(2*n)) / (1 + z^2/n);        % Wilson interval center.

half   = z * sqrt(bler*(1-bler)/n + z^2/(4*n^2)) / (1 + z^2/n);  % Wilson interval half width.

ciLow  = max(0, center - half);                   % Lower 95 percent confidence bound.

ciHigh = min(1, center + half);                   % Upper 95 percent confidence bound.

end
