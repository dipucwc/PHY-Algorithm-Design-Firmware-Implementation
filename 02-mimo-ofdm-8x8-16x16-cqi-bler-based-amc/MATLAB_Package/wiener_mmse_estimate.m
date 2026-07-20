
%% *** wiener_mmse_estimate ***:
%% Wiener MMSE channel estimation:
%{
The function applies the precomputed Wiener filter to the pilot observations to produce the MMSE channel estimate at all
subcarriers. The filter combines the all-to-pilot and pilot-to-pilot correlation matrices with the noise variance, so it
uses the channel statistics to suppress the pilot noise. The filter is passed in per transmit antenna and is applied for each
receive antenna.

Input:

    Y_pilot    Received frequency-domain pilot grid sized receive by subcarrier.
    pilotIdx   Cell array of pilot subcarrier indices per transmit antenna.
    W          Cell array of Wiener filter matrices per transmit antenna.
    Nr         Number of receive antennas.
    Nt         Number of transmit antennas.
    Nfft       FFT size.

Output:

    H_MMSE_est   Wiener MMSE channel estimate sized receive by transmit by subcarrier.
%}

function H_MMSE_est = wiener_mmse_estimate(Y_pilot, pilotIdx, W, Nr, Nt, Nfft)


%% Per-antenna filtering:
%%

H_MMSE_est = zeros(Nr, Nt, Nfft);                 % Initialize the channel estimate.

for n = 1:Nt                                      % Filter the observations for each transmit antenna.

    pIdx = pilotIdx{n};                           % Pilot subcarriers of this transmit antenna.

    for m = 1:Nr                                  % Filter the observations for each receive antenna.

        H_LS_p = Y_pilot(m, pIdx).';              % Pilot observations at the pilot subcarriers.

        H_MMSE_est(m, n, :) = W{n} * H_LS_p;      % Apply the Wiener filter to all subcarriers.

    end
end

end
