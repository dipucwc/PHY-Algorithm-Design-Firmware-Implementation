
%% *** interp_snr_at_ber ***:
%% SNR at a target BER by interpolation on the logarithmic axis:
%{
The function returns the SNR at which a BER curve crosses a target value. It searches the curve for the first segment that
brackets the target and interpolates on the logarithmic BER axis. It returns not-a-number when the curve does not cross the
target within the swept SNR range.

Input:

    snrList     Vector of SNR points in decibels.
    berCurve    BER values aligned with the SNR points.
    targetBER   Target BER used for the crossing.

Output:

    snrAtBer   Interpolated SNR at the target BER, or not-a-number when the target is not reached.
%}

function snrAtBer = interp_snr_at_ber(snrList, berCurve, targetBER)


%% Segment search:
%%

snrAtBer = NaN;                                   % Default when the target is not bracketed.

for i = 1:length(snrList)-1                       % Search each SNR segment for a crossing of the target.

    b1 = berCurve(i);                             % BER at the lower SNR of the segment.

    b2 = berCurve(i+1);                           % BER at the upper SNR of the segment.

    if b1 >= targetBER && b2 <= targetBER && b1 > 0 && b2 > 0   % Test whether the segment brackets the target.
        w = (log10(b1) - log10(targetBER)) / (log10(b1) - log10(b2));  % Interpolation weight on the log axis.
        snrAtBer = snrList(i) + w * (snrList(i+1) - snrList(i));        % Interpolated crossing SNR.
        return;
    end

end

end
