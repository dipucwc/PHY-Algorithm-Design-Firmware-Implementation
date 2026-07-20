
%% *** demod_ofdm_symbol ***:
%% Single-antenna OFDM demodulation:
%{
The function demodulates the single-antenna data OFDM symbols. For each symbol it removes the cyclic prefix, transforms the
body to the frequency domain, forms a least-squares channel estimate at the pilot subcarriers, interpolates the estimate to
all subcarriers, equalizes with a single-carrier zero-forcing division, and demodulates the data subcarriers. It also
returns the RMS error vector magnitude against the reference symbols.

Input:

    rxVec       Received signal vector.
    dataStart   First sample index of the first data symbol.
    numSyms     Number of data OFDM symbols to process.
    Nfft        FFT size.
    cpLen       Cyclic prefix length.
    pilotIdx    Pilot subcarrier indices.
    dataIdx     Data subcarrier indices.
    M           QAM modulation order.
    txQAM       Reference transmitted QAM symbols used for the error vector magnitude.

Output:

    rxBits    Demodulated bit stream.
    evm_rms   RMS error vector magnitude as a linear fraction.
    rxSyms    Equalized QAM symbols at the data subcarriers.
%}

function [rxBits, evm_rms, rxSyms] = demod_ofdm_symbol(rxVec, dataStart, numSyms, ...
    Nfft, cpLen, pilotIdx, dataIdx, M, txQAM)


%% Output preallocation:
%%

symbolLen = Nfft + cpLen;                         % OFDM symbol length including the cyclic prefix.

nD        = length(dataIdx);                      % Number of data subcarriers.

rxBits    = zeros(nD * log2(M) * numSyms, 1);     % Preallocate the demodulated bit stream.

rxSyms    = zeros(nD * numSyms, 1);               % Preallocate the equalized symbol vector.


%% Per-symbol demodulation:
%%

ptr = 1;                                          % Write pointer into the bit stream.

for s = 1:numSyms                                 % Process each data OFDM symbol.

    bodyStart = dataStart + (s-1)*symbolLen + cpLen;  % First body sample of the current symbol.

    bodyEnd   = bodyStart + Nfft - 1;             % Last body sample of the current symbol.

    if bodyEnd > length(rxVec)                    % Stop when the received signal is exhausted.
        break;
    end

    Y = fft(rxVec(bodyStart:bodyEnd), Nfft);      % Transform the symbol body to the frequency domain.

    H_pilots = Y(pilotIdx);                       % Least-squares estimate at the pilot subcarriers.

    H_full = interp1(double(pilotIdx), H_pilots, ...  % Interpolate the estimate to all subcarriers.
        (1:Nfft).', 'linear', 'extrap');

    Yeq = Y ./ H_full;                            % Apply the single-carrier zero-forcing equalizer.

    nB = nD * log2(M);                            % Number of bits produced by this symbol.

    rxBits(ptr:ptr+nB-1) = qamdemod(Yeq(dataIdx), M, ...  % Demodulate the data subcarriers.
        'OutputType', 'bit', 'UnitAveragePower', true);

    rxSyms((s-1)*nD+1:s*nD) = Yeq(dataIdx);       % Store the equalized data symbols.

    ptr = ptr + nB;                               % Advance the write pointer.

end

rxBits = rxBits(1:ptr-1);                         % Trim the bit stream to the processed length.


%% Error vector magnitude:
%%

numSym = length(rxSyms);                          % Number of equalized symbols.

if nargin >= 9 && ~isempty(txQAM) && numSym > 0   % Compute the metric only when a reference is available.
    refSym  = txQAM(1:numSym);                    % Reference symbols aligned to the equalized symbols.
    evm_rms = sqrt(mean(abs(refSym - rxSyms).^2) / ...  % RMS error vector magnitude as a linear fraction.
        max(mean(abs(refSym).^2), 1e-12));
else
    evm_rms = 0;                                  % Return zero when no reference is supplied.
end

end
