/*
=========================================================================================================================
 *** rf_eesm (header) ***
 Declarations for the exponential effective-SINR mapping.
=========================================================================================================================

 Description:
     Declares the EESM functions and the per-MCS beta table implemented in rf_eesm.c.

     Each declaration names the inputs and output; the full descriptions are in rf_eesm.c.

 Supporting files:
     implemented in   rf_eesm.c
     header           rf_fixed.h (Q16.16 type), rf_math.h (used inside the source)
     reference        calculate_effective_sinr.m
=========================================================================================================================
*/
#ifndef RF_EESM_H
#define RF_EESM_H

#include "rf_fixed.h"
#include <stddef.h>

/* Per-MCS calibration parameters beta (index zero to eight), in Q16.16. */
extern const q16_t RF_EESM_BETA_Q16[9];

q16_t rf_eesm_eff_sinr_db(const q16_t *sinr_lin_q16, size_t n, q16_t beta_q16);     /* EESM with an explicit beta. */
q16_t rf_eesm_eff_sinr_db_mcs(const q16_t *sinr_lin_q16, size_t n, int mcs_index);  /* EESM using the MCS's beta. */

#endif /* RF_EESM_H */
