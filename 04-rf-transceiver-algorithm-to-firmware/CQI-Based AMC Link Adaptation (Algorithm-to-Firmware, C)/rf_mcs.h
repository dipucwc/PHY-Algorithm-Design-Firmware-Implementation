/*
=========================================================================================================================
 *** rf_mcs (header) ***
 Declarations for the MCS table and the BLER-constrained selector.
=========================================================================================================================

 Description:
     Declares the MCS table, the calibrated-curve type, the selection status and criterion enumerations, and the two
     functions implemented in rf_mcs.c.

     Each declaration names the inputs and outputs; the full descriptions are in rf_mcs.c.

 Supporting files:
     implemented in   rf_mcs.c
     header           rf_fixed.h (Q16.16 type)
     reference        create_mcs_table.m, interpolate_bler_curve.m, select_mcs_for_target_bler.m
=========================================================================================================================
*/
#ifndef RF_MCS_H
#define RF_MCS_H

#include "rf_fixed.h"
#include <stddef.h>

#define RF_NUM_MCS 9               /* Nine MCS entries in the research table. */

/* One row of the MCS table. */
typedef struct {
    int   mcs_index;               /* Index zero to eight. */
    int   mod_order;               /* QAM order: four, sixteen, or sixty-four. */
    int   bits_per_sym;            /* Bits per QAM symbol: two, four, or six. */
    int   rate_num;                /* Coding-rate numerator. */
    int   rate_den;                /* Coding-rate denominator. */
    q16_t nominal_se;              /* Nominal spectral efficiency, Q16.16. */
} rf_mcs_entry_t;

extern const rf_mcs_entry_t RF_MCS_TABLE[RF_NUM_MCS];   /* The nine-entry table. */

/* How a selection ended. */
typedef enum {
    RF_SEL_TARGET_MET = 0,         /* A satisfying MCS below the top was chosen. */
    RF_SEL_HIGHEST_MCS,            /* The top entry satisfied the target. */
    RF_SEL_LOWEST_FALLBACK,        /* Nothing satisfied the target; the lowest MCS was used. */
    RF_SEL_NO_VALID_PREDICTION     /* No curve produced a prediction. */
} rf_sel_status_t;

/* Whether the per-layer predictions are combined by their mean or by the worst layer. */
typedef enum { RF_CRIT_MEAN = 0, RF_CRIT_WORST = 1 } rf_sel_criterion_t;

/* A calibrated BLER curve for one MCS: ascending SINR points and non-increasing BLER points. */
typedef struct {
    const q16_t *sinr_db;          /* Ascending effective-SINR points, Q16.16. */
    const q16_t *bler;             /* Non-increasing BLER points, Q16.16. */
    size_t       npts;             /* Number of points. */
} rf_bler_curve_t;

/* Predicted BLER at one SINR, read off a calibrated curve. */
q16_t rf_bler_interp(const rf_bler_curve_t *curve, q16_t eff_sinr_db);

/* Select the transmission MCS of the slot under the BLER target. */
int rf_mcs_select(const q16_t *quality_report, size_t nt,
                  const rf_bler_curve_t curves[RF_NUM_MCS],
                  q16_t target_bler, q16_t olla_offset_db,
                  rf_sel_criterion_t criterion,
                  q16_t *out_criterion_bler, rf_sel_status_t *out_status);

#endif /* RF_MCS_H */
