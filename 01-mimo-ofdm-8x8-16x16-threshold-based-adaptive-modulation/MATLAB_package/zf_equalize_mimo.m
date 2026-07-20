
%% *** zf_equalize_mimo ***:
%% Zero-forcing MIMO equalization at one subcarrier:
%{
The function recovers the transmit symbols at one subcarrier with the zero-forcing equalizer. It applies the Moore-Penrose
pseudo-inverse of the channel matrix to the received vector, which removes the inter-stream interference at the cost of noise
enhancement on weak subcarriers. The pseudo-inverse also handles rank-deficient channel matrices.

Input:

    H_k   Channel matrix at the subcarrier sized receive by transmit.
    y_k   Received signal vector at the subcarrier.

Output:

    x_hat   Recovered transmit symbol vector.
%}

function x_hat = zf_equalize_mimo(H_k, y_k)


%% Zero-forcing solution:
%%

x_hat = pinv(H_k) * y_k;                          % Apply the pseudo-inverse to the received vector.

end
