%{
=========================================================================================================================
 build_wiener_filter.m — Noise-dependent Wiener filter from the precomputed correlation matrices
=========================================================================================================================

The function builds the per-antenna Wiener filters at the current noise variance from the precomputed pilot-to-pilot
and all-to-pilot correlation matrices, exactly as the verified Project 1 platform does at every SNR point.
=========================================================================================================================
%}

function W = build_wiener_filter(link, cfg)

numPilots = cfg.Nfft / cfg.Nt;                    % Pilots per transmit antenna.

W = cell(cfg.Nt, 1);                              % One filter per transmit antenna.

for n = 1:cfg.Nt                                  % Regularized Wiener solution.
    W{n} = link.R_FP{n} / (link.R_PP{n} + link.noiseVar * eye(numPilots));
end

end
