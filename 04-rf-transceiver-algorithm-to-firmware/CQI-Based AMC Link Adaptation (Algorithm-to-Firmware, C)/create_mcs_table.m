%{
=========================================================================================================================
 create_mcs_table.m — Simplified research MCS table for Project 2
=========================================================================================================================

The function returns the simplified research MCS table used by the CQI-based link adaptation. Nine entries combine the
three QAM orders of the Project 1 platform with three convolutional coding rates obtained by puncturing the rate-1/2
mother code. The nominal spectral efficiency column is the product of bits per symbol and coding rate and increases
monotonically with the MCS index. This is a custom research table, not a standardized 3GPP MCS table.
=========================================================================================================================
%}

function mcsTable = create_mcs_table()

mcsTable = table( ...
    (0:8).', ...                                  % MCS index.
    [4; 4; 4; 16; 16; 16; 64; 64; 64], ...        % Modulation order.
    [2; 2; 2; 4; 4; 4; 6; 6; 6], ...              % Bits per QAM symbol.
    [1/2; 2/3; 3/4; 1/2; 2/3; 3/4; 1/2; 2/3; 3/4], ...  % Coding rate after puncturing.
    'VariableNames', {'McsIndex', 'ModulationOrder', 'BitsPerSymbol', 'CodeRate'});

mcsTable.NominalSpectralEfficiency = ...          % Nominal information bits per QAM symbol.
    mcsTable.BitsPerSymbol .* mcsTable.CodeRate;

end
