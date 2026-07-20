%{
=========================================================================================================================
 check_crc.m — Verify the CRC-16 field of a received block
=========================================================================================================================

The function recomputes the CRC-16-CCITT division over the received information-plus-CRC block. The block passes only
when the remainder is exactly zero. Block-error statistics in Project 2 are defined solely by this check; no BER-based
approximation of block success is used anywhere.
=========================================================================================================================
%}

function [crcPass, infoBits] = check_crc(receivedBlock, crcLength, crcPolynomial)

infoBits  = receivedBlock(1:end-crcLength);       % Information bits of the received block.

remainder = crc16_bits(receivedBlock, crcPolynomial);  % Remainder over information plus CRC field.

crcPass   = all(remainder == 0);                  % The block passes only with a zero remainder.

end
