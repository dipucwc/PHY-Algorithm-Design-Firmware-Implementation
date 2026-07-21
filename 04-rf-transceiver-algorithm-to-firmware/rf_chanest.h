/*
=========================================================================================================================
 *** rf_chanest (header) ***
 Declarations for the pilot-based channel estimation functions.
=========================================================================================================================

 Description:
     This header declares the least-squares pilot estimate and the fine carrier-offset estimate implemented in
     rf_chanest.c. Each declaration names the inputs and outputs; the full descriptions are in the source file.

 Supporting files:
     implemented in   rf_chanest.c
     header           rf_complex.h (complex type used in the signatures)
     reference        ls_pilot_estimate.m, estimate_fine_cfo.m
=========================================================================================================================
*/
#ifndef RF_CHANEST_H
#define RF_CHANEST_H

#include "rf_complex.h"
#include <stddef.h>

/* Least-squares channel estimate at the pilot subcarriers. */
void rf_ls_pilot_estimate(const cplx_t *rx_pilots, const cplx_t *tx_pilots, size_t n, cplx_t *h_ls);

/* Fine carrier-offset estimate from the pilot phase drift between two consecutive symbols. */
double rf_estimate_fine_cfo(const cplx_t *pilots_sym1, const cplx_t *pilots_sym2,
                            size_t n, size_t Nfft, size_t symbol_len);


/* Wiener MMSE estimate at all subcarriers from the precomputed filter and the pilot observations. */
void rf_wiener_apply(const cplx_t *W, const cplx_t *h_pilots, size_t Nfft, size_t Np, cplx_t *h_all);

#endif /* RF_CHANEST_H */
