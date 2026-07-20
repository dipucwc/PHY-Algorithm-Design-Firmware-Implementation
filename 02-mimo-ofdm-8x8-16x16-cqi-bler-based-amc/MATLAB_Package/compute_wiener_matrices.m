
%% *** compute_wiener_matrices ***:
%% Channel correlation matrices for the Wiener MMSE estimator:
%{
The function precomputes the frequency-domain channel correlation matrices used by the Wiener MMSE channel estimator. The
correlation between two subcarriers is the transform of the delay-power profile evaluated at their spacing, so it depends
only on the channel statistics and not on any single realization. The full correlation matrix is formed once, and per
transmit antenna the pilot-to-pilot and all-to-pilot sub-matrices are extracted from it. The main script combines these with
the noise variance to build the Wiener filter at each SNR point.

Input:

    tapPowers        Normalized tap powers.
    tapDelays_samp   Integer tap delays in samples.
    Nfft             FFT size.
    pilotIdx         Cell array of pilot subcarrier indices per transmit antenna.
    Nt               Number of transmit antennas.

Output:

    R_PP   Cell array of pilot-to-pilot correlation matrices per transmit antenna.
    R_FP   Cell array of all-to-pilot correlation matrices per transmit antenna.
    R_HH   Full subcarrier correlation matrix.
%}

function [R_PP, R_FP, R_HH] = compute_wiener_matrices(tapPowers, tapDelays_samp, Nfft, pilotIdx, Nt)


%% Full correlation matrix:
%%

numTaps = length(tapPowers);                      % Number of taps in the profile.

sc     = (0:Nfft-1).';                            % Subcarrier index vector.

kldiff = bsxfun(@minus, sc, sc.');               % Pairwise subcarrier-index differences.

R_HH = zeros(Nfft, Nfft);                         % Initialize the full correlation matrix.

for i = 1:numTaps                                 % Add each tap contribution to the correlation matrix.
    R_HH = R_HH + tapPowers(i) * ...
        exp(-1j * 2*pi * tapDelays_samp(i) * kldiff / Nfft);
end


%% Per-antenna sub-matrices:
%%

R_PP = cell(Nt, 1);                               % Pilot-to-pilot correlation per transmit antenna.

R_FP = cell(Nt, 1);                               % All-to-pilot correlation per transmit antenna.

for n = 1:Nt                                      % Extract the sub-matrices for each transmit antenna.
    R_PP{n} = R_HH(pilotIdx{n}, pilotIdx{n});     % Pilot-to-pilot block.
    R_FP{n} = R_HH(:, pilotIdx{n});               % All-to-pilot block.
end

end
