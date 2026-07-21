/*
=========================================================================================================================
 *** rf_sync (header) ***
 Declarations for the OFDM timing and CFO synchronization kernels.
=========================================================================================================================

 Description:
     Declares the four synchronization functions implemented in rf_sync.c.

     Each declaration names the inputs and outputs; the full descriptions are in rf_sync.c.

 Supporting files:
     implemented in   rf_sync.c
     header           rf_complex.h (complex type used in the signatures)
     reference        schmidl_cox_metric.m, estimate_coarse_cfo.m, apply_cfo.m
=========================================================================================================================
*/
#ifndef RF_SYNC_H
#define RF_SYNC_H

#include "rf_complex.h"
#include <stddef.h>

/* Timing metric and complex autocorrelation over the search range; returns the search length. */
size_t rf_schmidl_cox_metric(const cplx_t *rx, size_t L,
                             size_t preamble_len, size_t cp_len, size_t frame_len,
                             double *lambda, cplx_t *m_sc);

/* Index of the metric peak (the frame timing). */
size_t rf_detect_timing(const double *lambda, size_t search_len);

/* Coarse CFO in subcarrier spacings from the autocorrelation phase at the peak. */
double rf_estimate_coarse_cfo(const cplx_t *m_sc, size_t d_hat);

/* Apply a CFO phase ramp (positive to impair, negative to correct). */
void rf_apply_cfo(const cplx_t *in, size_t n, double epsilon, size_t Nfft, cplx_t *out);

#endif /* RF_SYNC_H */
