/*
=========================================================================================================================
 *** test_equalize ***
 Golden-vector test for the zero-forcing, MMSE, and soft-output MMSE MIMO equalizers.
=========================================================================================================================

 Description:
     This test verifies that the three C detectors produce the same outputs as the MATLAB reference across a set of
     channels and SNR points. The quantities under test are the zero-forcing symbol estimate, the plain MMSE symbol
     estimate, the gain-corrected unbiased soft estimate, and the per-stream effective noise variance. The purpose of
     the test is to establish that the port introduced no algorithmic change in any of the detector paths, including
     the bias-removal step that the soft decoder depends on.

     The complete procedure runs in three steps. In the first step, the test reads the vector file, in which every line
     describes one case: the array dimensions, the noise variance, the channel matrix, the received vector, and the
     four reference outputs computed by the export script from the reference algorithms. In the second step, the test
     runs the three C detectors on the identical channel and received vector of each case. In the third step, every
     output element is compared against its reference value, the largest deviation across all cases is tracked, and any
     element deviating by more than one part in a million is counted as a failure; this tolerance admits only the
     floating-point rounding difference between the two environments. The test reports one summary line with the case
     count and the largest error, and returns zero only when every element of every case agrees.

 Input:
     vectors/equalize_vectors.csv   Per case: dimensions, noise variance, channel, received vector, and the reference
                                     zero-forcing, MMSE, soft, and noise-variance outputs.

 Output:
     return value   Zero if the test passes, one if it fails.
     stdout         One line with the number of cases, the largest error, and PASS or FAIL.

 Supporting files:
     header      rf_equalize.h (the detectors under test)
     reference   zf_equalize_mimo.m, mmse_equalize_mimo.m, mmse_equalize_soft.m
     vectors     written by scripts/export_vectors.py, which reproduces the reference algorithms
=========================================================================================================================
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "rf_equalize.h"

/*
=========================================================================================================================
 *** parse ***
 Read a ";"-separated list of real-imaginary pairs into a complex array.
=========================================================================================================================

 Description:
     This helper converts one CSV field of the form "re;im;re;im;..." into a complex array. It uses an independent
     tokenizer state so that it does not disturb the outer comma tokenizer that is walking the CSV line.

 Input:
     s     The string field to parse.

 Output:
     out   The filled complex array.
     return value   The number of complex values read.
=========================================================================================================================
*/
static int parse(char *s, cplx_t *out)
{
    int n = 0; char *save = NULL;                        /* Value count and tokenizer state. */
    char *p = strtok_r(s, ";", &save);                   /* First token. */
    while (p) {                                          /* Read real-imaginary pairs to the end. */
        out[n].re = atof(p); p = strtok_r(NULL, ";", &save);  /* Real part, then advance. */
        if (!p) break;                                   /* Guard against a missing imaginary part. */
        out[n].im = atof(p); p = strtok_r(NULL, ";", &save);  /* Imaginary part, then advance. */
        ++n;                                             /* One complex value completed. */
    }
    return n;
}

int main(void)
{
    /* Step 1: open the vector file and skip its header. */
    FILE *f = fopen("vectors/equalize_vectors.csv", "r");    /* The golden vectors. */
    if (!f) { printf("FAIL: no equalize_vectors\n"); return 2; }
    static char line[65536];
    if (!fgets(line, sizeof line, f)) return 2;          /* Header line. */

    int cases = 0, fails = 0; double maxerr = 0.0;       /* Counters and the worst deviation. */
    while (fgets(line, sizeof line, f)) {                /* One case per line. */

        /* Parse the case: dimensions, noise variance, and the five arrays. */
        char *save = NULL;
        strtok_r(line, ",", &save);                      /* Case identifier (unused). */
        int Nr = atoi(strtok_r(NULL, ",", &save));       /* Receive antennas. */
        int Nt = atoi(strtok_r(NULL, ",", &save));       /* Transmit antennas. */
        strtok_r(NULL, ",", &save);                      /* SNR column (unused). */
        double nvar = atof(strtok_r(NULL, ",", &save));  /* Noise variance. */
        char *Hs = strtok_r(NULL, ",", &save);           /* Channel field. */
        char *ys = strtok_r(NULL, ",", &save);           /* Received-vector field. */
        char *zs = strtok_r(NULL, ",", &save);           /* Reference zero-forcing field. */
        char *ms = strtok_r(NULL, ",", &save);           /* Reference MMSE field. */
        char *ss = strtok_r(NULL, ",", &save);           /* Reference soft-estimate field. */
        char *ns = strtok_r(NULL, ",", &save);           /* Reference noise-variance field. */

        cplx_t H[256], y[16], zf_ref[16], mmse_ref[16], soft_ref[16], x[16], xb[16], xs[16];
        double nv_ref[16], nv[16];
        parse(Hs, H); parse(ys, y); parse(zs, zf_ref); parse(ms, mmse_ref); parse(ss, soft_ref);
        { int k = 0; char *sv = NULL;                    /* The noise-variance field is real-valued. */
          for (char *p = strtok_r(ns, ";", &sv); p; p = strtok_r(NULL, ";", &sv)) nv_ref[k++] = atof(p); }

        /* Step 2: run the three detectors on the identical input. */
        rf_zf_equalize(H, (size_t)Nr, (size_t)Nt, y, x); /* Zero-forcing. */
        for (int k = 0; k < Nt; ++k) {                   /* Compare element by element. */
            double e = cx_abs(cx_sub(x[k], zf_ref[k]));
            if (e > maxerr) maxerr = e; if (e > 1e-6) ++fails;
        }

        rf_mmse_equalize(H, (size_t)Nr, (size_t)Nt, y, nvar, x);  /* Plain MMSE. */
        for (int k = 0; k < Nt; ++k) {
            double e = cx_abs(cx_sub(x[k], mmse_ref[k]));
            if (e > maxerr) maxerr = e; if (e > 1e-6) ++fails;
        }

        rf_mmse_equalize_soft(H, (size_t)Nr, (size_t)Nt, y, nvar, xb, xs, nv);  /* Soft-output MMSE. */
        for (int k = 0; k < Nt; ++k) {                   /* Step 3: compare the soft outputs too. */
            double e1 = cx_abs(cx_sub(xs[k], soft_ref[k]));   /* Unbiased estimate. */
            double e2 = fabs(nv[k] - nv_ref[k]);               /* Effective noise variance. */
            if (e1 > maxerr) maxerr = e1; if (e1 > 1e-6) ++fails;
            if (e2 > maxerr) maxerr = e2; if (e2 > 1e-6) ++fails;
        }
        ++cases;                                         /* One case completed. */
    }
    fclose(f);

    printf("[test_equalize] %d cases (ZF+MMSE+soft), max|err|=%.2e -> %s\n",  /* The summary line. */
           cases, maxerr, fails ? "FAIL" : "PASS");
    return fails ? 1 : 0;                                /* Zero on pass. */
}
