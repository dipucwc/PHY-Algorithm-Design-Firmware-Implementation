
%% *** estimate_coarse_cfo ***:
%% Coarse carrier-offset estimation from the preamble autocorrelation:
%{
The function estimates the coarse carrier frequency offset from the phase of the Schmidl-Cox autocorrelation at the detected
timing position. The half-symbol repetition maps a phase of pi times the normalized offset onto the autocorrelation, so the
estimate is the autocorrelation angle divided by pi. The unambiguous range is one subcarrier spacing in each direction.

Input:

    M_sc    Complex autocorrelation vector from schmidl_cox_metric.
    d_hat   Detected timing position.

Output:

    eps_coarse   Coarse carrier-offset estimate in subcarrier spacings.
%}

function eps_coarse = estimate_coarse_cfo(M_sc, d_hat)


%% Coarse estimate:
%%

eps_coarse = angle(M_sc(d_hat)) / pi;             % Convert the autocorrelation phase to a normalized offset.

end
