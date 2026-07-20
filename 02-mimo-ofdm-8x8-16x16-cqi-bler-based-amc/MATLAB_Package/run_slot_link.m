%{
=========================================================================================================================
 run_slot_link.m — One MIMO-OFDM slot at one MCS on a fixed channel and noise realization
=========================================================================================================================

The function transmits and receives one slot at the requested MCS on a realization prepared by prepare_slot_shared.
Because the channel matrices, the pilot noise, the data noise, the channel estimate, the equalizer weights, and the
receiver SINR estimate all live in the shared realization structure, every adaptation method evaluated on the same
slot experiences exactly the same channel and noise; only the transmitted payload differs. Each spatial layer carries
one CRC-protected variable-rate codeword, so one slot produces Nt block verdicts under one wideband MCS. The function
returns the per-layer CRC verdicts and the delivered-information accounting from which BLER and goodput are measured.
=========================================================================================================================
%}

function res = run_slot_link(shared, mcsRow, cfg, trellis, payloadStream)

Nt   = cfg.Nt;                                    % Number of spatial layers.

Nfft = cfg.Nfft;                                  % Number of subcarriers.

nSym = cfg.numDataSymbols;                        % Data OFDM symbols per slot.

bps  = mcsRow.BitsPerSymbol;                      % Bits per QAM symbol of the MCS.

M    = mcsRow.ModulationOrder;                    % Modulation order of the MCS.

containerBits = Nfft * nSym * bps;                % Channel bits of one per-layer codeword container.

numInfoBits   = floor(containerBits * mcsRow.CodeRate) ...  % Information bits per codeword after CRC and tail.
    - cfg.crcLength - cfg.tailBits;


%% Per-layer encoding:
%%

txGrid  = zeros(Nt, Nfft, nSym);                  % Transmit QAM grid.

infoTx  = cell(Nt, 1);                            % Transmitted information bits per layer.

cwMeta  = cell(Nt, 1);                            % Codeword bookkeeping per layer.

for l = 1:Nt                                      % Build one codeword per spatial layer.

    infoTx{l} = double(rand(payloadStream, numInfoBits, 1) > 0.5);  % Draw the payload from the method's stream.

    [txBits, cwMeta{l}] = encode_variable_rate( ...  % CRC, terminated encoding, puncturing, interleaving, padding.
        infoTx{l}, mcsRow.CodeRate, containerBits, trellis, cfg, ...
        cfg.randomSeed + 131*l + mcsRow.McsIndex);

    txQAM = qammod(txBits, M, 'InputType', 'bit', 'UnitAveragePower', true);  % Map to unit-power QAM symbols.

    txGrid(l,:,:) = reshape(txQAM, Nfft, nSym);   % Place the layer's symbols on the grid.

end


%% Reception on the shared realization:
%%

rxSoft = zeros(Nt, Nfft, nSym);                   % Common gain-corrected unbiased MMSE outputs.

for s = 1:nSym                                    % Receive every data OFDM symbol.
    for k = 1:Nfft                                % Receive every subcarrier.

        y_k = shared.Hd{s}(:,:,k) * txGrid(:,k,s) + shared.dataNoise(:,k,s);  % Shared channel and shared noise.

        xb  = shared.W(:,:,k) * y_k;              % Biased MMSE output from the shared weights.

        rxSoft(:,k,s) = xb ./ shared.g(:,k);      % Common gain-corrected unbiased stream.

    end
end


%% Per-layer soft demapping, decoding, and CRC:
%%

nvarGrid = repmat(shared.nvar, 1, 1, nSym);       % Effective noise variance replicated across the data symbols.

crcPass   = false(Nt, 1);                         % Per-layer CRC verdicts.

bitErrors = 0;                                    % Information-bit errors across the slot.

for l = 1:Nt                                      % Decode every layer codeword.

    layerSym  = reshape(rxSoft(l,:,:), [], 1);    % Received symbols of the layer.

    layerNvar = reshape(nvarGrid(l,:,:), [], 1);  % Matching effective noise variances.

    llr = qamdemod(layerSym, M, 'OutputType', 'approxllr', ...  % Per-bit log-likelihood ratios.
        'UnitAveragePower', true, 'NoiseVariance', layerNvar);

    [crcPass(l), infoHat] = decode_variable_rate(llr, cwMeta{l}, trellis, cfg);  % Decode and verify the CRC.

    bitErrors = bitErrors + sum(infoHat ~= infoTx{l});  % Accumulate information-bit errors.

end


%% Slot accounting:
%%

res.crcPass        = crcPass;                     % Per-layer CRC verdicts.

res.totalBlocks    = Nt;                          % Blocks transmitted in the slot.

res.failedBlocks   = sum(~crcPass);               % Blocks that failed the CRC.

res.numInfoBits    = numInfoBits;                 % Information bits per block.

res.totalInfoBits  = Nt * numInfoBits;            % Information bits offered by the slot.

res.deliveredBits  = sum(crcPass) * numInfoBits;  % Information bits delivered by CRC-passing blocks.

res.bitErrors      = bitErrors;                   % Information-bit errors of the slot.

end
