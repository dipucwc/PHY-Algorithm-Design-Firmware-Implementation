/*
=========================================================================================================================
 *** rf_matrix (header) ***
 Declarations for the small complex-matrix operations used by the equalizers.
=========================================================================================================================

 Description:
     Declares the Gram-matrix build, the matched-filter build, and the linear solve implemented in rf_matrix.c.

     Each declaration names the inputs and outputs; the full descriptions are in rf_matrix.c.

 Supporting files:
     implemented in   rf_matrix.c
     header           rf_complex.h (complex type used in the signatures)
     used by          rf_equalize.c
=========================================================================================================================
*/
#ifndef RF_MATRIX_H
#define RF_MATRIX_H

#include "rf_complex.h"
#include <stddef.h>

#define RF_MAX_ANT 16              /* Largest array dimension the fixed buffers support. */

/* Build G = H^H H + reg*I (transmit by transmit). */
void rf_gram_plus_reg(const cplx_t *H, size_t Nr, size_t Nt, double reg, cplx_t *G);

/* Build b = H^H y (length Nt). */
void rf_matched_filter(const cplx_t *H, size_t Nr, size_t Nt, const cplx_t *y, cplx_t *b);

/* Solve A x = b (Nt by Nt); returns zero on success, one if singular. */
int rf_solve(cplx_t *A, cplx_t *b, size_t Nt, cplx_t *x);

#endif /* RF_MATRIX_H */
