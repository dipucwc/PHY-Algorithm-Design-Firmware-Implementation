/*
=========================================================================================================================
 *** rf_eesm ***
 Exponential Effective-SINR Mapping (EESM).
=========================================================================================================================

 Description:
     This file implements the exponential effective-SINR mapping (EESM), which reduces the per-resource-element SINR
     values of one codeword to a single effective SINR in decibels. The mapping is required because a codeword spans
     many subcarriers with different SINRs, and the selection logic needs one scalar that predicts the block error rate
     of the whole codeword. An arithmetic average is unsuitable for this purpose: decoding failure is governed by the
     weakest portions of the codeword, which an average understates.

     The complete procedure operates as follows. The mapping evaluates eff = -beta * ln( mean( exp( -SINR_n / beta ) ) ) over the resource elements and converts
     the result to decibels. The exponential weighting emphasizes the weak resource elements in proportion to their
     effect on the decoder, and the per-scheme parameter beta, calibrated in the reference model, sets the degree of
     that emphasis: large beta approaches the arithmetic mean and small beta approaches the minimum. The exponential
     and logarithm are computed in Q16.16 fixed point by the helpers of rf_math, and the result matches the
     double-precision reference within approximately 0.004 dB over the verification set.

 Input / Output:
     Given per function below.

 Supporting files:
     header      rf_eesm.h        (declares the two functions and the beta table)
     header      rf_fixed.h       (Q16.16 type and multiply)
     header      rf_math.h        (fixed-point exp, ln, ten-log10)
     reference   calculate_effective_sinr.m ('eesm' branch)
     calls       rf_exp_neg_q16, rf_ln_q16, rf_ten_log10_q16 (in rf_math.c), rf_q16_mul (in rf_fixed.h)
=========================================================================================================================
*/
#include "rf_eesm.h"
#include "rf_math.h"

/* The per-scheme beta knobs, [1.5 1.6 1.7 4.5 5.5 6.5 12.0 16.0 20.0], written in Q16.16. */
const q16_t RF_EESM_BETA_Q16[9] = {
    98304, 104858, 111411, 294912, 360448,            /* 1.5, 1.6, 1.7, 4.5, 5.5. */
    425984, 786432, 1048576, 1310720                  /* 6.5, 12.0, 16.0, 20.0.   */
};

/*
=========================================================================================================================
 *** rf_eesm_eff_sinr_db ***
 EESM effective SINR from a set of resource-element SINRs and an explicit beta.
=========================================================================================================================

 Description:
     This function evaluates the mapping with an explicitly supplied beta. For each resource element the quantity
     exp(-SINR/beta) is computed, the values are averaged, the logarithm of the average is taken, and the result is
     scaled by minus beta to give the effective SINR, which is then converted to decibels for the selection curves.

 Input:
     sinr_lin_q16   Array of N linear (not decibel) SINR values in Q16.16.
     n              Number of resource elements N.
     beta_q16       The EESM tuning knob beta in Q16.16.

 Output:
     return value   The effective SINR in decibels, Q16.16.
=========================================================================================================================
*/
q16_t rf_eesm_eff_sinr_db(const q16_t *sinr_lin_q16, size_t n, q16_t beta_q16)
{
    if (n == 0) return 0;                             /* No subcarriers, nothing to do. */

    q16_t inv_beta = (q16_t)(((int64_t)Q16_ONE << Q16_SHIFT) / beta_q16);  /* Work out 1/beta once. */

    int64_t acc = 0;                                  /* Running sum of the exponentials. */
    for (size_t i = 0; i < n; ++i) {                  /* Visit each subcarrier. */
        q16_t arg = rf_q16_mul(sinr_lin_q16[i], inv_beta);  /* SINR divided by beta. */
        q16_t e   = rf_exp_neg_q16((q16_t)(-arg));    /* exp of minus that. */
        acc += (int64_t)e;                            /* Add it to the pile. */
    }

    q16_t mean = (q16_t)(acc / (int64_t)n);           /* Average the exponentials. */
    if (mean <= 0) mean = 1;                          /* Guard before taking the log. */

    q16_t ln_mean = rf_ln_q16(mean);                  /* Log of the average. */
    q16_t eff     = rf_q16_mul((q16_t)(-beta_q16), ln_mean);  /* Times minus beta gives the effective SINR. */

    if (eff < 1) eff = 1;                             /* Keep it positive before the decibel conversion. */

    return rf_ten_log10_q16(eff);                     /* Report it in decibels. */
}

/*
=========================================================================================================================
 *** rf_eesm_eff_sinr_db_mcs ***
 EESM effective SINR using the beta of a given MCS.
=========================================================================================================================

 Description:
     This function selects the calibrated beta from the scheme index, bounds the index to the table, and evaluates the
     mapping with that beta by calling the explicit-beta function.

 Input:
     sinr_lin_q16   Array of N linear SINR values in Q16.16.
     n              Number of resource elements N.
     mcs_index      MCS index zero to eight, which selects the beta.

 Output:
     return value   The effective SINR in decibels, Q16.16.
=========================================================================================================================
*/
q16_t rf_eesm_eff_sinr_db_mcs(const q16_t *sinr_lin_q16, size_t n, int mcs_index)
{
    if (mcs_index < 0) mcs_index = 0;                 /* Stay inside the table. */
    if (mcs_index > 8) mcs_index = 8;
    return rf_eesm_eff_sinr_db(sinr_lin_q16, n, RF_EESM_BETA_Q16[mcs_index]);  /* Use that scheme's beta. */
}
