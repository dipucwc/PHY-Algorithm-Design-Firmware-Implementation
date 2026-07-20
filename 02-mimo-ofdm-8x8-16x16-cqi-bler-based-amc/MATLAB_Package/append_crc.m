%{
=========================================================================================================================
 append_crc.m — Attach the CRC-16 field to an information block
=========================================================================================================================

The function appends the CRC-16-CCITT remainder of the information bits to the block so that the receiver can verify
block delivery. A block is later declared successful only when the recomputed remainder over the received information
and CRC field is zero.
=========================================================================================================================
%}

function blockWithCrc = append_crc(infoBits, crcPolynomial)

crcField     = crc16_bits(infoBits, crcPolynomial);  % Compute the CRC remainder of the information bits.

blockWithCrc = [infoBits(:); crcField(:)];        % Concatenate the information bits and the CRC field.

end
