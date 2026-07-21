/*
=========================================================================================================================
 *** rf_metrics (header) ***
 Declarations for the link-quality metrics and threshold modulation selection.
=========================================================================================================================

 Description:
     Declares the SINR, EVM, and threshold-modulation functions implemented in rf_metrics.c.

     Each declaration names the inputs and outputs; the full descriptions are in rf_metrics.c.

 Supporting files:
     implemented in   rf_metrics.c
     header           rf_complex.h (complex type used in the signatures)
     reference        compute_sinr.m, compute_evm.m, amc_select_modulation.m
=========================================================================================================================
*/
#ifndef RF_METRICS_H
#define RF_METRICS_H

#include "rf_complex.h"
#include <stddef.h>

/* Post-equalization SINR in decibels. */
double rf_compute_sinr_db(const cplx_t *tx, const cplx_t *rx, size_t n);

/* RMS error vector magnitude in percent. */
double rf_compute_evm_pct(const cplx_t *tx, const cplx_t *rx, size_t n);

/* Threshold modulation selection; writes bits per symbol, returns the QAM order. */
int rf_amc_select_modulation(double snr_db, int *bits_per_sym);

#endif /* RF_METRICS_H */
