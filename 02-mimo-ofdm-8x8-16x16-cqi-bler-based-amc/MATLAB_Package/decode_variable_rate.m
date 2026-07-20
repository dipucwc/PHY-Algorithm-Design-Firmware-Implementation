%{
=========================================================================================================================
 decode_variable_rate.m — Deinterleaving, depuncturing, soft Viterbi decoding, and CRC verification for one codeword
=========================================================================================================================

The function inverts the variable-rate encoding chain for one codeword from the received per-bit log-likelihood
ratios. The padding is dropped, the interleaver permutation is inverted, the punctured positions are restored as
zero-valued erasures, the terminated mother code is decoded with the unquantized soft Viterbi metric, the tail bits
are removed, and the CRC-16 field is verified. The CRC verdict alone defines block success.
=========================================================================================================================
%}

function [crcPass, infoBitsHat] = decode_variable_rate(rxLlr, cw, trellis, cfg)

codewordLlr = rxLlr(1:cw.containerBits - cw.padLength);        % Drop the known zero padding.

deinterleaved = zeros(size(codewordLlr));                      % Invert the interleaver permutation.

deinterleaved(cw.interleaverPerm) = codewordLlr;

motherLlr = depuncture_llr(deinterleaved, cw.keptPositions, cw.motherLength);  % Restore erasures.

decoded = vitdec(motherLlr, trellis, cfg.tracebackDepth, 'term', 'unquant');   % Terminated soft Viterbi decoding.

receivedBlock = decoded(1:end-cfg.tailBits);                   % Remove the tail bits.

[crcPass, infoBitsHat] = check_crc(receivedBlock, cfg.crcLength, cfg.crcPolynomial);  % Verify the CRC.

end
