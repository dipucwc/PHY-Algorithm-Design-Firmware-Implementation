
%% *** compute_mimo_capacity ***:
%% MIMO ergodic capacity from the channel singular values:
%{
The function computes the ergodic capacity of the MIMO channel. For each subcarrier it takes the singular values of the
channel matrix scaled for the transmit-power split, and sums the capacity of each spatial mode under equal power allocation.
The per-subcarrier capacities are averaged across all subcarriers.

Input:

    H_freq      Channel matrix sized receive by transmit by subcarrier.
    SNRlinear   Linear SNR.
    Nfft        FFT size.
    Nt          Number of transmit antennas used for the power-split scaling.

Output:

    C   Ergodic capacity in bits per second per hertz.
%}

function C = compute_mimo_capacity(H_freq, SNRlinear, Nfft, Nt)


%% Subcarrier accumulation:
%%

capSC = 0;                                        % Accumulated capacity over the subcarriers.

for k = 1:Nfft                                    % Sum the capacity of each subcarrier.

    H_k = squeeze(H_freq(:,:,k)) / sqrt(Nt);      % Channel scaled for the transmit-power split.

    sv  = svd(H_k);                               % Singular values of the subcarrier channel.

    capSC = capSC + sum(log2(1 + SNRlinear * sv.^2));  % Add the capacity of the spatial modes.

end

C = capSC / Nfft;                                 % Average the capacity over the subcarriers.

end
