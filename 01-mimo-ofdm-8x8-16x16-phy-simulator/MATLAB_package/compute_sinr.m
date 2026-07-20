
%% *** compute_sinr ***:
%% Post-equalization SINR:
%{
The function computes the post-equalization signal-to-interference-plus-noise ratio in decibels. It uses the reference
symbols as the ideal signal and the difference between the reference and equalized symbols as the combined interference and
noise. The ratio measures how well the equalizer separated the spatial streams.

Input:

    txSyms   Reference transmitted symbols.
    rxSyms   Equalized received symbols.

Output:

    sinr_dB   Post-equalization SINR in decibels.
%}

function sinr_dB = compute_sinr(txSyms, rxSyms)


%% Metric calculation:
%%

N = min(length(txSyms), length(rxSyms));          % Common length of the two vectors.

if N == 0                                         % Return zero when there are no symbols.
    sinr_dB = 0;
    return;
end

sig_pow = mean(abs(txSyms(1:N)).^2);              % Reference signal power.

err_pow = mean(abs(txSyms(1:N) - rxSyms(1:N)).^2);  % Combined interference and noise power.

sinr_dB = 10 * log10(sig_pow / max(err_pow, 1e-12));  % Post-equalization SINR in decibels.

end
