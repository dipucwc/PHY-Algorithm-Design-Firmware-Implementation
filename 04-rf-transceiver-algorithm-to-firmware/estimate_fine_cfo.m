
%% *** estimate_fine_cfo ***:
%% Fine carrier-offset estimation from pilot phase drift:
%{
The function estimates the residual carrier frequency offset that remains after coarse compensation. A residual offset adds
a fixed phase rotation from one OFDM symbol to the next. The rotation is measured from the pilot subcarriers of two
consecutive data symbols. With unit pilots the pilot channel estimate equals the received pilot, so the phase of the pilot
inter-symbol correlation gives the per-symbol rotation, which is converted back to a normalized offset. The estimate is zero
when the received signal is too short to hold two data symbols.

Input:

    rxCoarse      Coarse-compensated received signal.
    preambleLen   Total preamble length in samples.
    symbolLen     OFDM symbol length including the cyclic prefix.
    Nfft          FFT size.
    pilotIdx      Pilot subcarrier indices.

Output:

    eps_fine   Fine carrier-offset estimate in subcarrier spacings.
%}

function eps_fine = estimate_fine_cfo(rxCoarse, preambleLen, symbolLen, Nfft, pilotIdx)


%% Symbol positions:
%%

eps_fine = 0;                                     % Default estimate when the signal is too short.

cpLen = symbolLen - Nfft;                         % Cyclic prefix length recovered from the symbol length.

sym1_body = preambleLen + cpLen + 1;              % Body start of the first data symbol.

sym2_body = sym1_body + symbolLen;                % Body start of the second data symbol.


%% Pilot phase drift:
%%

if sym2_body + Nfft - 1 <= length(rxCoarse)       % Proceed only when two full data symbols are available.

    Y1 = fft(rxCoarse(sym1_body : sym1_body+Nfft-1), Nfft);  % Frequency-domain first data symbol.

    Y2 = fft(rxCoarse(sym2_body : sym2_body+Nfft-1), Nfft);  % Frequency-domain second data symbol.

    H1p = Y1(pilotIdx);                           % Pilot observations from the first symbol.

    H2p = Y2(pilotIdx);                           % Pilot observations from the second symbol.

    delta_phi = angle(sum(H2p .* conj(H1p)));     % Per-symbol phase rotation from the pilot correlation.

    eps_fine  = delta_phi * Nfft / (2*pi*symbolLen);  % Convert the rotation to a normalized offset.

end

end
