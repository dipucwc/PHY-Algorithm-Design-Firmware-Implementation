/*
=========================================================================================================================
 *** test_quality ***
 Golden-vector test for the receiver-side quality estimation (post-equalization SINR and the quality report).
=========================================================================================================================

 Description:
     This test verifies that the quality-estimation kernels produce the same results as the reference on the same
     inputs. The quantities under test are the per-stream post-equalization SINR computed from the estimated channel
     and the per-layer, per-candidate effective-SINR quality report. The purpose of the test is to establish that the
     measurement chain feeding the closed loop reproduces the reference, because every selection decision of the
     transmitter rests on these numbers.

     The complete procedure runs in three steps. In the first step, the test reads the SINR vector file, in which each
     line carries one case: the antenna dimensions, the noise variance, the symbol energy, the estimated channel, and
     the per-stream reference SINR computed by the export script from the reference formula. Each case is evaluated by
     running the C kernel on the identical channel and comparing every stream within a relative tolerance of one part
     in a hundred thousand, which admits only floating-point rounding across the matrix inversion. In the second step,
     the test reads the report vector file, which carries one two-layer SINR profile with the reference nine-candidate
     report per layer, runs the C report builder, and compares every entry within 0.02 dB; this wider tolerance covers
     the Q16.16 fixed-point mapping against the double-precision reference. In the third step, the test reports one
     summary line with the case counts and the largest deviations, and returns zero only when every comparison holds.

 Input:
     vectors/quality_vectors.csv          Per case: dimensions, noise variance, symbol energy, channel, reference SINR.
     vectors/quality_report_vectors.csv   One profile with the reference per-layer, per-candidate report.

 Output:
     return value   Zero if the test passes, one if it fails.
     stdout         One line with the case counts, the largest errors, and PASS or FAIL.

 Supporting files:
     header      rf_quality.h (the kernels under test)
     reference   estimate_post_eq_sinr.m, estimate_quality_report.m
     vectors     written by scripts/export_vectors.py, which reproduces the reference algorithms
=========================================================================================================================
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "rf_quality.h"

/* parse_c: read "re;im;..." pairs into a complex array with an independent tokenizer state. */
static int parse_c(char *s, cplx_t *out)
{
    int n = 0; char *save = NULL;
    char *p = strtok_r(s, ";", &save);
    while (p) {
        out[n].re = atof(p); p = strtok_r(NULL, ";", &save);
        if (!p) break;
        out[n].im = atof(p); p = strtok_r(NULL, ";", &save);
        ++n;
    }
    return n;
}

/* parse_d: read ";"-separated real values into a double array. */
static int parse_d(char *s, double *out)
{
    int n = 0; char *save = NULL;
    for (char *p = strtok_r(s, ";", &save); p; p = strtok_r(NULL, ";", &save)) out[n++] = atof(p);
    return n;
}

int main(void)
{
    int fails = 0; double max_sinr_rel = 0.0, max_rep_db = 0.0;  /* Counters and the worst deviations. */

    /* Step 1: the per-stream SINR cases. */
    FILE *f = fopen("vectors/quality_vectors.csv", "r");
    if (!f) { printf("FAIL: no quality_vectors\n"); return 2; }
    static char line[65536];
    if (!fgets(line, sizeof line, f)) return 2;          /* Header. */
    int scases = 0;
    while (fgets(line, sizeof line, f)) {                /* One case per line. */
        char *save = NULL;
        int Nr = atoi(strtok_r(line, ",", &save));       /* Receive antennas. */
        int Nt = atoi(strtok_r(NULL, ",", &save));       /* Transmit antennas. */
        double nvar = atof(strtok_r(NULL, ",", &save));  /* Noise variance. */
        double Es   = atof(strtok_r(NULL, ",", &save));  /* Symbol energy. */
        char *Hs = strtok_r(NULL, ",", &save);           /* Channel field. */
        char *ss = strtok_r(NULL, ",", &save);           /* Reference SINR field. */
        cplx_t H[256]; double sref[16], sc[16];
        parse_c(Hs, H); parse_d(ss, sref);
        rf_post_eq_sinr(H, (size_t)Nr, (size_t)Nt, nvar, Es, sc);  /* Run the kernel. */
        for (int l = 0; l < Nt; ++l) {                   /* Compare each stream relatively. */
            double rel = fabs(sc[l] - sref[l]) / fmax(fabs(sref[l]), 1e-12);
            if (rel > max_sinr_rel) max_sinr_rel = rel;
            if (rel > 1e-5) ++fails;
        }
        ++scases;
    }
    fclose(f);

    /* Step 2: the quality-report case. */
    f = fopen("vectors/quality_report_vectors.csv", "r");
    if (!f) { printf("FAIL: no quality_report_vectors\n"); return 2; }
    if (!fgets(line, sizeof line, f)) return 2;          /* Header. */
    if (!fgets(line, sizeof line, f)) return 2;          /* The single data line. */
    char *save = NULL;
    int Nt2   = atoi(strtok_r(line, ",", &save));        /* Layers. */
    int Nfft2 = atoi(strtok_r(NULL, ",", &save));        /* Subcarriers per profile. */
    char *ps = strtok_r(NULL, ",", &save);               /* The SINR profile. */
    char *rs = strtok_r(NULL, ",", &save);               /* The reference report. */
    static double prof[1024], rref[64];
    parse_d(ps, prof); parse_d(rs, rref);
    static q16_t rep[64];
    rf_quality_report(prof, (size_t)Nt2, (size_t)Nfft2, rep);  /* Run the report builder. */
    for (int i = 0; i < Nt2 * 9; ++i) {                  /* Compare every entry in decibels. */
        double e = fabs(rf_q16_to_double(rep[i]) - rref[i]);
        if (e > max_rep_db) max_rep_db = e;
        if (e > 0.02) ++fails;                            /* Fixed-point mapping tolerance. */
    }
    fclose(f);

    /* Step 3: the summary line and the exit status. */
    printf("[test_quality] %d SINR cases (max rel %.1e) + report (max %.4f dB) -> %s\n",
           scases, max_sinr_rel, max_rep_db, fails ? "FAIL" : "PASS");
    return fails ? 1 : 0;
}
