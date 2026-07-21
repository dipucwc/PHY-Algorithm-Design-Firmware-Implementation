/*
=========================================================================================================================
 *** test_chanest ***
 Golden-vector test for the channel-estimation kernels (LS pilots, fine offset, Wiener application).
=========================================================================================================================

 Description:
     This test verifies that the three channel-estimation kernels produce the same results as the reference on the same
     inputs. The quantities under test are the least-squares channel estimate at the pilot subcarriers, the fine
     carrier-offset estimate from the pilot phase drift of two consecutive symbols, and the Wiener MMSE estimate formed
     by applying a precomputed filter to the pilot observations. The purpose of the test is to establish that the port
     of the pilot-processing stage introduced no algorithmic change.

     The complete procedure runs in three steps. In the first step, the test reads the single vector line, which
     contains the pilot dimensions, the received and transmitted pilots with the reference least-squares estimate, the
     pilot observations of two consecutive symbols with the reference fine-offset value, and a filter matrix with the
     reference filtered output. In the second step, the three C kernels are executed on those inputs: the least-squares
     division, the phase-drift estimate, and the filter application. In the third step, every output is compared with
     its reference within a tolerance of one part in a million for the complex arrays and the scalar offset, which
     admits only floating-point rounding. The test reports one summary line and returns zero when all three kernels
     agree.

 Input:
     vectors/chanest_vectors.csv   The pilot scenario with the three reference outputs.

 Output:
     return value   Zero if the test passes, one if it fails.
     stdout         One line with the largest error and PASS or FAIL.

 Supporting files:
     header      rf_chanest.h (the kernels under test)
     reference   ls_pilot_estimate.m, estimate_fine_cfo.m, wiener_mmse_estimate.m
     vectors     written by scripts/export_vectors.py, which reproduces the reference algorithms
=========================================================================================================================
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "rf_chanest.h"

/* parse: read "re;im;..." pairs into a complex array with an independent tokenizer state. */
static int parse(char *s, cplx_t *out)
{
    int n = 0; char *save = NULL;                        /* Count and tokenizer state. */
    char *p = strtok_r(s, ";", &save);                   /* First token. */
    while (p) {                                          /* Read pairs to the end. */
        out[n].re = atof(p); p = strtok_r(NULL, ";", &save);
        if (!p) break;
        out[n].im = atof(p); p = strtok_r(NULL, ";", &save);
        ++n;
    }
    return n;
}

int main(void)
{
    /* Step 1: read the scenario and the three references. */
    FILE *f = fopen("vectors/chanest_vectors.csv", "r");  /* The golden vectors. */
    if (!f) { printf("FAIL: no chanest_vectors\n"); return 2; }
    static char line[262144];
    if (!fgets(line, sizeof line, f)) return 2;          /* Header. */
    if (!fgets(line, sizeof line, f)) return 2;          /* The single data line. */

    char *save = NULL;
    int Np   = atoi(strtok_r(line, ",", &save));         /* Number of pilots. */
    int Nfft = atoi(strtok_r(NULL, ",", &save));         /* Number of subcarriers. */
    int slen = atoi(strtok_r(NULL, ",", &save));         /* Symbol length. */
    char *rxs = strtok_r(NULL, ",", &save);              /* Received pilots. */
    char *txs = strtok_r(NULL, ",", &save);              /* Transmitted pilots. */
    char *hls = strtok_r(NULL, ",", &save);              /* Reference LS estimate. */
    char *p1s = strtok_r(NULL, ",", &save);              /* Pilots of symbol one. */
    char *p2s = strtok_r(NULL, ",", &save);              /* Pilots of symbol two. */
    double eps_ref = atof(strtok_r(NULL, ",", &save));   /* Reference fine offset. */
    char *Ws  = strtok_r(NULL, ",", &save);              /* Filter matrix. */
    char *has = strtok_r(NULL, ",", &save);              /* Reference filtered output. */

    static cplx_t rxp[64], txp[64], hls_ref[64], p1[64], p2[64], W[4096], hall_ref[256];
    parse(rxs, rxp); parse(txs, txp); parse(hls, hls_ref);
    parse(p1s, p1);  parse(p2s, p2);  parse(Ws, W); parse(has, hall_ref);
    fclose(f);

    /* Step 2: run the three kernels on the identical inputs. */
    static cplx_t hls_c[64], hall_c[256];
    rf_ls_pilot_estimate(rxp, txp, (size_t)Np, hls_c);   /* Least-squares estimate. */
    double eps_c = rf_estimate_fine_cfo(p1, p2, (size_t)Np, (size_t)Nfft, (size_t)slen);  /* Fine offset. */
    rf_wiener_apply(W, hls_ref, (size_t)Nfft, (size_t)Np, hall_c);  /* Filter application. */

    /* Step 3: compare everything within the rounding tolerance. */
    int fails = 0; double maxerr = 0.0;                  /* Counters. */
    for (int k = 0; k < Np; ++k) {                       /* The LS estimates. */
        double e = cx_abs(cx_sub(hls_c[k], hls_ref[k]));
        if (e > maxerr) maxerr = e; if (e > 1e-6) ++fails;
    }
    double ee = fabs(eps_c - eps_ref);                   /* The fine offset. */
    if (ee > maxerr) maxerr = ee; if (ee > 1e-6) ++fails;
    for (int k = 0; k < Nfft; ++k) {                     /* The filtered estimates. */
        double e = cx_abs(cx_sub(hall_c[k], hall_ref[k]));
        if (e > maxerr) maxerr = e; if (e > 1e-6) ++fails;
    }

    printf("[test_chanest] LS + fine CFO + Wiener apply, max|err|=%.2e -> %s\n",  /* Summary. */
           maxerr, fails ? "FAIL" : "PASS");
    return fails ? 1 : 0;                                /* Zero on pass. */
}
