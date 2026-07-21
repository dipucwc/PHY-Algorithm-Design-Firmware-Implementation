/*
=========================================================================================================================
 *** rf_fixed ***
 Q15 and Q16.16 fixed-point arithmetic for the RF PHY firmware.
=========================================================================================================================

 Description:
     Defines the two fixed-point number formats used across the firmware and the small set of operations on them: a
     saturating cast, conversion to and from floating point, and a rounded multiply. A fixed-point format stores a
     fractional number inside an ordinary integer, so a core without a floating-point unit can still do the arithmetic.

     Q1.15 keeps one sign bit and fifteen fraction bits in an int16, range about minus one to one. Q16.16 keeps sixteen
     integer and sixteen fraction bits in an int32, used for SINR in decibels and for accumulation that would overflow
     Q15. Multiplies use a 64-bit intermediate and round before shifting back.

 Input / Output:
     Provided as inline helper functions; each is documented at its definition.

 Supporting files:
     used by     rf_math.c, rf_eesm.c, rf_mcs.c, rf_state.c
     reference   (the fixed-point equivalent of the double-precision reference arithmetic)
=========================================================================================================================
*/
#ifndef RF_FIXED_H
#define RF_FIXED_H

#include <stdint.h>

typedef int16_t q15_t;   /* Q1.15  : one sign and fifteen fraction bits, range about [-1, 1). */
typedef int32_t q16_t;   /* Q16.16 : sixteen integer and sixteen fraction bits. */

#define Q15_ONE   ((q15_t)0x7FFF)            /* Largest Q15 value, about one. */
#define Q15_SHIFT  15                        /* Fraction bits in Q15. */
#define Q16_SHIFT  16                        /* Fraction bits in Q16.16. */
#define Q16_ONE   ((q16_t)(1 << Q16_SHIFT))  /* The value one in Q16.16. */

/* rf_sat_q15: clamp a 32-bit accumulator into the Q15 range. Input: x. Output: x clipped to [-32768, 32767]. */
static inline q15_t rf_sat_q15(int32_t x)
{
    if (x >  32767) return (q15_t) 32767;         /* Clip above the maximum. */
    if (x < -32768) return (q15_t)-32768;         /* Clip below the minimum. */
    return (q15_t)x;                              /* In range: cast directly. */
}

/* rf_double_to_q16: convert a real number to Q16.16 with rounding. Input: x. Output: x in Q16.16. */
static inline q16_t rf_double_to_q16(double x)
{
    return (q16_t)(x * (double)Q16_ONE + (x >= 0 ? 0.5 : -0.5));  /* Scale by 2^16 and round. */
}

/* rf_q16_to_double: convert a Q16.16 value back to a real number (tests and logging). Input: x. Output: the real value. */
static inline double rf_q16_to_double(q16_t x)
{
    return (double)x / (double)Q16_ONE;          /* Divide by 2^16. */
}

/* rf_q16_mul: multiply two Q16.16 values with rounding. Input: a, b. Output: the Q16.16 product a*b. */
static inline q16_t rf_q16_mul(q16_t a, q16_t b)
{
    int64_t p = (int64_t)a * (int64_t)b;          /* Full-precision product. */
    p += (1 << (Q16_SHIFT - 1));                  /* Add half an LSB for rounding. */
    return (q16_t)(p >> Q16_SHIFT);               /* Shift back to Q16.16. */
}

#endif /* RF_FIXED_H */
