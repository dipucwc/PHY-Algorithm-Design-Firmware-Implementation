
%% *** compute_evm ***:
%% RMS error vector magnitude:
%{
The function computes the RMS error vector magnitude as a percentage. It takes the mean squared error between the reference
and received symbols, normalizes it by the mean reference power, and returns the square root as a percentage. The reference
and received vectors are compared over their common length.

Input:

    txSyms   Reference transmitted symbols.
    rxSyms   Received or equalized symbols.

Output:

    evm_pct   RMS error vector magnitude in percent.
%}

function evm_pct = compute_evm(txSyms, rxSyms)


%% Metric calculation:
%%

N = min(length(txSyms), length(rxSyms));          % Common length of the two vectors.

if N == 0                                         % Return zero when there are no symbols.
    evm_pct = 0;
    return;
end

err_pow = mean(abs(txSyms(1:N) - rxSyms(1:N)).^2);  % Mean squared error.

ref_pow = mean(abs(txSyms(1:N)).^2);              % Mean reference power.

evm_pct = sqrt(err_pow / max(ref_pow, 1e-12)) * 100;  % Normalized RMS error vector magnitude in percent.

end
