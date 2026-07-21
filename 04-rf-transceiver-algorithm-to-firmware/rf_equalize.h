/*
=========================================================================================================================
 *** rf_equalize (header) ***
 Declarations for the zero-forcing and MMSE MIMO equalizers.
=========================================================================================================================

 Description:
     Declares the two per-subcarrier MIMO detectors implemented in rf_equalize.c.

     Each declaration names the inputs and outputs; the full descriptions are in rf_equalize.c.

 Supporting files:
     implemented in   rf_equalize.c
     header           rf_complex.h (complex type), rf_matrix.h (used inside the source)
     reference        zf_equalize_mimo.m, mmse_equalize_mimo.m
=========================================================================================================================
*/
#ifndef RF_EQUALIZE_H
#define RF_EQUALIZE_H

#include "rf_complex.h"
#include <stddef.h>

/* Zero-forcing: solve (H^H H) x = H^H y. */
int rf_zf_equalize(const cplx_t *H, size_t Nr, size_t Nt, const cplx_t *y, cplx_t *x_hat);

/* MMSE: solve (H^H H + noiseVar I) x = H^H y, with noiseVar = 1 / linear SNR. */
int rf_mmse_equalize(const cplx_t *H, size_t Nr, size_t Nt, const cplx_t *y,
                     double noiseVar, cplx_t *x_hat);


/* Soft-output MMSE: unbiased estimate and per-stream effective noise variance for the soft decoder. */
int rf_mmse_equalize_soft(const cplx_t *H, size_t Nr, size_t Nt, const cplx_t *y,
                          double noiseVar, cplx_t *x_biased, cplx_t *x_soft, double *nvar_eff);

#endif /* RF_EQUALIZE_H */
