/*
=========================================================================================================================
 *** rf_matrix ***
 Small complex-matrix operations for MIMO equalization.
=========================================================================================================================

 Description:
     This file implements the complex-matrix operations used by the MIMO equalizers. It contains the Gram-matrix
     construction, the matched-filter construction, and a direct linear-system solver. Together they evaluate the
     equalizer equation (H^H H + a I) x = H^H y at one subcarrier.

     The complete procedure operates as follows. The Gram function forms H^H H, in which entry (i, j) is the inner product
     of channel columns i and j summed over the receive antennas, and adds an optional regularization value on the
     diagonal. The matched-filter function forms H^H y by projecting the received vector onto each channel column. The
     solver then computes x by Gauss-Jordan elimination with partial pivoting. Because the system dimension equals the
     transmit-antenna count, the matrices are small, and a direct elimination is preferred over an explicit matrix
     inverse: it requires fewer operations, and the partial pivoting maintains numerical stability. All matrices are
     stored row-major in flat arrays.

 Input / Output:
     Given per function below.

 Supporting files:
     header      rf_matrix.h      (declares the three functions in this file)
     header      rf_complex.h     (complex type and complex add / subtract / multiply / conjugate)
     reference   (the linear algebra behind zf_equalize_mimo.m and mmse_equalize_mimo.m)
     calls       none (uses only the inline helpers in rf_complex.h)
=========================================================================================================================
*/
#include "rf_matrix.h"

/*
=========================================================================================================================
 *** cx_div ***
 Complex division, used inside the solver.
=========================================================================================================================

 Description:
     This function performs complex division. The numerator is multiplied by the conjugate of the denominator and the
     result is scaled by the reciprocal of the denominator magnitude squared. The solver uses it when normalizing each
     pivot row.

 Input:
     a   Numerator.
     b   Denominator.

 Output:
     return value   a / b.
=========================================================================================================================
*/
static cplx_t cx_div(cplx_t a, cplx_t b)
{
    double d = cx_abs2(b);                            /* Magnitude squared of the bottom. */
    if (d < 1e-300) d = 1e-300;                       /* Never divide by zero. */
    return cx((a.re * b.re + a.im * b.im) / d,        /* Real part of a times conjugate of b, scaled. */
              (a.im * b.re - a.re * b.im) / d);       /* Imaginary part, scaled. */
}

/*
=========================================================================================================================
 *** rf_gram_plus_reg ***
 Build G = H^H H and add a value on the diagonal.
=========================================================================================================================

 Description:
     This function constructs the Gram matrix G = H^H H and adds a configurable value on its diagonal. Entry (i, j) is
     computed as the sum over receive antennas of the conjugate of H(m, i) times H(m, j). With the diagonal value set to
     zero the plain Gram matrix is produced, which corresponds to zero-forcing; with the noise variance on the diagonal
     the regularized matrix of the MMSE detector is produced.

 Input:
     H     Channel matrix, receive by transmit, stored row by row.
     Nr    Number of receive antennas.
     Nt    Number of transmit antennas.
     reg   Value added on the diagonal (zero for zero-forcing, noise variance for MMSE).

 Output:
     G     The transmit-by-transmit Gram matrix, stored row by row (caller-allocated).
=========================================================================================================================
*/
void rf_gram_plus_reg(const cplx_t *H, size_t Nr, size_t Nt, double reg, cplx_t *G)
{
    for (size_t i = 0; i < Nt; ++i) {                 /* Each row of G is one channel column. */
        for (size_t j = 0; j < Nt; ++j) {             /* Each column of G is another channel column. */

            cplx_t acc = cx(0.0, 0.0);                /* Dot product of columns i and j. */
            for (size_t m = 0; m < Nr; ++m) {         /* Sum down the receive antennas. */
                cplx_t hmi = H[m * Nt + i];           /* Channel entry for antenna m, stream i. */
                cplx_t hmj = H[m * Nt + j];           /* Channel entry for antenna m, stream j. */
                acc = cx_add(acc, cx_mul(cx_conj(hmi), hmj));  /* Conjugate of one times the other. */
            }

            if (i == j) acc.re += reg;                /* Add the regularization only on the diagonal. */
            G[i * Nt + j] = acc;                      /* Store the finished entry. */
        }
    }
}

/*
=========================================================================================================================
 *** rf_matched_filter ***
 Build b = H^H y.
=========================================================================================================================

 Description:
     This function constructs the matched-filter vector b = H^H y. Entry i is the sum over receive antennas of the
     conjugate of H(m, i) times y(m), which projects the received vector onto channel column i. The result forms the
     right-hand side of the equalizer system.

 Input:
     H    Channel matrix, receive by transmit, stored row by row.
     Nr   Number of receive antennas.
     Nt   Number of transmit antennas.
     y    Received vector, length Nr.

 Output:
     b    Matched-filter vector, length Nt (caller-allocated).
=========================================================================================================================
*/
void rf_matched_filter(const cplx_t *H, size_t Nr, size_t Nt, const cplx_t *y, cplx_t *b)
{
    for (size_t i = 0; i < Nt; ++i) {                 /* One entry per transmit stream. */
        cplx_t acc = cx(0.0, 0.0);                    /* Projection of y onto channel column i. */
        for (size_t m = 0; m < Nr; ++m) {             /* Sum down the receive antennas. */
            acc = cx_add(acc, cx_mul(cx_conj(H[m * Nt + i]), y[m]));  /* Conjugate of channel times received. */
        }
        b[i] = acc;                                   /* Store the entry. */
    }
}

/*
=========================================================================================================================
 *** rf_solve ***
 Solve A x = b for a small system by Gauss-Jordan elimination with partial pivoting.
=========================================================================================================================

 Description:
     This function solves the linear system A x = b by Gauss-Jordan elimination with partial pivoting. The elimination
     proceeds column by column: the row with the largest pivot magnitude is exchanged into the pivot position, the pivot
     row is normalized, and the pivot column is eliminated from every other row, with all operations applied equally to
     the right-hand side. When the matrix has been reduced to the identity, the right-hand side contains the solution.
     The pivot exchange bounds the growth of rounding errors, and a zero pivot column reports the matrix as singular.

 Input:
     A    System matrix, Nt by Nt, stored row by row (modified in place).
     b    Right-hand side, length Nt (modified in place).
     Nt   System size.

 Output:
     x    Solution vector, length Nt (caller-allocated).
     return value   Zero on success, one if the matrix is singular.
=========================================================================================================================
*/
int rf_solve(cplx_t *A, cplx_t *b, size_t Nt, cplx_t *x)
{
    for (size_t col = 0; col < Nt; ++col) {           /* Clear one column at a time. */

        size_t piv = col;                             /* Start by assuming the diagonal entry is the pivot. */
        double best = cx_abs2(A[col * Nt + col]);     /* Its size. */
        for (size_t r = col + 1; r < Nt; ++r) {       /* Look below for a bigger one. */
            double v = cx_abs2(A[r * Nt + col]);
            if (v > best) { best = v; piv = r; }      /* Keep the biggest for stability. */
        }
        if (best < 1e-300) return 1;                  /* Whole column is zero: the matrix can't be solved. */

        if (piv != col) {                             /* Swap the chosen pivot row up into place. */
            for (size_t c = 0; c < Nt; ++c) {         /* Swap the matrix row... */
                cplx_t t = A[col * Nt + c];
                A[col * Nt + c] = A[piv * Nt + c];
                A[piv * Nt + c] = t;
            }
            cplx_t tb = b[col];                       /* ...and the matching right-hand-side entry. */
            b[col] = b[piv];
            b[piv] = tb;
        }

        cplx_t pivval = A[col * Nt + col];            /* Divide the pivot row through so the pivot becomes one. */
        for (size_t c = 0; c < Nt; ++c)
            A[col * Nt + c] = cx_div(A[col * Nt + c], pivval);
        b[col] = cx_div(b[col], pivval);

        for (size_t r = 0; r < Nt; ++r) {             /* Subtract the pivot row from all the others... */
            if (r == col) continue;                   /* ...but not from itself. */
            cplx_t factor = A[r * Nt + col];          /* How much of the pivot row this row needs removed. */
            for (size_t c = 0; c < Nt; ++c)
                A[r * Nt + c] = cx_sub(A[r * Nt + c], cx_mul(factor, A[col * Nt + c]));
            b[r] = cx_sub(b[r], cx_mul(factor, b[col]));  /* Do the same to the right-hand side. */
        }
    }

    for (size_t i = 0; i < Nt; ++i) x[i] = b[i];      /* The right-hand side is now the solution. */
    return 0;                                          /* Solved. */
}
