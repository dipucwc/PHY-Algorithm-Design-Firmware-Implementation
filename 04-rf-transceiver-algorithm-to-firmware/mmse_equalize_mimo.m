
%% *** mmse_equalize_mimo ***:
%% MMSE MIMO equalization at one subcarrier:
%{
The function recovers the transmit symbols at one subcarrier with the MMSE equalizer. The regularization term set by the
noise variance limits the noise enhancement that zero-forcing suffers on weak subcarriers. At high SNR the regularization
becomes small and the equalizer approaches zero-forcing, and at low SNR it suppresses noise at the cost of some residual
inter-stream interference.

Input:

    H_k        Channel matrix at the subcarrier sized receive by transmit.
    y_k        Received signal vector at the subcarrier.
    noiseVar   Noise variance equal to the inverse of the linear SNR.
    Nt         Number of transmit antennas.

Output:

    x_hat   Recovered transmit symbol vector.
%}

function x_hat = mmse_equalize_mimo(H_k, y_k, noiseVar, Nt)


%% MMSE solution:
%%

W_eq  = (H_k' * H_k + noiseVar * eye(Nt)) \ H_k'; % Build the regularized equalizer matrix.

x_hat = W_eq * y_k;                               % Apply the equalizer to the received vector.

end
