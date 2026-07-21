%{
=========================================================================================================================
 depuncture_llr.m — Restore punctured positions as zero-valued erasure log-likelihood ratios
=========================================================================================================================

The function rebuilds the mother-code-length soft stream from the received log-likelihood ratios by writing each
received value back to its kept position and leaving every punctured position at exactly zero. A zero log-likelihood
ratio expresses no preference between bit zero and bit one, which is the correct erasure statement for a position the
transmitter never sent.
=========================================================================================================================
%}

function motherLlr = depuncture_llr(receivedLlr, keptPositions, motherLength)

motherLlr = zeros(motherLength, 1);               % Every position starts as a zero-valued erasure.

motherLlr(keptPositions) = receivedLlr(:);        % Restore the received soft values at the kept positions.

end
