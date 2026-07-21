%{
=========================================================================================================================
 apply_puncturing.m — Remove punctured positions from the mother-code output
=========================================================================================================================

The function tiles the periodic puncturing mask over the mother-code bit stream and keeps only the positions marked
for transmission. The kept-position index list is also returned so that the depuncturing routine can restore the
punctured positions as erasures at exactly the removed locations.
=========================================================================================================================
%}

function [puncturedBits, keptPositions] = apply_puncturing(motherBits, punctureMask)

period   = numel(punctureMask);                   % Puncturing period in mother bits.

numTiles = ceil(numel(motherBits) / period);      % Number of mask repetitions covering the stream.

fullMask = repmat(punctureMask(:), numTiles, 1);  % Tiled mask over the padded length.

fullMask = fullMask(1:numel(motherBits));         % Trim the tiled mask to the stream length.

keptPositions = find(fullMask);                   % Mother-stream positions that are transmitted.

puncturedBits = motherBits(keptPositions);        % Transmitted subset of the mother stream.

end
