
%% *** mimo_freq_response ***:
%% Time-varying MIMO frequency response:
%{
The function builds the receive-by-transmit-by-subcarrier channel matrix at a given symbol time. Each tap gain rotates in
time under a common Doppler phase, and each tap adds a frequency-domain phase shift set by its delay. The tap contributions
are summed across all subcarriers with an outer product. Calling the function once per OFDM symbol captures the Doppler
variation between the pilot symbol and each data symbol across the slot.

Input:

    initG       Initial complex tap gains sized receive by transmit by tap.
    initPh      Initial random tap phases sized receive by transmit by tap.
    tapDelays   Integer tap delays in samples.
    numTaps     Number of taps.
    Nfft        FFT size.
    fd          Maximum Doppler frequency in hertz.
    t_sym       Symbol time offset from the slot start in seconds.

Output:

    H_freq   Channel matrix sized receive by transmit by subcarrier.
%}

function H_freq = mimo_freq_response(initG, initPh, tapDelays, numTaps, Nfft, fd, t_sym)


%% Tap summation:
%%

Nr = size(initG, 1);                              % Number of receive antennas.

Nt = size(initG, 2);                              % Number of transmit antennas.

H_freq = zeros(Nr, Nt, Nfft);                     % Initialize the channel matrix.

for i = 1:numTaps                                 % Add each tap contribution.

    G_i = initG(:,:,i) .* ...                     % Apply the common Doppler phase to the tap gain.
        exp(1j * (2*pi*fd*t_sym + initPh(:,:,i)));

    phase_vec = exp(-1j * 2*pi * (0:Nfft-1) * tapDelays(i) / Nfft);  % Frequency-domain phase shift of the tap.

    H_freq = H_freq + reshape(G_i(:) * phase_vec, Nr, Nt, Nfft);     % Add the tap across all subcarriers.

end

end
