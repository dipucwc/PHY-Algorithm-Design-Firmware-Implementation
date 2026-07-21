/*
=========================================================================================================================
 *** rf_chanest ***
 Pilot-based channel estimation: least-squares at the pilots and fine carrier-offset refinement.
=========================================================================================================================

 Description:
     This file implements the pilot-processing stage of the receiver. It contains the least-squares channel estimate
     at the pilot subcarriers, the fine carrier-frequency-offset estimate from pilot phase drift, and the application
     of the precomputed Wiener filter that produces the MMSE channel estimate at all subcarriers. All three functions
     operate on frequency-domain observations after the FFT.

     The complete procedure operates as follows. The least-squares estimate follows from the pilot model
     Y = H * X + N at each pilot subcarrier: dividing the received pilot by the known transmitted pilot inverts the
     model and yields the channel plus a noise term, an unbiased estimate that requires no statistical knowledge and
     therefore serves as the first stage of the estimation chain. The Wiener stage then refines that first estimate.
     Its filter matrix, computed offline from the pilot-to-pilot and all-to-pilot channel correlations together with
     the noise variance, is applied to the pilot observations as one matrix-vector product per antenna pair; the
     product suppresses the pilot noise and interpolates the estimate to every subcarrier in a single step, and the
     offline computation of the matrix itself remains in the reference because it depends on the channel statistics.
     The fine offset estimate addresses the residual frequency error that remains after the coarse correction: a
     residual offset rotates every subcarrier by a fixed additional phase from one OFDM symbol to the next, the
     rotation is measured as the phase of the correlation between the pilot observations of two consecutive symbols,
     and scaling that phase by the FFT size over the symbol length converts it to a normalized offset in subcarrier
     spacings.

 Input / Output:
     Given per function below.

 Supporting files:
     header      rf_chanest.h     (declares the three functions in this file)
     header      rf_complex.h     (complex type and helpers)
     reference   ls_pilot_estimate.m, estimate_fine_cfo.m, wiener_mmse_estimate.m
     calls       none (uses only the inline helpers in rf_complex.h)
=========================================================================================================================
*/
#include "rf_chanest.h"

/*
=========================================================================================================================
 *** rf_ls_pilot_estimate ***
 Least-squares channel estimate at the pilot subcarriers.
=========================================================================================================================

 Description:
     This function forms the least-squares channel estimate at each pilot position. The received pilot observation is
     divided by the known transmitted pilot symbol, which inverts the pilot model Y = H * X and yields H plus a noise
     term. The result is unbiased and is produced independently at every pilot subcarrier.

 Input:
     rx_pilots   Received frequency-domain observations at the pilot subcarriers.
     tx_pilots   Known transmitted pilot symbols at the same subcarriers.
     n           Number of pilot subcarriers.

 Output:
     h_ls        Least-squares channel estimates at the pilot subcarriers (caller-allocated).
=========================================================================================================================
*/
void rf_ls_pilot_estimate(const cplx_t *rx_pilots, const cplx_t *tx_pilots, size_t n, cplx_t *h_ls)
{
    for (size_t k = 0; k < n; ++k) {                  /* One estimate per pilot subcarrier. */
        cplx_t x = tx_pilots[k];                      /* The known transmitted pilot. */
        double d = cx_abs2(x);                        /* Its power, for the division. */
        if (d < 1e-300) d = 1e-300;                   /* Protect against a zero pilot. */
        cplx_t num = cx_mul(rx_pilots[k], cx_conj(x));/* Received times conjugate of transmitted. */
        h_ls[k] = cx(num.re / d, num.im / d);         /* Divide by the pilot power: the LS estimate. */
    }
}

/*
=========================================================================================================================
 *** rf_estimate_fine_cfo ***
 Fine carrier-offset estimation from pilot phase drift.
=========================================================================================================================

 Description:
     This function estimates the residual carrier-frequency offset from the pilot observations of two consecutive OFDM
     symbols. The pilot observations of the second symbol are correlated against those of the first; a residual offset
     appears as a common phase on that correlation. The phase is extracted with the angle function and converted to a
     normalized offset by the factor Nfft over (2 * pi * symbol length), which accounts for the time separation of the
     two symbol bodies.

 Input:
     pilots_sym1   Pilot observations from the first data symbol.
     pilots_sym2   Pilot observations from the second data symbol.
     n             Number of pilot subcarriers.
     Nfft          FFT size.
     symbol_len    OFDM symbol length in samples including the cyclic prefix.

 Output:
     return value   Fine carrier-offset estimate in subcarrier spacings.
=========================================================================================================================
*/
double rf_estimate_fine_cfo(const cplx_t *pilots_sym1, const cplx_t *pilots_sym2,
                            size_t n, size_t Nfft, size_t symbol_len)
{
    cplx_t acc = cx(0.0, 0.0);                        /* Correlation of the two pilot sets. */

    for (size_t k = 0; k < n; ++k) {                  /* Accumulate across the pilots. */
        acc = cx_add(acc, cx_mul(pilots_sym2[k], cx_conj(pilots_sym1[k])));  /* Second times conj(first). */
    }

    double delta_phi = cx_angle(acc);                 /* Per-symbol phase rotation. */

    return delta_phi * (double)Nfft / (2.0 * M_PI * (double)symbol_len);  /* Convert to a normalized offset. */
}

/*
=========================================================================================================================
 *** rf_wiener_apply ***
 Wiener MMSE channel estimation by application of the precomputed filter.
=========================================================================================================================

 Description:
     This function produces the MMSE channel estimate at all subcarriers by applying the precomputed Wiener filter to
     the pilot observations. The filter matrix combines the all-to-pilot and pilot-to-pilot channel correlations with
     the noise variance; that combination is computed offline from the channel statistics and remains constant while
     the statistics hold, so the deployable per-symbol operation reduces to one matrix-vector product. The product
     smooths the noisy pilot estimates and interpolates them to every subcarrier in a single step. The reference
     applies the same filter per transmit antenna and per receive antenna; this function performs the operation for one
     such antenna pair, and the caller loops over the pairs.

 Input:
     W          Precomputed Wiener filter, Nfft rows by Np columns, stored row by row.
     h_pilots   Pilot-position channel observations for this antenna pair, length Np.
     Nfft       Number of subcarriers (rows of the filter).
     Np         Number of pilot subcarriers (columns of the filter).

 Output:
     h_all      MMSE channel estimate at all Nfft subcarriers (caller-allocated).
=========================================================================================================================
*/
void rf_wiener_apply(const cplx_t *W, const cplx_t *h_pilots, size_t Nfft, size_t Np, cplx_t *h_all)
{
    for (size_t k = 0; k < Nfft; ++k) {               /* One output subcarrier per row of the filter. */
        cplx_t acc = cx(0.0, 0.0);                    /* The filtered estimate at subcarrier k. */
        for (size_t p = 0; p < Np; ++p) {             /* Combine all pilot observations. */
            acc = cx_add(acc, cx_mul(W[k * Np + p], h_pilots[p]));  /* Filter row times pilot vector. */
        }
        h_all[k] = acc;                               /* Store the estimate. */
    }
}
