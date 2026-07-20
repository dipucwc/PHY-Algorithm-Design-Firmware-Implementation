
%% *** apply_tdla_channel ***:
%% TDL-A tapped-delay-line channel:
%{
The function convolves a signal frame with a tapped-delay-line channel. Each tap adds a delayed and scaled copy of the input
to the output buffer. The delays and powers follow the TDL-A profile, whose maximum delay stays inside the cyclic prefix, so
the cyclic prefix removes the inter-symbol interference at the receiver. The output is truncated to the input length.

Input:

    txFrame          Transmitted signal frame.
    h_taps           Complex tap gains.
    tapDelays_samp   Integer tap delays in samples.

Output:

    rxChan   Received signal of the same length as the input frame.
%}

function rxChan = apply_tdla_channel(txFrame, h_taps, tapDelays_samp)


%% Convolution buffer:
%%

frameLen = length(txFrame);                       % Input frame length.

maxDelay = max(tapDelays_samp);                   % Maximum tap delay.

numTaps  = length(h_taps);                        % Number of taps.

rxBuf = zeros(frameLen + maxDelay, 1);            % Output buffer sized to hold the delayed copies.


%% Tap accumulation:
%%

for i = 1:numTaps                                 % Add each delayed and scaled copy of the input.
    d = tapDelays_samp(i);                        % Delay of the current tap.
    rxBuf(d+1:d+frameLen) = rxBuf(d+1:d+frameLen) + h_taps(i) * txFrame;
end

rxChan = rxBuf(1:frameLen);                       % Truncate the output to the input length.

end
