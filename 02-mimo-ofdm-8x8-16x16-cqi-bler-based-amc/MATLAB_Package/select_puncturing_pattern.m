%{
=========================================================================================================================
 select_puncturing_pattern.m — Puncturing mask for a requested coding rate
=========================================================================================================================

The function returns the periodic puncturing mask that converts the rate-1/2 mother convolutional code into the
requested coding rate. The masks are the standard patterns for the constraint-length-7 code: the rate-2/3 mask keeps
three of every four mother bits and the rate-3/4 mask keeps four of every six. The mask is a logical column vector
over one mother-code period, ones marking transmitted positions and zeros marking punctured positions.
=========================================================================================================================
%}

function punctureMask = select_puncturing_pattern(codeRate)

if abs(codeRate - 1/2) < 1e-9                     % Rate 1/2: no puncturing.
    punctureMask = true(2, 1);

elseif abs(codeRate - 2/3) < 1e-9                 % Rate 2/3: standard mask [1 1; 1 0] read column-wise.
    punctureMask = logical([1; 1; 1; 0]);

elseif abs(codeRate - 3/4) < 1e-9                 % Rate 3/4: standard mask [1 1 0; 1 0 1] read column-wise.
    punctureMask = logical([1; 1; 1; 0; 0; 1]);

else
    error('Unsupported coding rate %.4f', codeRate);
end

end
