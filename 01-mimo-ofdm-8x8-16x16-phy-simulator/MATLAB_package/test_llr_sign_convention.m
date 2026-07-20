
%% *** test_llr_sign_convention ***:
%% Noiseless unit test of the log-likelihood-ratio sign convention:
%{
The script verifies that the sign convention of the approximate log-likelihood ratios produced by qamdemod matches the
convention expected by the unquantized soft-decision Viterbi decoder. A known information sequence is encoded with the
rate-1/2 convolutional code, mapped to unit-power QAM symbols, and demapped to log-likelihood ratios without any channel
or noise. The soft decoder must then recover the information bits with zero errors at every supported modulation order.
A sign mismatch between the demapper and the decoder produces massive errors here, so the test fails loudly rather than
silently degrading the coded results. The test is standalone and touches no simulation state.

Input:

    None. The test fixes its own seed and parameters.

Output:

    Console PASS or FAIL line per modulation order, and an error on any failure.
%}


%% Test execution:
%%

rng(3);                                           % Fix the seed for a reproducible test.

trellis = poly2trellis(7, [133 171]);            % Rate-1/2 constraint-length-7 convolutional code.

tbDepth = 5 * 7;                                  % Viterbi traceback depth.

nvSmall = 1e-3;                                   % Small noise variance used only for the LLR scaling.

for M = [4 16 64]                                 % Test every supported modulation order.

    bps      = log2(M);                           % Bits per QAM symbol.

    numInfo  = 600;                               % Number of information bits.

    infoBits = randi([0 1], numInfo, 1);          % Known information sequence.

    coded    = convenc(infoBits, trellis);        % Encode the information bits.

    pad      = mod(-numel(coded), bps);           % Pad length to fill whole symbols.

    txBits   = [coded; zeros(pad, 1)];            % Padded coded stream.

    txSym    = qammod(txBits, M, ...              % Map to unit-power QAM symbols.
        'InputType', 'bit', 'UnitAveragePower', true);

    llr = qamdemod(txSym, M, ...                  % Demap noiseless symbols to log-likelihood ratios.
        'OutputType', 'approxllr', 'UnitAveragePower', true, ...
        'NoiseVariance', nvSmall);

    dec = vitdec(llr(1:numel(coded)), ...         % Decode with the unquantized soft metric.
        trellis, tbDepth, 'trunc', 'unquant');

    nErr = sum(infoBits ~= dec(1:numInfo));       % Count decoded-bit errors.

    if nErr == 0                                  % Report the verdict for this modulation order.
        fprintf('LLR sign convention PASS at M = %d\n', M);
    else
        error('LLR sign convention FAIL at M = %d with %d errors', M, nErr);
    end

end

fprintf('LLR sign-convention test complete\n');
