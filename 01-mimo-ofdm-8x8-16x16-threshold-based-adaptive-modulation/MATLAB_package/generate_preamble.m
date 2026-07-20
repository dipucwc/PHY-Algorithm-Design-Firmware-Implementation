
%% *** generate_preamble ***:
%% Schmidl-Cox preamble generation for OFDM synchronization:
%{
The function builds one Schmidl-Cox preamble OFDM symbol. QAM symbols are placed only on the even frequency bins, which
makes the two halves of the time-domain body identical up to the carrier-offset phase shift. That repetition is what the
timing metric and the coarse carrier-offset estimator exploit at the receiver.

The preamble must be identical at the transmitter and the receiver, so its symbols are drawn from a fixed seed. The current
random-number-generator state is saved before the fixed draw and restored afterwards, so the surrounding Monte Carlo stream
is left unchanged.

Input:

    Nfft    FFT size and number of subcarriers.
    cpLen   Cyclic prefix length in samples.
    M       QAM modulation order used for the preamble symbols.

Output:

    preamble      Time-domain preamble with the cyclic prefix prepended.
    P_freq        Frequency-domain preamble spectrum.
    preambleLen   Total preamble length in samples.
%}

function [preamble, P_freq, preambleLen] = generate_preamble(Nfft, cpLen, M)


%% Fixed preamble draw:
%%

L = Nfft / 2;                                     % Half-symbol length of the preamble body.

sPrev = rng;                                      % Save the current random-number-generator state.

rng(0, 'twister');                                % Set the fixed seed used for the known preamble sequence.

P_even = qammod(randi([0 1], L*log2(M), 1), M, ...  % Draw the even-subcarrier QAM symbols from the fixed seed.
    'InputType', 'bit', 'UnitAveragePower', true);

rng(sPrev);                                       % Restore the previous state so the Monte Carlo stream is unchanged.


%% Subcarrier mapping:
%%

P_freq = zeros(Nfft, 1);                          % Initialize the frequency-domain preamble grid.

P_freq(1:2:Nfft) = P_even;                        % Place the symbols on the even frequency bins so the halves repeat.


%% Time-domain assembly:
%%

p_time      = ifft(P_freq, Nfft);                 % Transform the preamble grid to the time domain.

preamble    = [p_time(end-cpLen+1:end); p_time];  % Prepend the cyclic prefix.

preambleLen = length(preamble);                   % Total preamble length in samples.

end
