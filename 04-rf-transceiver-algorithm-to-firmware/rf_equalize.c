/*
=========================================================================================================================
 *** rf_equalize ***
 Zero-forcing and MMSE MIMO equalization at one subcarrier.
=========================================================================================================================

 Description:
     This file implements the linear MIMO detectors of the receiver: zero-forcing equalization, MMSE equalization, and
     the soft-output MMSE variant, all at one subcarrier. Each detector recovers the transmitted symbol vector from the
     received vector and the channel estimate, and the soft-output variant additionally supplies the unbiased estimate
     and the per-stream effective noise variance that the soft-decision decoder consumes.

     The complete procedure operates as follows. The two plain detectors differ only in the regularization of the
     system they solve. Zero-forcing solves
     (H^H H) x = H^H y, which removes the inter-stream interference completely but amplifies noise where the channel is
     weak or poorly conditioned. MMSE solves (H^H H + noiseVar I) x = H^H y; the noise-variance term on the diagonal
     limits the noise amplification at the cost of a small residual interference, and as the SNR increases the term
     vanishes and the MMSE solution converges to the zero-forcing solution. Both detectors obtain their solution through
     the shared machinery of rf_matrix: the Gram matrix, the matched filter, and the direct solver.

 Input / Output:
     Given per function below.

 Supporting files:
     header      rf_equalize.h    (declares the two functions in this file)
     header      rf_matrix.h      (Gram matrix, matched filter, and linear solve)
     header      rf_complex.h     (complex type, used through rf_matrix)
     reference   zf_equalize_mimo.m, mmse_equalize_mimo.m
     calls       rf_gram_plus_reg, rf_matched_filter, rf_solve (all in rf_matrix.c)
=========================================================================================================================
*/
#include "rf_equalize.h"
#include "rf_matrix.h"

/*
=========================================================================================================================
 *** rf_zf_equalize ***
 Zero-forcing detection at one subcarrier.
=========================================================================================================================

 Description:
     This function performs zero-forcing detection at one subcarrier. The Gram matrix is built without regularization,
     the matched filter is formed, and the system (H^H H) x = H^H y is solved. For a full-rank channel this solution
     equals the pseudo-inverse applied by the MATLAB reference.

 Input:
     H       Channel matrix, receive by transmit, stored row by row.
     Nr      Number of receive antennas.
     Nt      Number of transmit antennas.
     y       Received vector, length Nr.

 Output:
     x_hat   Recovered transmit-symbol vector, length Nt (caller-allocated).
     return value   Zero on success, one if the channel is singular.
=========================================================================================================================
*/
int rf_zf_equalize(const cplx_t *H, size_t Nr, size_t Nt, const cplx_t *y, cplx_t *x_hat)
{
    cplx_t G[RF_MAX_ANT * RF_MAX_ANT];                /* Will hold H^H H. */
    cplx_t b[RF_MAX_ANT];                             /* Will hold H^H y. */

    rf_gram_plus_reg(H, Nr, Nt, 0.0, G);             /* No noise term: this is zero-forcing. */
    rf_matched_filter(H, Nr, Nt, y, b);              /* Build the right-hand side. */

    return rf_solve(G, b, Nt, x_hat);                /* Solve for the transmitted symbols. */
}

/*
=========================================================================================================================
 *** rf_mmse_equalize ***
 MMSE detection at one subcarrier.
=========================================================================================================================

 Description:
     This function performs MMSE detection at one subcarrier. The Gram matrix is built with the noise variance added on
     the diagonal, the matched filter is formed, and the system (H^H H + noiseVar I) x = H^H y is solved. The noise
     variance equals the reciprocal of the linear SNR, and the added term suppresses the noise amplification that
     zero-forcing exhibits on weak subcarriers.

 Input:
     H          Channel matrix, receive by transmit, stored row by row.
     Nr         Number of receive antennas.
     Nt         Number of transmit antennas.
     y          Received vector, length Nr.
     noiseVar   Noise variance, equal to one over the linear SNR.

 Output:
     x_hat      Recovered transmit-symbol vector, length Nt (caller-allocated).
     return value   Zero on success, one if the system is singular.
=========================================================================================================================
*/
int rf_mmse_equalize(const cplx_t *H, size_t Nr, size_t Nt, const cplx_t *y,
                     double noiseVar, cplx_t *x_hat)
{
    cplx_t G[RF_MAX_ANT * RF_MAX_ANT];               /* Will hold H^H H plus the noise term. */
    cplx_t b[RF_MAX_ANT];                            /* Will hold H^H y. */

    rf_gram_plus_reg(H, Nr, Nt, noiseVar, G);        /* Add the noise variance on the diagonal. */
    rf_matched_filter(H, Nr, Nt, y, b);             /* Build the right-hand side. */

    return rf_solve(G, b, Nt, x_hat);                /* Solve for the transmitted symbols. */
}

/*
=========================================================================================================================
 *** rf_mmse_equalize_soft ***
 Soft-output MMSE detection at one subcarrier.
=========================================================================================================================

 Description:
     This function extends the MMSE detector with the quantities required for soft-decision decoding. The plain MMSE
     estimate is biased: the equalizer scales each stream by a gain smaller than one, and if the biased symbols were
     passed directly to the demapper, the log-likelihood ratios would be mis-scaled. The per-stream gain is the diagonal
     of the weight-times-channel product, and with A = H^H H + noiseVar I that product equals I - noiseVar * inverse(A),
     so each gain is obtained from one column of the inverse without forming the full weight matrix.

     The complete procedure runs in three steps. In the first step, the biased MMSE estimate is computed exactly as in
     the plain detector, by solving A x = H^H y. In the second step, the per-stream gain is computed: for each stream i,
     the system A z = e_i is solved, the diagonal entry of the inverse is read from z, and the gain follows as
     1 - noiseVar * z_i, floored to avoid division by a vanishing value. In the third step, the biased estimate of each
     stream is divided by its gain, which removes the bias, and the per-stream effective noise variance is formed as
     (1 - g) / g for unit signal power, floored likewise. The unbiased estimate and the effective noise variance are the
     pair that the hard demapper and the log-likelihood-ratio computation consume; the biased estimate is returned for
     reference analysis only.

 Input:
     H          Channel matrix, receive by transmit, stored row by row.
     Nr         Number of receive antennas.
     Nt         Number of transmit antennas.
     y          Received vector, length Nr.
     noiseVar   Noise variance, equal to one over the linear SNR.

 Output:
     x_biased   Biased MMSE estimate, length Nt (caller-allocated).
     x_soft     Gain-corrected unbiased estimate, length Nt (caller-allocated).
     nvar_eff   Per-stream effective noise variance, length Nt (caller-allocated).
     return value   Zero on success, one if the system is singular.
=========================================================================================================================
*/
int rf_mmse_equalize_soft(const cplx_t *H, size_t Nr, size_t Nt, const cplx_t *y,
                          double noiseVar, cplx_t *x_biased, cplx_t *x_soft, double *nvar_eff)
{
    cplx_t A[RF_MAX_ANT * RF_MAX_ANT];               /* The regularized system matrix, rebuilt per solve. */
    cplx_t b[RF_MAX_ANT];                            /* Right-hand side of each solve. */
    cplx_t z[RF_MAX_ANT];                            /* Solution of each solve. */

    /* Step 1: the biased estimate, from the same system as the plain MMSE detector. */
    rf_gram_plus_reg(H, Nr, Nt, noiseVar, A);        /* Build A = H^H H + noiseVar I. */
    rf_matched_filter(H, Nr, Nt, y, b);              /* Build H^H y. */
    if (rf_solve(A, b, Nt, x_biased)) return 1;      /* Solve for the biased estimate. */

    /* Step 2: the per-stream gain from the diagonal of I - noiseVar * inverse(A). */
    double g[RF_MAX_ANT];                            /* Per-stream gain. */
    for (size_t i = 0; i < Nt; ++i) {                /* One column of the inverse per stream. */
        rf_gram_plus_reg(H, Nr, Nt, noiseVar, A);    /* Rebuild A (the solver modifies it in place). */
        for (size_t k = 0; k < Nt; ++k) b[k] = cx(k == i ? 1.0 : 0.0, 0.0);  /* Unit vector e_i. */
        if (rf_solve(A, b, Nt, z)) return 1;         /* z is column i of the inverse. */
        g[i] = 1.0 - noiseVar * z[i].re;             /* Gain of stream i from the diagonal entry. */
        if (g[i] < 1e-6) g[i] = 1e-6;                /* Floor the gain, as the reference does. */
    }

    /* Step 3: remove the bias and form the effective noise variance per stream. */
    for (size_t i = 0; i < Nt; ++i) {                /* One stream at a time. */
        x_soft[i] = cx(x_biased[i].re / g[i], x_biased[i].im / g[i]);  /* Divide by the gain. */
        nvar_eff[i] = (1.0 - g[i]) / g[i];           /* Effective noise variance for unit signal power. */
        if (nvar_eff[i] < 1e-6) nvar_eff[i] = 1e-6;  /* Floor it, as the reference does. */
    }

    return 0;                                         /* Success. */
}
