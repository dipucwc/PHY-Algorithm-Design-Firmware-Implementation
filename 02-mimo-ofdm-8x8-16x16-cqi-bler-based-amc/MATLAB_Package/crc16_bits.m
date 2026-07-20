%{
=========================================================================================================================
 crc16_bits.m — CRC-16-CCITT remainder over a bit vector
=========================================================================================================================

The function computes the 16-bit cyclic-redundancy-check remainder of a binary column vector by long division with the
generator polynomial x^16 + x^12 + x^5 + 1 over GF(2) with an all-zero initial register. The same routine serves the
generator and the checker so that both sides of the link apply an identical polynomial division.
=========================================================================================================================
%}

function remainder = crc16_bits(bits, crcPolynomial)

register = [bits(:); zeros(numel(crcPolynomial)-1, 1)];  % Message bits followed by the zero-padded CRC field.

polyLen  = numel(crcPolynomial);                  % Length of the generator polynomial in bits.

for i = 1:numel(bits)                             % Divide the padded message by the generator polynomial.
    if register(i) == 1                           % A leading one triggers a polynomial subtraction.
        register(i:i+polyLen-1) = ...
            mod(register(i:i+polyLen-1) + crcPolynomial(:), 2);
    end
end

remainder = register(end-polyLen+2:end);          % The final 16 register bits are the CRC remainder.

end
