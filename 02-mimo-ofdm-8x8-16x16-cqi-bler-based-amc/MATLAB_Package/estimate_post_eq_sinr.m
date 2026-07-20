%{
=========================================================================================================================
 estimate_post_eq_sinr.m — Receiver-side per-stream post-equalization SINR from the estimated channel
=========================================================================================================================

The function computes the post-MMSE-equalization signal-to-interference-plus-noise ratio of every spatial stream at
every subcarrier from the estimated channel alone, exactly as a practical receiver would. For stream l with equalizer
row w_l and estimated channel columns h_j, the estimate is

    SINR_l = |w_l h_l|^2 Es / ( sum_{j~=l} |w_l h_j|^2 Es + ||w_l||^2 sigma^2 ),

where Es is the transmitted symbol energy and sigma^2 the receiver-noise variance. The equalizer weights are the same
regularized MMSE weights applied by mmse_equalize_soft, so the estimate describes the detector actually in use. The
output is one SINR value per stream and subcarrier at the pilot-time channel estimate; the caller replicates it across
the data symbols of the slot, which states explicitly that the practical estimate is held constant over the slot.
=========================================================================================================================
%}

function [sinrLinear, equalizerWeights, biasGain, nvarEff] = estimate_post_eq_sinr( ...
    Hest, noiseVariance, symbolEnergy, Nt)

Nfft = size(Hest, 3);                             % Number of subcarriers.

sinrLinear       = zeros(Nt, Nfft);               % Per-stream, per-subcarrier SINR estimate.

equalizerWeights = zeros(Nt, size(Hest,1), Nfft); % MMSE equalizer rows per subcarrier.

biasGain         = zeros(Nt, Nfft);               % Per-stream MMSE bias gains.

nvarEff          = zeros(Nt, Nfft);               % Per-stream effective noise variances.

for k = 1:Nfft                                    % Process every subcarrier.

    H_k = squeeze(Hest(:,:,k)) / sqrt(Nt);        % Estimated channel scaled for the transmit-power split.

    W_k = (H_k' * H_k + noiseVariance * eye(Nt)) \ H_k';  % Regularized MMSE weight identical to the detector.

    G_k = W_k * H_k;                              % Weight-times-channel product.

    g_k = max(real(diag(G_k)), 1e-6);             % Per-stream bias gains.

    for l = 1:Nt                                  % Evaluate every spatial stream.

        signalPower = abs(G_k(l,l))^2 * symbolEnergy;                 % Desired-stream power at the equalizer output.

        interference = (sum(abs(G_k(l,:)).^2) - abs(G_k(l,l))^2) * symbolEnergy;  % Residual inter-stream power.

        noisePower  = (W_k(l,:) * W_k(l,:)') * noiseVariance;         % Enhanced noise power of the equalizer row.

        sinrLinear(l,k) = signalPower / max(interference + real(noisePower), 1e-12);  % Per-stream SINR estimate.

    end

    equalizerWeights(:,:,k) = W_k;                % Store the weights for the shared equalization step.

    biasGain(:,k) = g_k;                          % Store the bias gains.

    nvarEff(:,k)  = max((1 - g_k) ./ g_k, 1e-6);  % Effective noise variance of the unbiased output.

end

end
