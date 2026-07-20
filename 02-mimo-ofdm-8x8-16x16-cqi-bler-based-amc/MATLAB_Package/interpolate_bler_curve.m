%{
=========================================================================================================================
 interpolate_bler_curve.m — Monotonic BLER prediction from a calibrated curve
=========================================================================================================================

The function predicts the block error rate of one MCS at a queried effective SINR from its calibrated curve. The
calibration points are sorted by effective SINR and forced monotonically nonincreasing with a running minimum before
linear interpolation, because a physical BLER curve cannot rise with improving effective SINR and Monte Carlo noise
must not create spurious local increases. Queries beyond the calibrated range clamp to the end values.
=========================================================================================================================
%}

function predictedBler = interpolate_bler_curve(blerCurves, mcsIndex, effectiveSinrDb)

rows = blerCurves.McsIndex == mcsIndex;           % Calibration points of the requested MCS.

if ~any(rows)                                     % No calibration data means no valid prediction.
    predictedBler = NaN;
    return;
end

sinr = blerCurves.EffectiveSinrDb(rows);          % Calibrated effective-SINR points.

bler = blerCurves.MeasuredBler(rows);             % Calibrated BLER points.

[sinr, order] = sort(sinr);                       % Sort by effective SINR.

bler = cummin(bler(order));                       % Enforce a monotonically nonincreasing curve.

if isscalar(sinr)                                 % A single point predicts a constant.
    predictedBler = bler;
elseif effectiveSinrDb <= sinr(1)                 % Clamp below the calibrated range.
    predictedBler = bler(1);
elseif effectiveSinrDb >= sinr(end)               % Clamp above the calibrated range.
    predictedBler = bler(end);
else
    predictedBler = interp1(sinr, bler, effectiveSinrDb, 'linear');  % Interpolate inside the range.
end

end
