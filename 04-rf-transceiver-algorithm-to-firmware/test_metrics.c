/*
=========================================================================================================================
 *** test_metrics ***
 Golden-vector test for the link-quality metrics and the threshold modulation selection.
=========================================================================================================================

 Description:
     This test verifies that the measurement and adaptation helpers produce the same results as the MATLAB reference.
     The quantities under test are the post-equalization SINR, the error vector magnitude, and the threshold-based
     modulation selection. The purpose of the test is to establish that the ported metrics report the identical
     numbers, because these numbers drive both the reported link quality and the open-loop adaptation decision.

     The complete procedure runs in three steps. In the first step, the test reads the metrics vector file, in which
     every line carries one case: the symbol count, the reference and received symbol sets, and the reference SINR and
     EVM computed by the export script. Each case is evaluated by running the two C metrics on the same symbols and
     comparing within a tolerance of one part in ten thousand, which admits only floating-point rounding. In the second
     step, the test reads the modulation vector file, in which every line carries an operating SNR and the reference
     modulation order and bits per symbol, including values placed exactly on the 8 and 18 dB thresholds so that the
     boundary behaviour is pinned; the C selector must match these integers exactly. In the third step, the test
     reports one summary line with both case counts and the largest metric error, and returns zero only when every
     comparison holds.

 Input:
     vectors/metrics_vectors.csv   Per case: symbol count, reference and received symbols, reference SINR and EVM.
     vectors/amc_vectors.csv       Per case: an SNR value and the reference modulation order and bits per symbol.

 Output:
     return value   Zero if the test passes, one if it fails.
     stdout         One line with the case counts, the largest metric error, and PASS or FAIL.

 Supporting files:
     header      rf_metrics.h (the functions under test)
     reference   compute_sinr.m, compute_evm.m, amc_select_modulation.m
     vectors     written by scripts/export_vectors.py, which reproduces the reference algorithms
=========================================================================================================================
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "rf_metrics.h"

/*
 parse: read a ";"-separated "re;im;..." list into a complex array with an independent tokenizer state.
     Input : s     the string field.
     Output: out   the filled array; returns the number of complex values read.
*/
static int parse(char *s, cplx_t *out)
{
    int n = 0; char *save = NULL;                        /* Count and tokenizer state. */
    char *p = strtok_r(s, ";", &save);                   /* First token. */
    while (p) {                                          /* Read pairs until the string ends. */
        out[n].re = atof(p); p = strtok_r(NULL, ";", &save);  /* Real part. */
        if (!p) break;                                   /* Guard. */
        out[n].im = atof(p); p = strtok_r(NULL, ";", &save);  /* Imaginary part. */
        ++n;                                             /* One value done. */
    }
    return n;
}

int main(void)
{
    int fails = 0; double maxerr = 0.0;                  /* Failure counter and worst error. */

    /* Step 1: the SINR and EVM cases. */
    FILE *f = fopen("vectors/metrics_vectors.csv", "r"); /* Open the SINR and EVM cases. */
    if (!f) { printf("FAIL: no metrics_vectors\n"); return 2; }
    static char line[65536];
    if (!fgets(line, sizeof line, f)) return 2;          /* Skip the header. */

    int mcases = 0;
    while (fgets(line, sizeof line, f)) {                /* One case per line. */
        char *save = NULL;
        int n = atoi(strtok_r(line, ",", &save));        /* Symbol count. */
        char *txs = strtok_r(NULL, ",", &save);          /* Reference symbols. */
        char *rxs = strtok_r(NULL, ",", &save);          /* Received symbols. */
        double sinr_ref = atof(strtok_r(NULL, ",", &save));  /* Reference SINR. */
        double evm_ref  = atof(strtok_r(NULL, ",", &save));  /* Reference EVM. */
        cplx_t tx[64], rx[64];                           /* Symbol buffers. */
        parse(txs, tx); parse(rxs, rx);                  /* Fill them. */

        double s = rf_compute_sinr_db(tx, rx, (size_t)n);/* Compute SINR. */
        double e = rf_compute_evm_pct(tx, rx, (size_t)n);/* Compute EVM. */
        if (fabs(s - sinr_ref) > maxerr) maxerr = fabs(s - sinr_ref);  /* Track worst SINR error. */
        if (fabs(e - evm_ref)  > maxerr) maxerr = fabs(e - evm_ref);   /* Track worst EVM error. */
        if (fabs(s - sinr_ref) > 1e-4 || fabs(e - evm_ref) > 1e-4) ++fails;  /* Count failures. */
        ++mcases;                                        /* One case done. */
    }
    fclose(f);

    /* Step 2: the threshold-modulation cases. */
    f = fopen("vectors/amc_vectors.csv", "r");           /* Open the modulation cases. */
    if (!fgets(line, sizeof line, f)) return 2;          /* Skip the header. */
    int acases = 0;
    while (fgets(line, sizeof line, f)) {                /* One case per line. */
        char *save = NULL;
        double snr = atof(strtok_r(line, ",", &save));   /* Operating SNR. */
        int M_ref = atoi(strtok_r(NULL, ",", &save));    /* Reference modulation order. */
        int b_ref = atoi(strtok_r(NULL, ",", &save));    /* Reference bits per symbol. */
        int bps; int M = rf_amc_select_modulation(snr, &bps);  /* Run the selector. */
        if (M != M_ref || bps != b_ref) {                /* Must match exactly. */
            printf("  snr=%.2f M=%d/%d bps=%d/%d\n", snr, M, M_ref, bps, b_ref); ++fails;
        }
        ++acases;                                        /* One case done. */
    }
    fclose(f);

    /* Step 3: the summary line and the exit status. */
    printf("[test_metrics] %d SINR/EVM + %d AMC cases, max|err|=%.2e -> %s\n",  /* Report the result. */
           mcases, acases, maxerr, fails ? "FAIL" : "PASS");
    return fails ? 1 : 0;                                /* Exit status. */
}
