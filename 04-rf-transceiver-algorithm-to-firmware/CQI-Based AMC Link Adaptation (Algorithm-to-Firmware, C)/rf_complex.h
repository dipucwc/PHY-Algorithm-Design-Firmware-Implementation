/*
=========================================================================================================================
 *** rf_complex ***
 Complex-number helper for the RF PHY firmware.
=========================================================================================================================

 Description:
     Defines a complex-number type and the small set of operations the receiver kernels use, because OFDM samples in the
     frequency domain are complex.

     A complex number is stored as two doubles, its real and imaginary parts. Each operation is a short inline function
     so the C reads almost the same as the MATLAB reference, where complex arithmetic is built in. A fixed-point build
     would change only this type.

 Input / Output:
     Each helper takes and returns complex or real values; described at each definition.

 Supporting files:
     used by     rf_sync.c, rf_matrix.c, rf_equalize.c, rf_metrics.c
     reference   (the built-in complex arithmetic of the MATLAB files)
=========================================================================================================================
*/
#ifndef RF_COMPLEX_H
#define RF_COMPLEX_H

#include <math.h>

typedef struct { double re; double im; } cplx_t;   /* One complex sample: real and imaginary parts. */

/* cx: build a complex number.               Input: re, im.  Output: the complex value.        */
static inline cplx_t cx(double re, double im) { cplx_t z; z.re = re; z.im = im; return z; }

/* cx_add: sum of two complex numbers.       Input: a, b.    Output: a + b.                    */
static inline cplx_t cx_add(cplx_t a, cplx_t b) { return cx(a.re + b.re, a.im + b.im); }

/* cx_sub: difference of two complex numbers. Input: a, b.   Output: a - b.                    */
static inline cplx_t cx_sub(cplx_t a, cplx_t b) { return cx(a.re - b.re, a.im - b.im); }

/* cx_mul: product of two complex numbers.    Input: a, b.   Output: a * b.                    */
static inline cplx_t cx_mul(cplx_t a, cplx_t b)
{
    return cx(a.re * b.re - a.im * b.im,          /* Real part:      re*re - im*im. */
              a.re * b.im + a.im * b.re);         /* Imaginary part: re*im + im*re. */
}

/* cx_conj: complex conjugate.                Input: a.       Output: conjugate of a.          */
static inline cplx_t cx_conj(cplx_t a) { return cx(a.re, -a.im); }

/* cx_abs2: magnitude squared.                Input: a.       Output: |a|^2 = re^2 + im^2.     */
static inline double cx_abs2(cplx_t a) { return a.re * a.re + a.im * a.im; }

/* cx_abs: magnitude.                         Input: a.       Output: |a|.                     */
static inline double cx_abs(cplx_t a) { return sqrt(cx_abs2(a)); }

/* cx_angle: phase angle in radians (MATLAB angle()). Input: a. Output: atan2(im, re).         */
static inline double cx_angle(cplx_t a) { return atan2(a.im, a.re); }

#endif /* RF_COMPLEX_H */
