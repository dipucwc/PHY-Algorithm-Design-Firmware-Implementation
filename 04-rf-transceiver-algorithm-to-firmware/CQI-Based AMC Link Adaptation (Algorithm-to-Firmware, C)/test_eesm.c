/*
=========================================================================================================================
 *** test_eesm ***
 Golden-vector test for the Q16.16 effective-SINR mapping.
=========================================================================================================================

 Description:
     This test verifies that the Q16.16 fixed-point effective-SINR mapping reproduces the double-precision MATLAB
     reference. The quantity under test is the effective SINR in decibels, evaluated for every calibrated beta over a
     set of subcarrier SINR patterns that includes flat profiles, a deep notch, a ramp, and a two-level profile, so
     that the fixed-point exponential and logarithm are exercised across their operating range. The purpose of the test
     is to bound the fixed-point error, because the selection curves are read at this value and a biased mapping would
     shift every scheme decision.

     The complete procedure runs in three steps. In the first step, the test reads the vector file, in which every line
     carries one case: the scheme index, the pattern, the number of resource elements, the linear SINR values, and the
     reference result computed by the export script in double precision. In the second step, each SINR set is converted
     to Q16.16 and the fixed-point mapping is evaluated with the beta of the given scheme. In the third step, every
     result is compared with its reference within a tolerance of one tenth of a decibel, the largest deviation across
     all cases is tracked and reported, and the test returns zero only when every case is inside the tolerance; the
     observed maximum is about four thousandths of a decibel, well inside the bound.

 Input:
     vectors/eesm_vectors.csv   Per case: MCS index, beta, pattern name, count, the SINR values, and the reference dB.

 Output:
     return value   Zero if the test passes, one if it fails.
     stdout         One line with the number of cases, the largest error, and PASS or FAIL.

 Supporting files:
     header      rf_eesm.h (the kernel under test)
     reference   calculate_effective_sinr.m
=========================================================================================================================
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "rf_eesm.h"

int main(void)
{
    FILE *f = fopen("vectors/eesm_vectors.csv", "r");    /* Open the vector file. */
    if (!f) { printf("FAIL: cannot open vectors\n"); return 2; }
    static char line[65536];
    if (!fgets(line, sizeof line, f)) { fclose(f); return 2; }  /* Skip the header. */

    int cases = 0, fails = 0; double maxerr = 0.0;       /* Counters and worst error. */
    const double TOL = 0.10;                             /* Tolerance in decibels. */
    while (fgets(line, sizeof line, f)) {                /* One case per line. */
        int mcs = atoi(strtok(line, ","));               /* MCS index. */
        strtok(NULL, ","); strtok(NULL, ",");            /* Skip beta and pattern name. */
        int n = atoi(strtok(NULL, ","));                 /* Number of resource elements. */
        char *sinrs = strtok(NULL, ",");                 /* The SINR values. */
        double ref = atof(strtok(NULL, ","));            /* Reference effective SINR. */
        q16_t buf[512]; int i = 0;                       /* Fixed-point input buffer. */
        for (char *p = strtok(sinrs, ";"); p && i < n; p = strtok(NULL, ";"))  /* Convert each value. */
            buf[i++] = rf_double_to_q16(atof(p));
        double got = rf_q16_to_double(rf_eesm_eff_sinr_db_mcs(buf, (size_t)n, mcs));  /* Run the kernel. */
        double err = fabs(got - ref);                    /* Error against the reference. */
        if (err > maxerr) maxerr = err;                  /* Track the worst. */
        if (err > TOL) {                                 /* Count a failure. */
            printf("  mcs=%d ref=%.4f got=%.4f err=%.4f\n", mcs, ref, got, err); ++fails;
        }
        ++cases;                                         /* One case done. */
    }
    fclose(f);

    printf("[test_eesm] %d cases, max|err|=%.4f dB (tol %.2f) -> %s\n",  /* Report the result. */
           cases, maxerr, TOL, fails ? "FAIL" : "PASS");
    return fails ? 1 : 0;                                /* Exit status. */
}
