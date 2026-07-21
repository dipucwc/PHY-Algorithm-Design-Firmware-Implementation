/*
=========================================================================================================================
 *** rf_quality (header) ***
 Declarations for the receiver-side link-quality estimation.
=========================================================================================================================

 Description:
     This header declares the per-stream post-equalization SINR estimate, the per-layer quality report, and the
     uncorrected CQI implemented in rf_quality.c. Each declaration names the inputs and outputs; the full descriptions
     are in the source file.

 Supporting files:
     implemented in   rf_quality.c
     header           rf_complex.h (complex type), rf_eesm.h and rf_mcs.h (mapping and selection)
     reference        estimate_post_eq_sinr.m, estimate_quality_report.m, estimate_cqi.m
=========================================================================================================================
*/
#ifndef RF_QUALITY_H
#define RF_QUALITY_H

#include "rf_complex.h"
#include "rf_fixed.h"
#include "rf_mcs.h"
#include <stddef.h>

#define RF_QMAX_ANT 16             /* Largest antenna count the fixed buffers support. */

/* Per-stream post-equalization SINR at one subcarrier from the estimated channel. */
int rf_post_eq_sinr(const cplx_t *Hest, size_t Nr, size_t Nt,
                    double noiseVar, double Es, double *sinr_lin);

/* Per-layer, per-candidate effective-SINR quality report of one slot (Q16.16 decibels). */
void rf_quality_report(const double *sinr_lin, size_t nt, size_t nfft, q16_t *report);

/* Uncorrected CQI: the zero-offset selection on the quality report. */
int rf_estimate_cqi(const double *sinr_lin, size_t nt, size_t nfft,
                    const rf_bler_curve_t curves[RF_NUM_MCS], q16_t target, q16_t *report);

#endif /* RF_QUALITY_H */
