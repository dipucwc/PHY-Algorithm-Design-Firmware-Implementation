
%% *** schmidl_cox_metric ***:
%% Normalized Schmidl-Cox timing metric:
%{
The function computes the normalized Schmidl-Cox timing metric from the received signal. The metric correlates the two
identical halves of the preamble body. It reaches its maximum when the sliding window straddles the two halves, which marks
the preamble timing. The correlation and the energy normalization are formed with cumulative sums so that the whole search
range is evaluated without an inner loop.

Input:

    rxRaw         Received signal vector.
    L             Half-symbol length equal to the FFT size divided by two.
    preambleLen   Total preamble length in samples.
    cpLen         Cyclic prefix length in samples.
    frameLen      Total received frame length in samples.

Output:

    Lambda      Normalized timing metric over the search range.
    M_sc        Complex autocorrelation over the search range.
    P_sc        Energy normalization over the search range.
    searchLen   Number of evaluated timing positions.
%}

function [Lambda, M_sc, P_sc, searchLen] = schmidl_cox_metric(rxRaw, L, preambleLen, cpLen, frameLen)


%% Search range:
%%

searchLen = preambleLen + cpLen + 1;              % Nominal number of timing positions to evaluate.

searchLen = min(searchLen, frameLen - 2*L);       % Clip the range to fit the available samples.


%% Windowed products:
%%

r1_mat = rxRaw(1:searchLen+L-1);                  % Samples aligned with the first half of the window.

r2_mat = rxRaw(L+1:searchLen+2*L-1);              % Samples aligned with the second half of the window.

prod_cr = conj(r1_mat) .* r2_mat;                 % Cross-product between the two halves.

prod_p  = abs(r2_mat).^2;                         % Energy of the second half.


%% Sliding-window sums:
%%

csum_cr = [0; cumsum(prod_cr)];                   % Cumulative sum of the cross-product.

csum_p  = [0; cumsum(prod_p)];                    % Cumulative sum of the energy.

M_sc = csum_cr(L+1:searchLen+L) - csum_cr(1:searchLen);  % Windowed autocorrelation.

P_sc = csum_p(L+1:searchLen+L) - csum_p(1:searchLen);    % Windowed energy.


%% Normalized metric:
%%

Lambda = abs(M_sc).^2 ./ max(P_sc.^2, eps);       % Normalized metric bounded in the zero-to-one range.

end
