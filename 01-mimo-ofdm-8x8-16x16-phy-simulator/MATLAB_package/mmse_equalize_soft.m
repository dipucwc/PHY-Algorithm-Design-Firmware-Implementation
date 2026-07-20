
%% *** mmse_equalize_soft ***:
%% Soft-output MMSE MIMO equalization at one subcarrier:
%{
The function recovers the transmit symbols at one subcarrier with the MMSE equalizer and returns the quantities needed for
soft-decision decoding. It forms the regularized MMSE weight, applies it to the received vector, and reads the per-stream
gain from the diagonal of the weight-times-channel product. Dividing by that gain removes the MMSE bias, and the per-stream
effective noise variance is formed from the same gain. The biased estimate is retained only for diagnostic or reference analysis; both the hard and soft decoder paths, and the
uncoded EVM and SINR metrics, use the gain-corrected unbiased estimate with the effective noise variance for hard bit demapping and log-likelihood-ratio scaling.

Input:

    H_k        Channel matrix at the subcarrier sized receive by transmit.
    y_k        Received signal vector at the subcarrier.
    noiseVar   Noise variance equal to the inverse of the linear SNR.
    Nt         Number of transmit antennas.

Output:

    xhat_biased   Biased MMSE estimate retained only for diagnostic or reference analysis.
    xhat_soft     Gain-corrected unbiased MMSE estimate used for
                  uncoded metrics and both hard- and soft-decision paths.
    nvar_eff      Per-stream effective noise variance used for log-likelihood-ratio scaling.
%}

function [xhat_biased, xhat_soft, nvar_eff] = mmse_equalize_soft(H_k, y_k, noiseVar, Nt)


%% MMSE weight and biased estimate:
%%

Winv = (H_k' * H_k + noiseVar * eye(Nt)) \ H_k';  % Build the regularized MMSE weight.

xhat_biased = Winv * y_k;                         % Apply the weight to the received vector.


%% Bias removal and effective noise variance:
%%

G = Winv * H_k;                                   % Weight-times-channel product.

g = real(diag(G));                                % Per-stream gain from the diagonal.

g = max(g, 1e-6);                                 % Floor the gain to avoid division by a small number.

xhat_soft = xhat_biased ./ g;                     % Remove the MMSE bias.

nvar_eff = (1 - g) ./ g;                          % Per-stream effective noise variance for unit signal power.

nvar_eff = max(nvar_eff, 1e-6);                   % Floor the effective noise variance.

end
