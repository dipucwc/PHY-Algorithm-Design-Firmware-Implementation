/*
=========================================================================================================================
 *** rf_quality ***
 Receiver-side link-quality estimation: per-stream post-equalization SINR, the quality report, and the CQI.
=========================================================================================================================

 Description:
     This file implements the measurement chain that produces the channel-quality feedback of the closed loop. It
     contains the per-stream post-equalization SINR estimate computed from the estimated channel, the per-layer,
     per-candidate effective-SINR quality report, and the uncorrected channel-quality indicator (CQI) that the receiver
     feeds back. These three functions turn the raw channel estimate of a slot into the report on which the transmitter
     bases its modulation-and-coding decision.

     The complete procedure operates as follows. The SINR estimate reproduces, from the estimated channel alone, the
     conditions of the MMSE detector actually in use: at one subcarrier the regularized MMSE weight is formed, the
     weight-times-channel product is evaluated, and the per-stream SINR follows as the desired-stream power over the
     residual inter-stream power plus the enhanced noise power of the equalizer row, with the channel scaled for the
     transmit-power split across the antennas. The quality report then evaluates the effective-SINR mapping once per
     spatial layer and per candidate scheme: each layer carries one independent codeword, so the mapping runs over that
     layer's own subcarrier SINR profile with the calibration parameter of each candidate, which preserves the
     codeword-level meaning that a single slot-wide scalar cannot provide. The CQI is finally obtained by running the
     BLER-constrained selection on the report at zero outer-loop offset, so the fed-back indicator carries no
     transmitter-side correction; the full report travels through the feedback delay alongside it, and the transmitter
     reruns the selection with its own current offset at transmission time.

 Input / Output:
     Given per function below.

 Supporting files:
     header      rf_quality.h     (declares the three functions in this file)
     header      rf_complex.h     (complex type for the channel and weight matrices)
     header      rf_matrix_p2.h   (Gram matrix, matched filter, and solver reused from the equalizer algebra)
     header      rf_eesm.h        (effective-SINR mapping), rf_mcs.h (the zero-offset selection)
     reference   estimate_post_eq_sinr.m, estimate_quality_report.m, estimate_cqi.m
     calls       rf_eesm_eff_sinr_db (in rf_eesm.c), rf_mcs_select and rf_bler_interp (in rf_mcs.c)
=========================================================================================================================
*/
#include "rf_quality.h"
#include "rf_eesm.h"
#include <math.h>

/*
=========================================================================================================================
 *** solve_small ***
 Gauss-Jordan solve of one small complex system, private to this file.
=========================================================================================================================

 Description:
     This helper solves A x = b for the small Nt-by-Nt system by Gauss-Jordan elimination with partial pivoting. It is
     the same procedure as the solver of the Project 1 matrix module, kept private here so that this file stays
     self-contained. The elimination reduces the matrix to the identity column by column while applying every operation
     to the right-hand side, which then holds the solution.

 Input:
     A    System matrix, Nt by Nt, stored row by row (modified in place).
     b    Right-hand side, length Nt (modified in place).
     Nt   System size.

 Output:
     x    Solution vector, length Nt (caller-allocated).
     return value   Zero on success, one if the matrix is singular.
=========================================================================================================================
*/
static cplx_t cxq_div(cplx_t a, cplx_t b)
{
    double d = cx_abs2(b);                            /* Denominator magnitude squared. */
    if (d < 1e-300) d = 1e-300;                       /* Protect against division by zero. */
    return cx((a.re * b.re + a.im * b.im) / d,        /* Real part of a times conj(b), scaled. */
              (a.im * b.re - a.re * b.im) / d);       /* Imaginary part, scaled. */
}

static int solve_small(cplx_t *A, cplx_t *b, size_t Nt, cplx_t *x)
{
    for (size_t col = 0; col < Nt; ++col) {           /* Eliminate one column at a time. */

        size_t piv = col;                             /* Choose the largest pivot for stability. */
        double best = cx_abs2(A[col * Nt + col]);
        for (size_t r = col + 1; r < Nt; ++r) {
            double v = cx_abs2(A[r * Nt + col]);
            if (v > best) { best = v; piv = r; }
        }
        if (best < 1e-300) return 1;                  /* Singular matrix. */

        if (piv != col) {                             /* Exchange the pivot row into place. */
            for (size_t c = 0; c < Nt; ++c) {
                cplx_t t = A[col * Nt + c]; A[col * Nt + c] = A[piv * Nt + c]; A[piv * Nt + c] = t;
            }
            cplx_t tb = b[col]; b[col] = b[piv]; b[piv] = tb;
        }

        cplx_t pv = A[col * Nt + col];                /* Normalize the pivot row. */
        for (size_t c = 0; c < Nt; ++c) A[col * Nt + c] = cxq_div(A[col * Nt + c], pv);
        b[col] = cxq_div(b[col], pv);

        for (size_t r = 0; r < Nt; ++r) {             /* Eliminate the column from the other rows. */
            if (r == col) continue;
            cplx_t f = A[r * Nt + col];
            for (size_t c = 0; c < Nt; ++c)
                A[r * Nt + c] = cx_sub(A[r * Nt + c], cx_mul(f, A[col * Nt + c]));
            b[r] = cx_sub(b[r], cx_mul(f, b[col]));
        }
    }

    for (size_t i = 0; i < Nt; ++i) x[i] = b[i];      /* The transformed right-hand side is the solution. */
    return 0;
}

/*
=========================================================================================================================
 *** rf_post_eq_sinr ***
 Per-stream post-equalization SINR at one subcarrier from the estimated channel.
=========================================================================================================================

 Description:
     This function computes the SINR that every spatial stream experiences at the output of the MMSE detector, using
     only the estimated channel, the noise variance, and the symbol energy, exactly as a practical receiver must. The
     complete procedure runs in three steps. In the first step, the estimated channel is scaled by one over the square
     root of the transmit-antenna count, which accounts for the equal power split across the antennas, and the
     regularized weight W = inverse(H^H H + noiseVar I) H^H is formed; the inverse is obtained column by column from
     the shared solver, and the weight rows are the same rows the detector applies, so the estimate describes the
     detector actually in use. In the second step, the weight-times-channel product G = W H is evaluated. In the third
     step, the SINR of stream l follows as the desired-stream power |G(l,l)|^2 Es over the residual inter-stream power
     (the remaining squared entries of row l times Es) plus the enhanced noise power of the equalizer row,
     ||w_l||^2 noiseVar, with the denominator floored to avoid division by zero.

 Input:
     Hest       Estimated channel at the subcarrier, Nr by Nt, row by row (unscaled).
     Nr         Number of receive antennas.
     Nt         Number of transmit antennas (spatial streams).
     noiseVar   Receiver-noise variance.
     Es         Transmitted symbol energy.

 Output:
     sinr_lin   Per-stream linear SINR estimate, length Nt (caller-allocated).
     return value   Zero on success, one if the weight system is singular.
=========================================================================================================================
*/
int rf_post_eq_sinr(const cplx_t *Hest, size_t Nr, size_t Nt,
                    double noiseVar, double Es, double *sinr_lin)
{
    cplx_t H[RF_QMAX_ANT * RF_QMAX_ANT];              /* The scaled channel. */
    cplx_t A[RF_QMAX_ANT * RF_QMAX_ANT];              /* The regularized system matrix. */
    cplx_t b[RF_QMAX_ANT], zc[RF_QMAX_ANT];           /* Solve vectors. */
    cplx_t Ainv[RF_QMAX_ANT * RF_QMAX_ANT];           /* The inverse, built column by column. */
    cplx_t W[RF_QMAX_ANT * RF_QMAX_ANT];              /* The MMSE weight, Nt by Nr. */
    cplx_t G[RF_QMAX_ANT * RF_QMAX_ANT];              /* The weight-times-channel product, Nt by Nt. */

    /* Step 1a: scale the channel for the transmit-power split. */
    double scale = 1.0 / sqrt((double)Nt);            /* One over the square root of the antenna count. */
    for (size_t i = 0; i < Nr * Nt; ++i)              /* Scale every entry. */
        H[i] = cx(Hest[i].re * scale, Hest[i].im * scale);

    /* Step 1b: build A = H^H H + noiseVar I. */
    for (size_t i = 0; i < Nt; ++i) {                 /* Entry (i, j) of the Gram matrix. */
        for (size_t j = 0; j < Nt; ++j) {
            cplx_t acc = cx(0.0, 0.0);
            for (size_t m = 0; m < Nr; ++m)           /* Inner product of channel columns i and j. */
                acc = cx_add(acc, cx_mul(cx_conj(H[m * Nt + i]), H[m * Nt + j]));
            if (i == j) acc.re += noiseVar;           /* Regularization on the diagonal. */
            A[i * Nt + j] = acc;
        }
    }

    /* Step 1c: invert A column by column with the shared solver. */
    for (size_t c = 0; c < Nt; ++c) {                 /* One unit vector per column. */
        cplx_t Awork[RF_QMAX_ANT * RF_QMAX_ANT];      /* The solver modifies its input. */
        for (size_t i = 0; i < Nt * Nt; ++i) Awork[i] = A[i];
        for (size_t k = 0; k < Nt; ++k) b[k] = cx(k == c ? 1.0 : 0.0, 0.0);
        if (solve_small(Awork, b, Nt, zc)) return 1;  /* Column c of the inverse. */
        for (size_t r = 0; r < Nt; ++r) Ainv[r * Nt + c] = zc[r];
    }

    /* Step 1d: W = Ainv * H^H (Nt by Nr). */
    for (size_t l = 0; l < Nt; ++l) {                 /* Row l of the weight. */
        for (size_t m = 0; m < Nr; ++m) {             /* Column m over the receive antennas. */
            cplx_t acc = cx(0.0, 0.0);
            for (size_t j = 0; j < Nt; ++j)           /* Ainv row l times conj(H) column m. */
                acc = cx_add(acc, cx_mul(Ainv[l * Nt + j], cx_conj(H[m * Nt + j])));
            W[l * Nr + m] = acc;
        }
    }

    /* Step 2: G = W * H (Nt by Nt). */
    for (size_t l = 0; l < Nt; ++l) {
        for (size_t j = 0; j < Nt; ++j) {
            cplx_t acc = cx(0.0, 0.0);
            for (size_t m = 0; m < Nr; ++m)           /* Weight row l times channel column j. */
                acc = cx_add(acc, cx_mul(W[l * Nr + m], H[m * Nt + j]));
            G[l * Nt + j] = acc;
        }
    }

    /* Step 3: the per-stream SINR from the rows of G and W. */
    for (size_t l = 0; l < Nt; ++l) {                 /* Evaluate every spatial stream. */
        double sig = cx_abs2(G[l * Nt + l]) * Es;     /* Desired-stream power at the equalizer output. */
        double intf = 0.0;                            /* Residual inter-stream power. */
        for (size_t j = 0; j < Nt; ++j)
            if (j != l) intf += cx_abs2(G[l * Nt + j]) * Es;
        double npow = 0.0;                            /* Enhanced noise power of the equalizer row. */
        for (size_t m = 0; m < Nr; ++m) npow += cx_abs2(W[l * Nr + m]);
        npow *= noiseVar;
        double den = intf + npow;                     /* The combined disturbance. */
        if (den < 1e-12) den = 1e-12;                 /* Floor the denominator. */
        sinr_lin[l] = sig / den;                      /* The per-stream SINR estimate. */
    }

    return 0;                                          /* Success. */
}

/*
=========================================================================================================================
 *** rf_quality_report ***
 Per-layer, per-candidate effective-SINR quality report of one slot.
=========================================================================================================================

 Description:
     This function builds the uncorrected quality report: one effective SINR in decibels per spatial layer and per
     candidate scheme. Each layer carries one independent codeword, so for every layer the subcarrier SINR profile of
     that layer alone is passed to the effective-SINR mapping, and the mapping is evaluated once per candidate with
     that candidate's calibration parameter. The report carries no outer-loop correction; the transmitter applies its
     own current offset when it reruns the selection after the feedback delay.

 Input:
     sinr_lin   Per-layer, per-subcarrier linear SINR, Nt rows by Nfft columns, row by row.
     nt         Number of spatial layers.
     nfft       Number of subcarriers per layer profile.

 Output:
     report     Nt-by-nine effective SINR in decibels, Q16.16, row by row (caller-allocated).
=========================================================================================================================
*/
void rf_quality_report(const double *sinr_lin, size_t nt, size_t nfft, q16_t *report)
{
    static q16_t layer_q[4096];                       /* One layer's profile converted to Q16.16. */

    for (size_t l = 0; l < nt; ++l) {                 /* Evaluate every layer codeword separately. */

        for (size_t k = 0; k < nfft; ++k)             /* Convert the layer's profile to fixed point. */
            layer_q[k] = rf_double_to_q16(sinr_lin[l * nfft + k]);

        for (int m = 0; m < RF_NUM_MCS; ++m)          /* One mapping per candidate, with its own beta. */
            report[l * (size_t)RF_NUM_MCS + (size_t)m] =
                rf_eesm_eff_sinr_db(layer_q, nfft, RF_EESM_BETA_Q16[m]);
    }
}

/*
=========================================================================================================================
 *** rf_estimate_cqi ***
 Receiver-side uncorrected CQI from the quality report.
=========================================================================================================================

 Description:
     This function produces the channel-quality indicator the receiver feeds back. The quality report of the slot is
     built first, and the BLER-constrained selection is then run on that report at zero outer-loop offset, so the
     indicator carries no transmitter-side correction. The report itself is returned alongside the integer indicator,
     because the feedback carries the full report and the transmitter reruns the selection with its own current offset;
     the integer value serves the logging and the convergence traces. As in the reference, the indicator and the scheme
     index share the same nine-entry scale.

 Input:
     sinr_lin   Per-layer, per-subcarrier linear SINR, Nt rows by Nfft columns.
     nt         Number of spatial layers.
     nfft       Number of subcarriers per layer profile.
     curves     Calibrated error curve of each candidate scheme.
     target     The block-error-rate target, Q16.16.

 Output:
     report     The Nt-by-nine quality report, Q16.16 (caller-allocated).
     return value   The uncorrected CQI (the zero-offset selection result), zero to eight.
=========================================================================================================================
*/
int rf_estimate_cqi(const double *sinr_lin, size_t nt, size_t nfft,
                    const rf_bler_curve_t curves[RF_NUM_MCS], q16_t target, q16_t *report)
{
    rf_quality_report(sinr_lin, nt, nfft, report);    /* Build the uncorrected report. */

    q16_t crit; rf_sel_status_t st;                   /* Selection outputs (indicator only needs the index). */
    return rf_mcs_select(report, nt, curves, target, 0, RF_CRIT_MEAN, &crit, &st);  /* Zero-offset selection. */
}
