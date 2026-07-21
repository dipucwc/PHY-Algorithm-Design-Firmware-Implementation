/*
=========================================================================================================================
 *** test_sync ***
 Golden-vector test for the synchronization kernels (timing detection and coarse carrier-frequency offset).
=========================================================================================================================

 Description:
     This test verifies that the C synchronization kernels produce the same results as the MATLAB reference when both
     are given the identical input frame. The two quantities under test are the detected frame-timing index and the
     coarse carrier-frequency-offset estimate, which together form the output of the synchronization stage. The purpose
     of the test is to establish that the port from MATLAB to C introduced no algorithmic change: if the same samples
     go in and the same numbers come out, the C implementation is a faithful reproduction of the reference.

     The complete procedure runs in four steps. In the first step, the test reads the scenario file, which contains the
     frame dimensions (FFT size, half-symbol length, cyclic-prefix length, preamble length, and frame length) together
     with the two reference results that the export script computed from the MATLAB algorithm: the expected timing
     index and the expected coarse offset. In the second step, the test reads the received frame itself, sample by
     sample as real and imaginary pairs, so that the C kernels operate on exactly the samples the reference operated
     on. In the third step, the test executes the chain under test in the same order as the receiver: the Schmidl-Cox
     metric is computed over the search range, the timing peak is detected, and the coarse offset is estimated from the
     correlation phase at that peak. In the fourth step, the results are compared against the reference values: the
     timing index must match exactly, because it is an integer position, and the coarse offset must agree within a
     tolerance of one part in ten thousand, which absorbs only the difference in floating-point rounding between the
     two environments. The test reports one summary line and returns zero when both checks hold, so that the build
     system can run it automatically and fail the build on any mismatch.

 Input:
     vectors/sync_vectors.csv   Scenario parameters and the reference timing index and offset.
     vectors/sync_frame.csv     The received frame samples, real and imaginary.

 Output:
     return value   Zero if the test passes, one if it fails.
     stdout         One line with the timing index, the offset error, and PASS or FAIL.

 Supporting files:
     header      rf_sync.h (the kernels under test)
     reference   schmidl_cox_metric.m, estimate_coarse_cfo.m
     vectors     written by scripts/export_vectors.py, which reproduces the reference algorithm
=========================================================================================================================
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "rf_sync.h"

int main(void)
{
    /* Step 1: read the scenario parameters and the two reference results. */
    FILE *f = fopen("vectors/sync_vectors.csv", "r");     /* Open the scenario file. */
    if (!f) { printf("FAIL: no sync_vectors\n"); return 2; }  /* The vectors must exist. */
    char line[512];
    if (!fgets(line, sizeof line, f)) return 2;           /* Skip the header line. */
    if (!fgets(line, sizeof line, f)) return 2;           /* Read the single data line. */

    int Nfft   = atoi(strtok(line, ","));                 /* FFT size. */
    int L      = atoi(strtok(NULL, ","));                 /* Half-symbol length. */
    int cp     = atoi(strtok(NULL, ","));                 /* Cyclic-prefix length. */
    int plen   = atoi(strtok(NULL, ","));                 /* Preamble length. */
    int flen   = atoi(strtok(NULL, ","));                 /* Frame length. */
    strtok(NULL, ",");                                    /* Skip the true offset column. */
    int d_ref      = atoi(strtok(NULL, ","));             /* Reference timing index. */
    double eps_ref = atof(strtok(NULL, ","));             /* Reference coarse offset. */
    fclose(f);

    /* Step 2: read the received frame so the C kernels see exactly the reference input. */
    cplx_t *rx = malloc(sizeof(cplx_t) * (size_t)flen);   /* Buffer for the frame. */
    f = fopen("vectors/sync_frame.csv", "r");             /* Open the frame file. */
    if (!fgets(line, sizeof line, f)) return 2;           /* Skip the header. */
    int i = 0;
    while (fgets(line, sizeof line, f) && i < flen) {     /* One sample per line. */
        rx[i].re = atof(strtok(line, ","));               /* Real part. */
        rx[i].im = atof(strtok(NULL, ","));               /* Imaginary part. */
        ++i;
    }
    fclose(f);

    /* Step 3: run the chain under test in the receiver order. */
    double *lambda = malloc(sizeof(double) * (size_t)flen);  /* Timing-metric buffer. */
    cplx_t *m_sc   = malloc(sizeof(cplx_t) * (size_t)flen);  /* Correlation buffer. */

    size_t slen  = rf_schmidl_cox_metric(rx, (size_t)L, (size_t)plen, (size_t)cp,  /* The metric. */
                                         (size_t)flen, lambda, m_sc);
    size_t d_hat = rf_detect_timing(lambda, slen);        /* The timing peak. */
    double eps_coarse = rf_estimate_coarse_cfo(m_sc, d_hat);  /* The coarse offset. */
    (void)Nfft;                                           /* Parsed for completeness; not needed further. */

    /* Step 4: compare against the reference and report. */
    int fails = 0;                                        /* Failure counter. */
    if ((int)d_hat != d_ref) {                            /* The integer timing must match exactly. */
        printf("  timing d_hat=%zu ref=%d\n", d_hat, d_ref); ++fails;
    }
    if (fabs(eps_coarse - eps_ref) > 1e-4) {              /* The offset must agree within the tolerance. */
        printf("  coarse CFO=%.6f ref=%.6f\n", eps_coarse, eps_ref); ++fails;
    }

    printf("[test_sync] timing d_hat=%zu, coarse CFO err=%.2e -> %s\n",  /* The summary line. */
           d_hat, fabs(eps_coarse - eps_ref), fails ? "FAIL" : "PASS");

    free(rx); free(lambda); free(m_sc);                   /* Release the buffers. */
    return fails ? 1 : 0;                                 /* Zero on pass, one on fail. */
}
