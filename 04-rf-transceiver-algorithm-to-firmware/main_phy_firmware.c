/*
=========================================================================================================================
 *** main_phy_firmware ***
 Main program for the Project 1 RF PHY receiver firmware (8x8 and 16x16 MIMO-OFDM).
=========================================================================================================================

 Description:
     This is the main program of the Project 1 receiver firmware. It executes the deployable receiver kernels of the
     8x8 and 16x16 MIMO-OFDM physical layer, ported from the verified MATLAB link-level model, once on a single frame so
     that the complete receive chain is visible in one file. The Monte Carlo SNR sweep and the plotting of the MATLAB
     model are evaluation infrastructure and are not part of the firmware; the firmware executes the per-frame
     operations only.

     The complete procedure operates as follows, in the receive order of the reference. The synchronization stage computes the Schmidl-Cox
     timing metric, detects the timing peak, estimates the coarse carrier-frequency offset from the correlation phase,
     and removes the offset with a phase ramp. The equalization stage recovers the transmitted symbols at one
     subcarrier with the MMSE detector, which solves the regularized system built from the channel estimate. The
     measurement stage computes the post-equalization SINR and the error vector magnitude and applies the threshold
     modulation rule of the baseline. Each stage calls one supporting kernel, and each kernel corresponds to one MATLAB
     reference function.

 Supporting functions:

     rf_schmidl_cox_metric
         Computes the normalized Schmidl-Cox timing metric from the received signal (rf_sync.c).

     rf_detect_timing
         Returns the frame-start position as the index of the metric peak (rf_sync.c).

     rf_estimate_coarse_cfo
         Estimates the coarse carrier-frequency offset from the autocorrelation phase at the peak (rf_sync.c).

     rf_apply_cfo
         Applies a carrier-frequency-offset phase ramp for impairment or correction (rf_sync.c).

     rf_ls_pilot_estimate
         Forms the least-squares channel estimate at the pilot subcarriers (rf_chanest.c).

     rf_estimate_fine_cfo
         Estimates the residual carrier offset from pilot phase drift between two symbols (rf_chanest.c).

     rf_mmse_equalize_soft
         Adds the unbiased estimate and per-stream noise variance for the soft decoder (rf_equalize.c).

     rf_wiener_apply
         Applies the precomputed Wiener filter to the pilot observations (rf_chanest.c).

     rf_zf_equalize
         Recovers the transmit symbols at one subcarrier with the zero-forcing detector (rf_equalize.c).

     rf_mmse_equalize
         Recovers the transmit symbols at one subcarrier with the MMSE detector (rf_equalize.c).

     rf_gram_plus_reg, rf_matched_filter, rf_solve
         Build H^H H and H^H y and solve the small system used by the equalizers (rf_matrix.c).

     rf_compute_sinr_db
         Computes the post-equalization signal-to-interference-plus-noise ratio in decibels (rf_metrics.c).

     rf_compute_evm_pct
         Computes the RMS error vector magnitude as a percentage (rf_metrics.c).

     rf_amc_select_modulation
         Selects the QAM modulation order from the operating SNR (rf_metrics.c).

 Input:
     (none)   The program is self-contained; it builds a tiny example frame and channel in code.

 Output:
     return value   Zero on normal completion.
     stdout         One line per pipeline stage showing the result (timing, coarse offset, SINR, EVM, modulation).

 Supporting files:
     header      rf_sync.h, rf_equalize.h, rf_metrics.h, rf_complex.h
     sources     rf_sync.c, rf_matrix.c, rf_equalize.c, rf_metrics.c
     reference   main_phy_simulation.m (the MATLAB main script this pipeline mirrors)
=========================================================================================================================
*/
#include <stdio.h>
#include <stdlib.h>
#include "rf_sync.h"
#include "rf_equalize.h"
#include "rf_metrics.h"

int main(void)
{
    /* ---- Stage 1: find the frame and fix the frequency -------------------------------------------------------- */

    const size_t Nfft = 64;                           /* FFT size for this small example frame. */
    const size_t L    = Nfft / 2;                     /* The preamble has two halves, each this long. */
    const size_t cp   = 16;                           /* Guard samples in front of each symbol. */
    const size_t plen = Nfft;                         /* Preamble length. */

    size_t frame_len = cp + plen + 64;                /* A short frame: guard, preamble, then some data. */
    cplx_t *rx     = malloc(sizeof(cplx_t) * frame_len);  /* The samples we received. */
    double *lambda = malloc(sizeof(double) * frame_len);  /* Room for the timing metric. */
    cplx_t *m_sc   = malloc(sizeof(cplx_t) * frame_len);  /* Room for the correlation. */

    /* Build a simple preamble whose two halves are identical, which is what the timing metric looks for. */
    for (size_t i = 0; i < frame_len; ++i) {
        double v = (double)((i * 7 + 3) % 5) - 2.0;   /* Any repeatable pattern works for the demo. */
        if (i >= cp && i < cp + L)                    /* First half of the preamble. */
            rx[i] = cx(v, -v);
        else if (i >= cp + L && i < cp + 2 * L)       /* Second half is a copy of the first. */
            rx[i] = cx(v, -v);
        else                                          /* Everything else is quiet. */
            rx[i] = cx(0.01, -0.01);
    }

    size_t slen  = rf_schmidl_cox_metric(rx, L, plen, cp, frame_len, lambda, m_sc);  /* Score every start position. */
    size_t d_hat = rf_detect_timing(lambda, slen);    /* The best-scoring position is the frame start. */
    double eps   = rf_estimate_coarse_cfo(m_sc, d_hat);  /* The correlation phase tells us the frequency error. */
    rf_apply_cfo(rx, frame_len, -eps, Nfft, rx);      /* Spin the samples back to cancel that error. */

    printf("sync   : timing index = %zu, coarse CFO = %.4f subcarrier spacings\n", d_hat, eps);

    /* ---- Stage 2: separate the antennas at one subcarrier ------------------------------------------------------ */

    const size_t Nr = 2, Nt = 2;                      /* A tiny two-by-two example so the numbers are easy to follow. */
    cplx_t H[4] = { cx(1.0, 0.0), cx(0.2, 0.1),       /* The channel that mixed the two streams. */
                    cx(0.1, -0.2), cx(0.9, 0.0) };
    cplx_t x[2] = { cx(1.0, 0.0), cx(-1.0, 0.0) };    /* What was actually sent. */
    cplx_t y[2];                                      /* What the antennas received: y = H x. */
    y[0] = cx_add(cx_mul(H[0], x[0]), cx_mul(H[1], x[1]));  /* First receive antenna. */
    y[1] = cx_add(cx_mul(H[2], x[0]), cx_mul(H[3], x[1]));  /* Second receive antenna. */

    cplx_t x_hat[2];                                  /* Where the recovered symbols go. */
    double noiseVar = 0.01;                           /* How much noise we assume (one over the linear SNR). */
    rf_mmse_equalize(H, Nr, Nt, y, noiseVar, x_hat);  /* Undo the mixing to get the streams back. */

    /* ---- Stage 3: measure the link and choose a modulation ---------------------------------------------------- */

    double sinr = rf_compute_sinr_db(x, x_hat, Nt);   /* How clean is the recovered signal? */
    double evm  = rf_compute_evm_pct(x, x_hat, Nt);   /* Same idea, expressed as a percentage error. */
    int bps;                                          /* Bits per symbol, filled in by the selector. */
    int M = rf_amc_select_modulation(20.0, &bps);     /* At a 20 dB link, which QAM order can we afford? */

    printf("equalize: recovered stream 0 = %.3f%+.3fj (true 1.000+0.000j)\n", x_hat[0].re, x_hat[0].im);
    printf("metrics : SINR = %.1f dB, EVM = %.2f%%, selected %d-QAM (%d bits/symbol)\n", sinr, evm, M, bps);

    free(rx); free(lambda); free(m_sc);               /* Give the memory back. */
    return 0;                                          /* Done. */
}
