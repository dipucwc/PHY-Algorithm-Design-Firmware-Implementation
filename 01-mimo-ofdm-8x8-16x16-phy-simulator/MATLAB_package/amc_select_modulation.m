
%% *** amc_select_modulation ***:
%% Adaptive modulation selection:
%{
The function selects the QAM modulation order from the operating SNR. It applies fixed SNR thresholds that map low SNR to
QPSK, mid SNR to sixteen-QAM, and high SNR to sixty-four-QAM. The thresholds are matched to the TDL-A channel with the
rate-1/2 convolutional code used in the simulation.

Input:

    SNRdB   Operating SNR in decibels.

Output:

    M            QAM modulation order.
    modName      Modulation name.
    bitsPerSym   Bits per QAM symbol.
%}

function [M, modName, bitsPerSym] = amc_select_modulation(SNRdB)

% This function performs threshold-based modulation-order selection.
% The convolutional-code rate remains fixed at 1/2.
% It is not a full CQI-to-MCS adaptive coding implementation.



%% Threshold selection:
%%

if SNRdB < 8                                      % Low SNR uses QPSK.
    M = 4;   modName = "QPSK";   bitsPerSym = 2;
elseif SNRdB < 18                                 % Mid SNR uses sixteen-QAM.
    M = 16;  modName = "16-QAM"; bitsPerSym = 4;
else                                              % High SNR uses sixty-four-QAM.
    M = 64;  modName = "64-QAM"; bitsPerSym = 6;
end

end
