
%% *** ls_pilot_estimate ***:
%% Least-squares channel estimation with spline interpolation:
%{
The function forms the least-squares MIMO channel estimate from the received pilot grid. With unit pilots the least-squares
estimate at each pilot subcarrier equals the received pilot observation. Because the comb pattern gives each transmit antenna
its own subcarriers, the estimate for one transmit antenna is interpolated from that antenna's pilot subcarriers to all
subcarriers with a spline, for each receive antenna.

Input:

    Y_pilot    Received frequency-domain pilot grid sized receive by subcarrier.
    pilotIdx   Cell array of pilot subcarrier indices per transmit antenna.
    Nr         Number of receive antennas.
    Nt         Number of transmit antennas.
    Nfft       FFT size.

Output:

    H_LS_est   Least-squares channel estimate sized receive by transmit by subcarrier.
%}

function H_LS_est = ls_pilot_estimate(Y_pilot, pilotIdx, Nr, Nt, Nfft)


%% Per-antenna estimation:
%%

H_LS_est = zeros(Nr, Nt, Nfft);                   % Initialize the channel estimate.

for n = 1:Nt                                      % Estimate the channel for each transmit antenna.

    pIdx = pilotIdx{n};                           % Pilot subcarriers of this transmit antenna.

    for m = 1:Nr                                  % Estimate the channel for each receive antenna.

        H_LS_p = Y_pilot(m, pIdx).';              % Least-squares estimate at the pilot subcarriers.

        H_LS_full = interp1(double(pIdx), H_LS_p, ...  % Spline interpolation to all subcarriers.
            (1:Nfft).', 'spline', 'extrap');

        H_LS_est(m, n, :) = H_LS_full;            % Store the interpolated estimate.

    end
end

end
