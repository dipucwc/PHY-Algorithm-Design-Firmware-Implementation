/*
=========================================================================================================================
 *** rf_mcs ***
 MCS table and BLER-constrained MCS selection.
=========================================================================================================================

 Description:
     This file implements the modulation-and-coding-scheme (MCS) table and the BLER-constrained selection that decides
     the transmission format of each slot. The table contains nine entries formed by crossing three QAM orders with
     three coding rates, ordered by nondecreasing nominal spectral efficiency. The selection rule chooses the entry
     with the highest spectral efficiency whose predicted block error rate satisfies the configured target.

     The complete procedure operates as follows, starting with the prediction. For each candidate scheme, the predicted block error rate is read from
     that scheme's calibrated curve at the offset-corrected effective SINR of each spatial layer, and the per-layer
     predictions are combined by their mean or, when configured, by the worst layer. Candidates whose combined
     prediction exceeds the target are discarded. Among the remaining candidates the selection applies three ordered
     criteria: highest nominal spectral efficiency, then lowest predicted block error rate, then lower modulation
     order. When no candidate satisfies the target, the selection falls back to the most robust entry so that
     transmission continues. The curve reading is performed by a monotone linear interpolation with end clamping,
     provided as a separate function because the selector evaluates it for every candidate on every layer.

 Input / Output:
     Given per function below.

 Supporting files:
     header      rf_mcs.h         (declares the table, the curve type, and the two functions)
     header      rf_fixed.h       (Q16.16 type and multiply)
     reference   create_mcs_table.m, interpolate_bler_curve.m, select_mcs_for_target_bler.m
     calls       rf_q16_mul (in rf_fixed.h); the selector calls rf_bler_interp in this file
=========================================================================================================================
*/
#include "rf_mcs.h"

/* Little helper to work out a scheme's bits-per-symbol times its code rate, in Q16.16. */
#define SE_Q16(bps,num,den)  ((q16_t)(((int64_t)(bps)*(num)*Q16_ONE)/(den)))

/* The nine schemes: three QAM sizes each at code rates 1/2, 2/3, 3/4. */
const rf_mcs_entry_t RF_MCS_TABLE[RF_NUM_MCS] = {
    { 0,  4, 2, 1, 2, SE_Q16(2,1,2) },  /* QPSK,  rate 1/2 -> carries 1.00 bits/symbol. */
    { 1,  4, 2, 2, 3, SE_Q16(2,2,3) },  /* QPSK,  rate 2/3 -> 1.33. */
    { 2,  4, 2, 3, 4, SE_Q16(2,3,4) },  /* QPSK,  rate 3/4 -> 1.50. */
    { 3, 16, 4, 1, 2, SE_Q16(4,1,2) },  /* 16-QAM, rate 1/2 -> 2.00. */
    { 4, 16, 4, 2, 3, SE_Q16(4,2,3) },  /* 16-QAM, rate 2/3 -> 2.67. */
    { 5, 16, 4, 3, 4, SE_Q16(4,3,4) },  /* 16-QAM, rate 3/4 -> 3.00. */
    { 6, 64, 6, 1, 2, SE_Q16(6,1,2) },  /* 64-QAM, rate 1/2 -> 3.00. */
    { 7, 64, 6, 2, 3, SE_Q16(6,2,3) },  /* 64-QAM, rate 2/3 -> 4.00. */
    { 8, 64, 6, 3, 4, SE_Q16(6,3,4) },  /* 64-QAM, rate 3/4 -> 4.50. */
};

/*
=========================================================================================================================
 *** rf_bler_interp ***
 Predicted BLER at a queried effective SINR, read off one MCS's calibrated curve.
=========================================================================================================================

 Description:
     This function reads the predicted block error rate from one scheme's calibrated curve at a queried effective SINR.
     Queries outside the calibrated range return the nearest end value; queries inside the range are answered by linear
     interpolation between the two bracketing points. The curve is stored with ascending SINR and non-increasing error
     rate, which the calibration guarantees.

 Input:
     c   The calibrated curve (ascending SINR points and non-increasing BLER points).
     x   The queried effective SINR in decibels, Q16.16.

 Output:
     return value   The predicted BLER in Q16.16, or minus one if the curve has no points (invalid).
=========================================================================================================================
*/
q16_t rf_bler_interp(const rf_bler_curve_t *c, q16_t x)
{
    if (c->npts == 0) return -1;                      /* No curve to read: signal "no answer". */
    if (c->npts == 1) return c->bler[0];              /* Only one point: that's our answer. */
    if (x <= c->sinr_db[0])            return c->bler[0];             /* Below the curve: take the low end. */
    if (x >= c->sinr_db[c->npts - 1])  return c->bler[c->npts - 1];   /* Above the curve: take the high end. */

    size_t i = 1;                                     /* Find which two points bracket our SINR. */
    while (i < c->npts && c->sinr_db[i] < x) ++i;

    q16_t x0 = c->sinr_db[i - 1], x1 = c->sinr_db[i]; /* The SINRs of those two points. */
    q16_t y0 = c->bler[i - 1],    y1 = c->bler[i];    /* Their error rates. */
    q16_t dx = (q16_t)(x1 - x0);                      /* The SINR gap between them. */
    if (dx == 0) return y0;                           /* Same point twice: avoid dividing by zero. */

    int64_t frac = (((int64_t)(x - x0)) << Q16_SHIFT) / dx;  /* How far along the gap our SINR sits. */
    q16_t   t    = (q16_t)frac;
    return (q16_t)(y0 + rf_q16_mul((q16_t)(y1 - y0), t));    /* Straight-line reading between the two. */
}

/*
=========================================================================================================================
 *** rf_mcs_select ***
 Choose the transmission MCS of the slot under the BLER target.
=========================================================================================================================

 Description:
     This function selects the transmission scheme of the slot. Every candidate is predicted on every spatial layer at
     the offset-corrected effective SINR, the per-layer predictions are combined according to the configured criterion,
     candidates above the target are discarded, and the ordered tie-breaks determine the winner among the rest. When no
     candidate satisfies the target, the lowest scheme is returned with the fallback status; when the highest table
     entry satisfies it, the saturation status is reported.

 Input:
     quality_report   Nt-by-nine array (row by row) of per-layer, per-scheme effective SINR in decibels, Q16.16.
     nt               Number of spatial layers Nt.
     curves           Calibrated error curve of each of the nine schemes.
     target_bler      The error-rate target, Q16.16 (for example 0.10).
     olla_offset_db   The outer-loop SINR nudge added before prediction, Q16.16.
     criterion        Combine the layers by their average or by the worst one.

 Output:
     out_criterion_bler   The predicted error rate of the chosen scheme.
     out_status           How it ended (target met, top scheme reached, fell back, or no prediction).
     return value         The chosen scheme index, zero to eight.
=========================================================================================================================
*/
int rf_mcs_select(const q16_t *quality_report, size_t nt,
                  const rf_bler_curve_t curves[RF_NUM_MCS],
                  q16_t target_bler, q16_t olla_offset_db,
                  rf_sel_criterion_t criterion,
                  q16_t *out_criterion_bler, rf_sel_status_t *out_status)
{
    q16_t crit[RF_NUM_MCS];                           /* Each scheme's combined predicted error rate. */
    int   valid[RF_NUM_MCS];                          /* Whether every layer gave a usable prediction. */
    int   any_valid = 0;                              /* Whether any scheme is usable at all. */

    for (int m = 0; m < RF_NUM_MCS; ++m) {            /* Look at every scheme. */

        int     ok    = 1;                            /* Did all layers predict cleanly? */
        int64_t sum   = 0;                            /* For averaging across layers. */
        q16_t   worst = 0;                            /* For the worst-layer option. */

        for (size_t l = 0; l < nt; ++l) {             /* Predict on each spatial layer. */
            q16_t eff = quality_report[l * (size_t)RF_NUM_MCS + (size_t)m];          /* This layer's SINR for this scheme. */
            q16_t p   = rf_bler_interp(&curves[m], (q16_t)(eff + olla_offset_db));  /* Predicted error rate. */
            if (p < 0) { ok = 0; break; }             /* No prediction: this scheme is out. */
            sum += p;                                 /* Tally for the average. */
            if (p > worst) worst = p;                 /* Track the worst layer. */
        }

        if (ok) {                                     /* Combine the layers into one number. */
            crit[m]   = (criterion == RF_CRIT_WORST) ? worst : (q16_t)(sum / (int64_t)nt);
            valid[m]  = 1;
            any_valid = 1;
        } else {
            valid[m]  = 0;                            /* Mark this scheme unusable. */
        }
    }

    if (!any_valid) {                                 /* Nothing could be predicted at all. */
        *out_criterion_bler = -1;
        *out_status = RF_SEL_NO_VALID_PREDICTION;
        return 0;                                     /* Default to the most robust scheme. */
    }

    int best = -1;                                    /* The best scheme that clears the target so far. */
    for (int m = 0; m < RF_NUM_MCS; ++m) {
        if (!valid[m] || crit[m] > target_bler) continue;                 /* Skip anything over target. */
        if (best < 0) { best = m; continue; }                             /* First one that qualifies. */
        if (RF_MCS_TABLE[m].nominal_se > RF_MCS_TABLE[best].nominal_se) { best = m; continue; }  /* More bits wins. */
        if (RF_MCS_TABLE[m].nominal_se < RF_MCS_TABLE[best].nominal_se) continue;                /* Fewer bits loses. */
        if (crit[m] < crit[best]) { best = m; continue; }                 /* Tie on bits: cleaner wins. */
        if (crit[m] > crit[best]) continue;
        if (RF_MCS_TABLE[m].mod_order < RF_MCS_TABLE[best].mod_order) best = m;  /* Still tied: smaller QAM wins. */
    }

    if (best < 0) {                                   /* Nothing cleared the target. */
        *out_criterion_bler = valid[0] ? crit[0] : (q16_t)-1;
        *out_status = RF_SEL_LOWEST_FALLBACK;
        return 0;                                     /* Fall back to the most robust scheme. */
    }

    *out_criterion_bler = crit[best];                 /* Report the winner's predicted error rate. */
    *out_status = (best == RF_NUM_MCS - 1) ? RF_SEL_HIGHEST_MCS : RF_SEL_TARGET_MET;
    return RF_MCS_TABLE[best].mcs_index;              /* Hand back the chosen scheme. */
}
