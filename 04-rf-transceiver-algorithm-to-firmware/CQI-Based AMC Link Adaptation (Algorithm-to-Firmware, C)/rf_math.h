/*
=========================================================================================================================
 *** rf_math (header) ***
 Declarations for the fixed-point transcendental helpers.
=========================================================================================================================

 Description:
     Declares the fixed-point exponential, natural logarithm, and ten-log-base-ten implemented in rf_math.c.

     Each declaration names the input and output; the full descriptions are in rf_math.c.

 Supporting files:
     implemented in   rf_math.c
     header           rf_fixed.h (Q16.16 type)
     used by          rf_eesm.c
=========================================================================================================================
*/
#ifndef RF_MATH_H
#define RF_MATH_H

#include "rf_fixed.h"

q16_t rf_exp_neg_q16(q16_t x);      /* exp(x) for x <= 0, in Q16.16. */
q16_t rf_ln_q16(q16_t x);           /* ln(x) for x > 0, in Q16.16. */
q16_t rf_ten_log10_q16(q16_t x);    /* ten times log-base-ten of x, for x > 0, in Q16.16. */

#endif /* RF_MATH_H */
