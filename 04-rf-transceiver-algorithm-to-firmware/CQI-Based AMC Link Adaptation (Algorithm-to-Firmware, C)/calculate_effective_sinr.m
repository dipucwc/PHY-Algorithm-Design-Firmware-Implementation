%{
=========================================================================================================================
 calculate_effective_sinr.m — Mean, minimum, and EESM effective-SINR mapping over the codeword resource elements
=========================================================================================================================

The function collapses the per-resource-element SINR values of one codeword into a single effective SINR. The mean
mapping averages the linear SINR values and can overestimate the quality of frequency-selective codewords because a
few very weak resource elements dominate the decoded performance. The minimum mapping is conservative. The primary
mapping is the exponential effective-SINR mapping

    SINR_eff = -beta * ln( (1/N) * sum_n exp( -SINR_n / beta ) ),

whose calibration parameter beta depends on the MCS and weights weak resource elements the way the decoder
experiences them.
=========================================================================================================================
%}

function effectiveSinrDb = calculate_effective_sinr(sinrLinear, method, beta)

s = sinrLinear(:);                                % Resource-element SINR values of the codeword.

switch lower(string(method))

    case "mean"                                   % Arithmetic mean of the linear SINR values.
        eff = mean(s);

    case "minimum"                                % Worst resource element of the codeword.
        eff = min(s);

    case "eesm"                                   % Exponential effective-SINR mapping with parameter beta.
        eff = -beta * log(mean(exp(-s / beta)));

    otherwise
        error('Unknown effective-SINR method "%s".', method);
end

effectiveSinrDb = 10*log10(max(eff, 1e-12));      % Effective SINR in decibels.

end
