
%% *** apply_cfo ***:
%% Carrier-frequency-offset phase ramp:
%{
The function applies a carrier-frequency-offset phase ramp to a time-domain signal. A positive offset models the
transmit-side impairment, and a negative offset applies the receive-side compensation. The rotation advances by the
normalized offset per subcarrier spacing across the sample index.

Input:

    rxIn      Input signal vector.
    epsilon   Normalized offset in subcarrier spacings.
    Nfft      FFT size that sets the rotation rate per sample.

Output:

    rxOut   Output signal with the phase ramp applied.
%}

function rxOut = apply_cfo(rxIn, epsilon, Nfft)


%% Phase ramp:
%%

N     = length(rxIn);                             % Signal length.

n_vec = (0:N-1).';                                % Sample-index vector.

rxOut = rxIn .* exp(1j * 2*pi * epsilon * n_vec / Nfft);  % Apply the offset phase ramp.

end
