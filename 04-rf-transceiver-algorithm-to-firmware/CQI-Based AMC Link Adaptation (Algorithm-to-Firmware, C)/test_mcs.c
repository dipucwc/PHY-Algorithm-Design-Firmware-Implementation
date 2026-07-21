/*
=========================================================================================================================
 *** test_mcs ***
 Functional test for the BLER-constrained MCS selector and the curve interpolation.
=========================================================================================================================

 Description:
     This test verifies the behaviour of the BLER-constrained scheme selection and of the curve interpolation it relies
     on. Three properties are checked: the interpolation returns the correct value at a known point of a known curve,
     the selection picks the highest scheme at high SINR and falls back to the most robust scheme with the fallback
     status at low SINR, and the selection is monotone, meaning that raising the SINR never lowers the chosen scheme.
     The purpose of the test is to pin the decision logic itself, independently of any calibration data.

     The complete procedure runs in three steps. In the first step, the test constructs nine synthetic two-point
     calibration curves whose crossing SINR values are known by design, so every expected decision can be derived by
     hand. In the second step, the interpolation is queried exactly at a crossing, where the linear reading between the
     two points must give the midpoint value. In the third step, the selection is exercised three ways: with a high
     quality report that must select the top scheme, with a low report that must return scheme zero together with the
     fallback status, and with a fine SINR sweep from zero to thirty decibels during which the selected index must
     never decrease. The test reports one summary line and returns zero only when all the checks hold.

 Input:
     (none)   The curves and quality reports are built in code.

 Output:
     return value   Zero if the test passes, one if it fails.
     stdout         One line reporting PASS or FAIL.

 Supporting files:
     header      rf_mcs.h (the functions under test)
     reference   select_mcs_for_target_bler.m, interpolate_bler_curve.m
=========================================================================================================================
*/
#include <stdio.h>
#include <string.h>
#include "rf_mcs.h"

/* S: shorthand to make a Q16.16 value from a real number. */
static q16_t S(double d) { return rf_double_to_q16(d); }

int main(void)
{
    int fails = 0;                                       /* Failure counter. */

    static q16_t sinr[RF_NUM_MCS][2], bler[RF_NUM_MCS][2];  /* Two-point curves per MCS. */
    rf_bler_curve_t curves[RF_NUM_MCS];                  /* Curve descriptors. */
    double cross[RF_NUM_MCS] = {5,7,8,11,13,15,15,17,19};/* Target-crossing SINR per MCS. */
    for (int m = 0; m < RF_NUM_MCS; ++m) {               /* Build each curve. */
        sinr[m][0] = S(cross[m] - 2.0); bler[m][0] = S(0.50);  /* Low-SINR point. */
        sinr[m][1] = S(cross[m] + 2.0); bler[m][1] = S(0.00);  /* High-SINR point. */
        curves[m].sinr_db = sinr[m]; curves[m].bler = bler[m]; curves[m].npts = 2;
    }

    q16_t mid = rf_bler_interp(&curves[0], S(cross[0])); /* At the crossing, BLER should be halfway (0.25). */
    double midd = rf_q16_to_double(mid);
    if (midd < 0.24 || midd > 0.26) { printf("  interp mid=%.4f (want 0.25)\n", midd); ++fails; }

    q16_t target = S(0.10);                              /* The BLER target. */
    q16_t qr_hi[RF_NUM_MCS], qr_lo[RF_NUM_MCS];          /* High- and low-SINR quality reports. */
    for (int m = 0; m < RF_NUM_MCS; ++m) { qr_hi[m] = S(30.0); qr_lo[m] = S(0.0); }

    q16_t crit; rf_sel_status_t st;                      /* Selection outputs. */
    int hi = rf_mcs_select(qr_hi, 1, curves, target, 0, RF_CRIT_MEAN, &crit, &st);  /* High SINR. */
    if (hi != 8) { printf("  high-SINR selected MCS=%d (want 8)\n", hi); ++fails; }

    int lo = rf_mcs_select(qr_lo, 1, curves, target, 0, RF_CRIT_MEAN, &crit, &st);  /* Low SINR. */
    if (!(lo == 0 && st == RF_SEL_LOWEST_FALLBACK)) {    /* Should fall back to MCS 0. */
        printf("  low-SINR MCS=%d st=%d (want 0/fallback)\n", lo, st); ++fails;
    }

    int prev = -1;                                       /* Previous selection, for the monotonicity check. */
    for (double d = 0; d <= 30; d += 1.0) {              /* Sweep the SINR upward. */
        q16_t qr[RF_NUM_MCS]; for (int m = 0; m < RF_NUM_MCS; ++m) qr[m] = S(d);  /* Quality report at d. */
        int sel = rf_mcs_select(qr, 1, curves, target, 0, RF_CRIT_MEAN, &crit, &st);  /* Select. */
        if (sel < prev) { printf("  non-monotone at %.0f dB: %d < %d\n", d, sel, prev); ++fails; }
        prev = sel;                                      /* Remember for the next step. */
    }

    printf("[test_mcs] selector + interp + monotonicity -> %s\n", fails ? "FAIL" : "PASS");  /* Report. */
    return fails ? 1 : 0;                                /* Exit status. */
}
