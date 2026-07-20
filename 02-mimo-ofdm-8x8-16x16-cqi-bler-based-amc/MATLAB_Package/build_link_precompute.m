%{
=========================================================================================================================
 build_link_precompute.m — Pilot pattern, tap powers, and Wiener correlation matrices for one array size
=========================================================================================================================

The function precomputes the quantities that depend only on the array size and channel profile: the normalized tap
powers, the non-overlapping comb pilot pattern that assigns each transmit antenna its own subcarrier subset, and the
Wiener correlation matrices from which the noise-dependent Wiener filter is later built at every SNR point. These
replicate the verified Project 1 platform exactly.
=========================================================================================================================
%}

function link = build_link_precompute(cfg)

link.numTaps   = numel(cfg.tapDelays_samp);       % Number of channel taps.

link.tapPowers = 10.^(cfg.tapPowers_dB/10);       % Linear tap powers.

link.tapPowers = link.tapPowers / sum(link.tapPowers);  % Unit total power.

link.pilotIdx  = cell(cfg.Nt, 1);                 % Comb pilot indices per transmit antenna.

link.pilotSC_tx = zeros(cfg.Nfft, 1);             % Active antenna per pilot subcarrier.

for n = 1:cfg.Nt                                  % Non-overlapping combs.
    link.pilotIdx{n} = (n:cfg.Nt:cfg.Nfft).';
    link.pilotSC_tx(link.pilotIdx{n}) = n;
end

[link.R_PP, link.R_FP, ~] = compute_wiener_matrices( ...  % Wiener correlation matrices.
    link.tapPowers, cfg.tapDelays_samp, cfg.Nfft, link.pilotIdx, cfg.Nt);

end
