/*
=========================================================================================================================
 *** rf_math ***
 Fixed-point transcendental helpers in Q16.16 (exp, ln, ten-log10).
=========================================================================================================================

 Description:
     This file implements the transcendental functions required by the effective-SINR mapping in Q16.16 fixed-point
     arithmetic: the exponential of a non-positive argument, the natural logarithm, and the conversion of a linear
     ratio to decibels. Implementing these in integer arithmetic allows the mapping to run on a processor without a
     floating-point unit.

     The complete procedure operates as follows. Each function follows the same structure: the argument is first reduced to a narrow range where a short polynomial
     series is accurate, and the removed part is reapplied exactly. The exponential extracts whole multiples of ln(2),
     each of which becomes a binary shift, and expands the small remainder in a Taylor series. The logarithm expresses
     the argument as a mantissa in the interval [1, 2) times a power of two, evaluates the mantissa logarithm with an
     inverse-hyperbolic-tangent series, and adds the exponent times ln(2). The decibel conversion scales the natural
     logarithm by the constant ten over ln(10). The accuracy is sufficient for the mapping: the resulting effective
     SINR matches the double-precision reference within a few thousandths of a decibel.

 Input / Output:
     Given per function below.

 Supporting files:
     header      rf_math.h        (declares the three functions)
     header      rf_fixed.h       (Q16.16 type, multiply, and constants)
     reference   (the log and exp inside calculate_effective_sinr.m)
     calls       rf_q16_mul (in rf_fixed.h)
=========================================================================================================================
*/
#include "rf_math.h"

#define LN2_Q16   45426    /* ln(2), the natural log of two, written in Q16.16. */

/*
=========================================================================================================================
 *** rf_exp_neg_q16 ***
 Exponential of a non-positive argument.
=========================================================================================================================

 Description:
     This function evaluates the exponential for arguments less than or equal to zero, the only range the mapping
     requires. The magnitude of the argument is reduced by whole units of ln(2), each accounting for a factor of one
     half applied later as a right shift, and the remaining fraction is expanded in a six-term Taylor series, which is
     accurate over the reduced range.

 Input:
     x   A Q16.16 value with x less than or equal to zero.

 Output:
     return value   exp(x) in Q16.16.
=========================================================================================================================
*/
q16_t rf_exp_neg_q16(q16_t x)
{
    if (x > 0) x = 0;                                 /* Safety net; we only expect non-positive inputs. */

    int32_t neg = -x;                                 /* Work with the size of x. */
    int k = 0;                                        /* How many whole ln2 steps we peel off. */
    while (neg >= LN2_Q16) { neg -= LN2_Q16; ++k; }   /* Peel them off until only a small bit is left. */
    q16_t r = (q16_t)neg;                             /* The small leftover, between 0 and ln2. */

    q16_t term = Q16_ONE;                             /* First Taylor term is 1. */
    q16_t sum  = Q16_ONE;                             /* Running total starts at 1. */
    q16_t mr   = -r;                                  /* Each term multiplies by -r. */
    for (int i = 1; i <= 6; ++i) {                    /* Six terms is plenty this close to zero. */
        term = rf_q16_mul(term, mr);                  /* Next power of -r. */
        term = (q16_t)(term / i);                     /* Divide by i (the factorial builds up as we go). */
        sum += term;                                  /* Add it in. */
    }
    if (sum < 0) sum = 0;                             /* Tiny rounding guard. */

    if (k > 30) return 0;                             /* So far below zero it underflows to nothing. */
    sum >>= k;                                        /* Apply the peeled-off halves as a shift. */
    return sum;                                       /* That's exp(x). */
}

/*
=========================================================================================================================
 *** rf_ln_q16 ***
 Natural logarithm of a positive argument.
=========================================================================================================================

 Description:
     This function evaluates the natural logarithm for positive arguments. The argument is normalized to a mantissa in
     the interval [1, 2) times a power of two. The mantissa logarithm is computed from the series in
     u = (m - 1) / (m + 1), and the exponent contributes exactly its multiple of ln(2).

 Input:
     x   A Q16.16 value with x greater than zero.

 Output:
     return value   ln(x) in Q16.16.
=========================================================================================================================
*/
q16_t rf_ln_q16(q16_t x)
{
    if (x <= 0) return (q16_t)(-30 * Q16_ONE);        /* Guard: ln of zero or less isn't defined; clamp low. */

    int e = 0;                                        /* The power-of-two part. */
    q16_t m = x;                                      /* The mantissa, brought into range next. */
    while (m >= (q16_t)(2 * Q16_ONE)) { m >>= 1; ++e; }  /* Halve until below two. */
    while (m <  Q16_ONE)              { m <<= 1; --e; }   /* Double until at least one. */

    q16_t num = m - Q16_ONE;                          /* Set up u = (m-1)/(m+1) for the series. */
    q16_t den = m + Q16_ONE;
    q16_t u   = (q16_t)(((int64_t)num << Q16_SHIFT) / den);
    q16_t u2  = rf_q16_mul(u, u);                     /* u squared, reused each term. */
    q16_t term = u;                                   /* First term is u. */
    q16_t sum  = u;                                   /* Running total. */
    const int denom[3] = {3, 5, 7};                   /* The series uses odd denominators. */
    for (int i = 0; i < 3; ++i) {
        term = rf_q16_mul(term, u2);                  /* Step up by u squared. */
        sum += (q16_t)(term / denom[i]);              /* Add term over the next odd number. */
    }
    q16_t ln_m = (q16_t)(2 * sum);                    /* ln of the mantissa is twice that series. */

    return (q16_t)((int64_t)e * LN2_Q16 + ln_m);      /* Add the power-of-two part back in. */
}

#define TEN_OVER_LN10_Q16   284619   /* The constant 10/ln(10) in Q16.16, for turning ln into decibels. */

/*
=========================================================================================================================
 *** rf_ten_log10_q16 ***
 Ten times the base-ten logarithm (a linear ratio in decibels).
=========================================================================================================================

 Description:
     This function converts a linear ratio to decibels. The natural logarithm is computed first and scaled by the fixed
     constant ten over ln(10), which equals ten times the base-ten logarithm.

 Input:
     x   A Q16.16 value with x greater than zero.

 Output:
     return value   ten times log-base-ten of x, in Q16.16.
=========================================================================================================================
*/
q16_t rf_ten_log10_q16(q16_t x)
{
    q16_t lnx = rf_ln_q16(x);                              /* Natural log first. */
    return rf_q16_mul(lnx, (q16_t)TEN_OVER_LN10_Q16);      /* Scale it into decibels. */
}
