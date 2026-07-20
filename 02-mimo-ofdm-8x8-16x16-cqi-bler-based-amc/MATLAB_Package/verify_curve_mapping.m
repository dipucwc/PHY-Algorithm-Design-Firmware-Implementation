%{
=========================================================================================================================
 verify_curve_mapping.m — Guard that a calibration table belongs to the requested effective-SINR mapping
=========================================================================================================================

The function asserts that every row of a loaded calibration table carries the requested mapping label. Each online
controller must query the curves calibrated with its own mapping, because effective SINRs from different mappings are
not interchangeable quantities; the guard turns a silent axis mismatch into an immediate error.
=========================================================================================================================
%}

function verify_curve_mapping(blerCurves, mapping)

assert(ismember('Mapping', blerCurves.Properties.VariableNames), ...  % The table must carry the mapping label.
    'Calibration table has no Mapping column; regenerate the curves with generate_mcs_bler_curves.');

labels = unique(string(blerCurves.Mapping));      % Mapping labels present in the table.

assert(isscalar(labels) && labels == string(mapping), ...  % Exactly the requested mapping, nothing else.
    'Calibration table is labeled "%s" but the controller requested "%s".', strjoin(labels, ','), string(mapping));

end
