%{
=========================================================================================================================
 encode_variable_rate.m — CRC attachment, terminated encoding, puncturing, interleaving, and padding for one codeword
=========================================================================================================================

The function builds the transmitted bit stream of one codeword at the requested coding rate. The information bits
receive the CRC-16 field, the tail bits terminate the mother code in the zero state, the terminated stream is encoded
by the rate-1/2 mother code, the puncturing mask raises the rate, a seeded random bit interleaver spreads the
codeword across the frequency-selective resource elements, and known zero padding fills the codeword container up to
the fixed number of channel bits. The structure returned alongside the bits carries every quantity the receiver needs
to invert the chain deterministically.
=========================================================================================================================
%}

function [txBits, cw] = encode_variable_rate(infoBits, codeRate, containerBits, trellis, cfg, interleaverSeed)

blockWithCrc = append_crc(infoBits, cfg.crcPolynomial);        % Attach the CRC-16 field.

terminated   = [blockWithCrc; zeros(cfg.tailBits, 1)];         % Append the tail bits for code termination.

motherBits   = convenc(terminated, trellis);                   % Encode with the rate-1/2 mother code.

punctureMask = select_puncturing_pattern(codeRate);            % Select the puncturing mask for the coding rate.

[punctured, keptPositions] = apply_puncturing(motherBits, punctureMask);  % Remove the punctured positions.

assert(numel(punctured) <= containerBits, ...                  % The codeword must fit its channel-bit container.
    'Punctured codeword (%d bits) exceeds the container (%d bits).', numel(punctured), containerBits);

interleaverStream = RandStream('mt19937ar', 'Seed', interleaverSeed);  % Deterministic interleaver stream.

interleaverPerm   = randperm(interleaverStream, numel(punctured)).';   % Random bit interleaver permutation.

interleaved       = punctured(interleaverPerm);                % Interleave the punctured codeword.

padLength = containerBits - numel(interleaved);                % Known zero padding filling the container.

txBits    = [interleaved; zeros(padLength, 1)];                % Transmitted channel bits of the codeword.

cw.numInfoBits     = numel(infoBits);             % Information bits carried by the codeword.
cw.codeRate        = codeRate;                    % Coding rate of the codeword.
cw.motherLength    = numel(motherBits);           % Mother-code stream length.
cw.keptPositions   = keptPositions;               % Transmitted mother-stream positions.
cw.interleaverPerm = interleaverPerm;             % Interleaver permutation.
cw.padLength       = padLength;                   % Zero-padding length.
cw.containerBits   = containerBits;               % Channel bits of the container.

end
