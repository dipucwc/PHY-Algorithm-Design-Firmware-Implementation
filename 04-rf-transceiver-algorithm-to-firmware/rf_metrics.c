/*
=========================================================================================================================
 *** rf_metrics ***
 Link-quality metrics and threshold modulation selection.
=========================================================================================================================

 Description:
     This file implements the link-quality measurements and the threshold-based modulation selection of the baseline
     receiver. It contains the post-equalization SINR, the error vector magnitude, and the SNR-threshold rule for the
     QAM order.

     The complete procedure operates as follows. The SINR treats the known transmitted symbols as the reference signal and the difference between reference and
     equalized symbols as the combined interference and noise; the ratio of the two average powers, expressed in
     decibels, measures how well the detector separated the spatial streams. The EVM expresses the same error as a
     normalized root-mean-square percentage, which is the form reported by laboratory instruments. The modulation
     selection implements the open-loop rule of the baseline project: fixed SNR thresholds at 8 and 18 dB assign QPSK,
     16-QAM, or 64-QAM, with the coding rate held constant. This rule is the reference point that the closed-loop
     CQI-based adaptation of the second project replaces.

 Input / Output:
     Given per function below.

 Supporting files:
     header      rf_metrics.h     (declares the three functions in this file)
     header      rf_complex.h     (complex type and magnitude helpers)
     reference   compute_sinr.m, compute_evm.m, amc_select_modulation.m
     calls       none (uses only the inline helpers in rf_complex.h and the C math library)
=========================================================================================================================
*/
#include "rf_metrics.h"
#include <math.h>

/*
=========================================================================================================================
 *** rf_compute_sinr_db ***
 Post-equalization SINR in decibels.
=========================================================================================================================

 Description:
     This function computes the post-equalization SINR in decibels. The average power of the reference symbols and the
     average power of the error between reference and equalized symbols are accumulated over the symbol set, and the
     SINR is ten times the base-ten logarithm of their ratio.

 Input:
     tx   Reference transmitted symbols.
     rx   Equalized received symbols.
     n    Number of symbols to compare.

 Output:
     return value   SINR in decibels.
=========================================================================================================================
*/
double rf_compute_sinr_db(const cplx_t *tx, const cplx_t *rx, size_t n)
{
    if (n == 0) return 0.0;                           /* Nothing to measure. */

    double sig = 0.0, err = 0.0;                      /* Signal power and error power. */
    for (size_t i = 0; i < n; ++i) {                  /* Add up over all the symbols. */
        sig += cx_abs2(tx[i]);                        /* Power of the ideal signal. */
        err += cx_abs2(cx_sub(tx[i], rx[i]));         /* Power of the error (how far off we were). */
    }
    sig /= (double)n;                                 /* Average signal power. */
    err /= (double)n;                                 /* Average error power. */
    if (err < 1e-12) err = 1e-12;                     /* Guard the ratio. */

    return 10.0 * log10(sig / err);                   /* Ratio, in decibels. */
}

/*
=========================================================================================================================
 *** rf_compute_evm_pct ***
 RMS error vector magnitude in percent.
=========================================================================================================================

 Description:
     This function computes the root-mean-square error vector magnitude as a percentage. The mean squared error between
     reference and received symbols is normalized by the mean reference power, and the square root of the ratio is
     scaled to percent.

 Input:
     tx   Reference transmitted symbols.
     rx   Received or equalized symbols.
     n    Number of symbols to compare.

 Output:
     return value   RMS error vector magnitude in percent.
=========================================================================================================================
*/
double rf_compute_evm_pct(const cplx_t *tx, const cplx_t *rx, size_t n)
{
    if (n == 0) return 0.0;                           /* Nothing to measure. */

    double err = 0.0, ref = 0.0;                      /* Error power and reference power. */
    for (size_t i = 0; i < n; ++i) {                  /* Add up over all the symbols. */
        err += cx_abs2(cx_sub(tx[i], rx[i]));         /* How far off this symbol was. */
        ref += cx_abs2(tx[i]);                        /* Power of the ideal symbol. */
    }
    err /= (double)n;                                 /* Average error power. */
    ref /= (double)n;                                 /* Average reference power. */
    if (ref < 1e-12) ref = 1e-12;                     /* Guard the ratio. */

    return sqrt(err / ref) * 100.0;                   /* Root of the ratio, as a percentage. */
}

/*
=========================================================================================================================
 *** rf_amc_select_modulation ***
 Threshold-based modulation-order selection (the open-loop Project 1 rule).
=========================================================================================================================

 Description:
     This function implements the threshold-based modulation selection of the baseline project. The operating SNR is
     compared against fixed thresholds: below 8 dB the selection is QPSK, from 8 dB to below 18 dB it is 16-QAM, and
     from 18 dB it is 64-QAM. The coding rate remains fixed at one half. The rule is open-loop, because it never
     observes the receiver measurements; that limitation motivates the closed-loop design of the second project.

 Input:
     snr_db         Operating SNR in decibels.

 Output:
     bits_per_sym   Set to the bits per QAM symbol (two, four, or six).
     return value   QAM order (four, sixteen, or sixty-four).
=========================================================================================================================
*/
int rf_amc_select_modulation(double snr_db, int *bits_per_sym)
{
    if (snr_db < 8.0) {                               /* Weak link: keep it robust. */
        *bits_per_sym = 2;                            /* QPSK carries two bits per symbol. */
        return 4;
    } else if (snr_db < 18.0) {                       /* Middling link. */
        *bits_per_sym = 4;                            /* 16-QAM carries four. */
        return 16;
    } else {                                          /* Strong link: push throughput. */
        *bits_per_sym = 6;                            /* 64-QAM carries six. */
        return 64;
    }
}
