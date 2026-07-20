%{
=========================================================================================================================
 prepare_slot_shared.m — Shared channel, noise, channel estimate, equalizer weights, and receiver SINR for one slot
=========================================================================================================================

The function draws one slot realization and precomputes everything that is common to every adaptation method
evaluated on that slot: the time-varying channel matrices of every data symbol, the pilot and data noise, the Wiener
MMSE channel estimate from the comb pilot symbol, the regularized MMSE equalizer weights with their bias gains and
effective noise variances, the receiver-side per-stream SINR estimate from the estimated channel, and a
reference-based measured SINR from the true pilot-time channel used for verification and for the oracle method. All
random draws come from the realization stream seeded per slot, so the same seed reproduces the identical slot.
=========================================================================================================================
%}

function shared = prepare_slot_shared(cfg, link, realizationStream)

Nt = cfg.Nt;  Nr = cfg.Nr;  Nfft = cfg.Nfft;  nSym = cfg.numDataSymbols;


%% Channel realization:
%%

initG  = zeros(Nr, Nt, link.numTaps);             % Initial complex tap gains.

initPh = 2*pi*rand(realizationStream, Nr, Nt, link.numTaps);  % Initial random tap phases.

for i = 1:link.numTaps                            % One Rayleigh tap-gain matrix per path.
    initG(:,:,i) = sqrt(link.tapPowers(i)) * ...
        (randn(realizationStream, Nr, Nt) + 1j*randn(realizationStream, Nr, Nt)) / sqrt(2);
end

shared.Hd = cell(nSym, 1);                        % Power-split data channel per OFDM symbol.

for s = 1:nSym                                    % Evolve the channel across the slot.
    H = mimo_freq_response(initG, initPh, cfg.tapDelays_samp, ...
        link.numTaps, Nfft, cfg.fd_max, s * cfg.symbolDur);
    shared.Hd{s} = H / sqrt(Nt);                  % Fold in the transmit-power split.
end

H_pilot = mimo_freq_response(initG, initPh, cfg.tapDelays_samp, ...  % Pilot-time channel.
    link.numTaps, Nfft, cfg.fd_max, 0);


%% Shared noise:
%%

shared.pilotNoise = sqrt(link.noiseVar/2) * ...   % Pilot-symbol noise.
    (randn(realizationStream, Nr, Nfft) + 1j*randn(realizationStream, Nr, Nfft));

shared.dataNoise  = sqrt(link.noiseVar/2) * ...   % Data-symbol noise tensor shared by every method.
    (randn(realizationStream, Nr, Nfft, nSym) + 1j*randn(realizationStream, Nr, Nfft, nSym));


%% Pilot reception and channel estimation:
%%

Y_pilot = zeros(Nr, Nfft);                        % Received comb pilot grid.

for k = 1:Nfft                                    % Each subcarrier carries one active transmit antenna.
    Y_pilot(:,k) = H_pilot(:, link.pilotSC_tx(k), k) + shared.pilotNoise(:,k);
end

shared.Hest = wiener_mmse_estimate(Y_pilot, link.pilotIdx, link.W_wiener, Nr, Nt, Nfft);  % Wiener MMSE estimate.


%% Equalizer weights and receiver SINR estimate:
%%

[shared.sinrEst, shared.W, shared.g, shared.nvar] = estimate_post_eq_sinr( ...  % Estimated-channel SINR and weights.
    shared.Hest, link.noiseVar, 1, Nt);

[shared.sinrTrue, ~, ~, ~] = estimate_post_eq_sinr( ...  % Reference SINR from the true pilot-time channel.
    H_pilot, link.noiseVar, 1, Nt);

end
