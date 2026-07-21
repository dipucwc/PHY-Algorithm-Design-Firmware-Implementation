/*
=========================================================================================================================
 *** rf_sync ***
 OFDM timing and carrier-frequency-offset (CFO) synchronization.
=========================================================================================================================

 Description:
     This file implements the frame synchronization stage of the OFDM receiver. Synchronization is the first operation
     the receiver performs, because until the frame boundary and the carrier frequency are known, the FFT cannot be
     placed on the correct samples and the subcarriers cannot be demodulated. The file contains the four functions that
     establish this alignment: the Schmidl-Cox timing metric, the timing-peak detection, the coarse carrier-frequency-
     offset estimation, and the phase-ramp correction that removes the estimated offset from the samples.

     The complete procedure operates as follows. The transmitted preamble is constructed with two identical time-domain
     halves. The timing metric slides a two-half window across the received samples and, at every candidate start
     position, correlates the first half of the window against the second half and normalizes the squared correlation
     by the squared energy of the second half. Where the window is aligned with the preamble the two halves match and
     the metric reaches its maximum, so the peak position of the metric is the frame timing; the peak detection locates
     that maximum with a single pass. The same correlation also carries the frequency information: a carrier offset of
     epsilon subcarrier spacings rotates the second half relative to the first by a phase of pi times epsilon, because
     the halves are separated by one half symbol. The coarse-offset estimator therefore reads the phase angle of the
     correlation at the detected peak and divides it by pi, giving an estimate that is unambiguous over plus or minus
     one subcarrier spacing. Finally, the correction function multiplies the received samples by a phase ramp whose
     angle grows linearly with the sample index at the estimated rate but with the opposite sign, which cancels the
     offset and restores the subcarrier orthogonality that the FFT requires. The same ramp function, called with a
     positive offset, serves the simulation as the transmit-side impairment model.

 Input / Output:
     Given per function below.

 Supporting files:
     header      rf_sync.h        (declares the four functions in this file)
     header      rf_complex.h     (complex type and complex add / multiply / conjugate / angle)
     reference   schmidl_cox_metric.m, estimate_coarse_cfo.m, apply_cfo.m
     calls       none (uses only the inline helpers in rf_complex.h)
=========================================================================================================================
*/
#include "rf_sync.h"

/*
=========================================================================================================================
 *** rf_schmidl_cox_metric ***
 Normalized Schmidl-Cox timing metric over the search range.
=========================================================================================================================

 Description:
     This function computes the timing metric at every candidate frame-start position. The procedure at each position
     is the same: the first and second halves of a sliding window are correlated sample by sample, the energy of the
     second half is accumulated alongside, and the metric is formed as the squared correlation magnitude divided by the
     squared energy. The normalization bounds the metric between zero and one and makes it independent of the received
     signal level, so a fixed detection logic works at any SNR. The complex correlation values are stored as well,
     because the coarse-offset estimator reads its phase from them at the detected peak, which avoids recomputing the
     correlation a second time.

 Input:
     rx             Received time-domain samples.
     L              Half-symbol length equal to the FFT size divided by two.
     preamble_len   Preamble length in samples.
     cp_len         Cyclic-prefix length in samples.
     frame_len      Total received frame length in samples.

 Output:
     lambda[]       Normalized timing metric over the search range (caller-allocated).
     m_sc[]         Complex autocorrelation over the search range (caller-allocated).
     return value   search_len, the number of evaluated timing positions.
=========================================================================================================================
*/
size_t rf_schmidl_cox_metric(const cplx_t *rx, size_t L,
                             size_t preamble_len, size_t cp_len, size_t frame_len,
                             double *lambda, cplx_t *m_sc)
{
    size_t search_len = preamble_len + cp_len + 1;    /* Number of candidate start positions to evaluate. */

    if (search_len > frame_len - 2 * L)               /* Limit the search to the samples actually available. */
        search_len = frame_len - 2 * L;

    for (size_t d = 0; d < search_len; ++d) {         /* Evaluate each candidate position d. */

        cplx_t M = cx(0.0, 0.0);                      /* Correlation of the two window halves at this position. */
        double P = 0.0;                               /* Energy of the second half at this position. */

        for (size_t i = 0; i < L; ++i) {              /* Accumulate across the half-symbol window. */
            cplx_t r1 = rx[d + i];                    /* Sample from the first half. */
            cplx_t r2 = rx[d + L + i];                /* Corresponding sample from the second half. */
            M = cx_add(M, cx_mul(cx_conj(r1), r2));   /* Correlation term: conj(first) times second. */
            P += cx_abs2(r2);                         /* Energy term for the normalization. */
        }

        m_sc[d] = M;                                  /* Store the correlation for the offset estimator. */

        double den = P * P;                           /* Squared energy as the normalizer. */
        if (den < 1e-12) den = 1e-12;                 /* Protect against division by zero. */
        lambda[d] = cx_abs2(M) / den;                 /* Normalized metric, bounded in [0, 1]. */
    }

    return search_len;                                /* Number of positions evaluated. */
}

/*
=========================================================================================================================
 *** rf_detect_timing ***
 Index of the metric peak.
=========================================================================================================================

 Description:
     This function returns the frame-start position. Because the timing metric reaches its maximum where the sliding
     window is aligned with the preamble, the detection reduces to locating the largest value in the metric, which a
     single pass over the search range accomplishes.

 Input:
     lambda       Normalized metric over the search range.
     search_len   Number of evaluated positions.

 Output:
     return value   Index of the peak (zero-based).
=========================================================================================================================
*/
size_t rf_detect_timing(const double *lambda, size_t search_len)
{
    size_t best = 0;                                  /* Index of the largest value found so far. */
    double best_val = lambda[0];                      /* The largest value found so far. */

    for (size_t d = 1; d < search_len; ++d) {         /* Scan the remaining positions. */
        if (lambda[d] > best_val) {                   /* A larger metric value is found. */
            best_val = lambda[d];                     /* Update the value. */
            best = d;                                 /* Update the index. */
        }
    }

    return best;                                      /* The peak index is the frame timing. */
}

/*
=========================================================================================================================
 *** rf_estimate_coarse_cfo ***
 Coarse carrier-frequency offset from the autocorrelation phase.
=========================================================================================================================

 Description:
     This function converts the correlation phase at the detected timing into a frequency-offset estimate. The two
     preamble halves are separated by one half symbol, so a normalized offset of epsilon subcarrier spacings produces a
     phase of pi times epsilon on their correlation. The estimate is therefore the phase angle of the stored
     correlation at the peak, divided by pi. Its unambiguous range is plus or minus one subcarrier spacing, which is
     the coarse acquisition range; the residual error inside that range is refined later by the fine estimator that
     operates on pilot phase drift.

 Input:
     m_sc    Complex autocorrelation over the search range.
     d_hat   Detected timing index.

 Output:
     return value   Coarse offset in subcarrier spacings.
=========================================================================================================================
*/
double rf_estimate_coarse_cfo(const cplx_t *m_sc, size_t d_hat)
{
    return cx_angle(m_sc[d_hat]) / M_PI;              /* Phase-to-offset conversion. */
}

/*
=========================================================================================================================
 *** rf_apply_cfo ***
 Apply a carrier-frequency-offset phase ramp to a time-domain signal.
=========================================================================================================================

 Description:
     This function applies a linearly growing phase to the input samples. A carrier-frequency offset appears in the
     time domain as exactly such a phase ramp, with the phase advancing by two pi times the normalized offset per FFT
     length of samples. The function therefore serves two purposes with one implementation: called with a positive
     offset it models the impairment on the transmitted signal, and called with the negative of the estimated offset it
     performs the correction on the received signal, cancelling the rotation sample by sample.

 Input:
     in        Input samples.
     n         Number of samples.
     epsilon   Normalized offset in subcarrier spacings.
     Nfft      FFT size that sets the phase increment per sample.

 Output:
     out       Output samples with the phase ramp applied (caller-allocated).
=========================================================================================================================
*/
void rf_apply_cfo(const cplx_t *in, size_t n, double epsilon, size_t Nfft, cplx_t *out)
{
    for (size_t i = 0; i < n; ++i) {                  /* Rotate each sample by its ramp phase. */
        double ph = 2.0 * M_PI * epsilon * (double)i / (double)Nfft;  /* Phase at sample index i. */
        cplx_t rot = cx(cos(ph), sin(ph));            /* Unit rotation exp(j * phase). */
        out[i] = cx_mul(in[i], rot);                  /* Apply the rotation. */
    }
}
