/*
=========================================================================================================================
 *** test_state ***
 Functional test for the RF control state machine and the outer-loop update.
=========================================================================================================================

 Description:
     This test verifies the control state machine and the outer-loop update. Four properties are checked: the offset
     moves down after a failed slot and up after a successful one; the offset shows no net drift when the failure
     fraction equals the target, which is the defining property of the target-locked step ratio; the offset never
     leaves the configured clamp range even under a long run of failures; and the state machine cycles through a
     complete slot without entering the fault state while counting the blocks into the registers. The purpose of the
     test is to pin the closed-loop behaviour that the link-level results depend on.

     The complete procedure runs in four steps. In the first step, the controller is initialized with the target-locked
     step sizes and the update is applied to a single failed and a single passed slot, checking the direction of each
     move. In the second step, a slot pattern with exactly one failure in ten blocks, matching the 0.10 target, is
     applied fifty times and the accumulated drift is required to stay near zero. In the third step, one hundred
     consecutive failures are applied and the resulting offset is required to respect the clamp. In the fourth step,
     the state machine is stepped through a full slot cycle with a valid quality report and passing verdicts, the
     resulting state must not be the fault state, and the block counter register must show the counted blocks. The test
     reports one summary line and returns zero only when all four properties hold.

 Input:
     (none)   The configuration, curves, and verdicts are built in code.

 Output:
     return value   Zero if the test passes, one if it fails.
     stdout         One line reporting PASS or FAIL.

 Supporting files:
     header      rf_state.h (the functions under test)
     reference   update_olla_offset.m and the run loop of run_cqi_amc_main.m
=========================================================================================================================
*/
#include <stdio.h>
#include <string.h>
#include "rf_state.h"

/* S: shorthand to make a Q16.16 value from a real number. */
static q16_t S(double d) { return rf_double_to_q16(d); }

int main(void)
{
    int fails = 0;                                       /* Failure counter. */
    rf_regfile_t regs; memset(&regs, 0, sizeof regs);    /* The simulated register file. */

    rf_adapt_cfg_t cfg = {                               /* Adaptation configuration. */
        .olla_offset_db    = 0,                          /* Start with no offset. */
        .olla_step_down_db = S(0.5),                     /* Down-step on a failure. */
        .olla_step_up_db   = S(0.5 * 0.10 / 0.90),       /* Up-step, target-locked to 0.10. */
        .olla_clamp_db     = S(10.0),                    /* Offset limit. */
        .target_bler       = S(0.10),                    /* Target BLER. */
        .criterion         = RF_CRIT_MEAN                /* Combine layers by their mean. */
    };
    rf_ctx_t ctx; rf_state_init(&ctx, &regs, &cfg);      /* Initialize the controller. */

    uint8_t one_fail[1] = {1}, one_ok[1] = {0};          /* One failed and one passed block. */
    q16_t o0 = 0;                                        /* Starting offset. */
    q16_t of = rf_olla_update(&cfg, o0, one_fail, 1);    /* After a failure. */
    q16_t os = rf_olla_update(&cfg, o0, one_ok, 1);      /* After a success. */
    if (!(of < o0)) { printf("  failure did not lower offset\n"); ++fails; }  /* Down on failure. */
    if (!(os > o0)) { printf("  success did not raise offset\n"); ++fails; }  /* Up on success. */

    uint8_t seq[10] = {1,0,0,0,0,0,0,0,0,0};             /* One failure in ten, matching the target. */
    q16_t o = 0;
    for (int rep = 0; rep < 50; ++rep) o = rf_olla_update(&cfg, o, seq, 10);  /* Run many slots. */
    double drift = rf_q16_to_double(o);                  /* Net drift. */
    if (drift < -1.0 || drift > 1.0) { printf("  drift=%.3f dB not near zero\n", drift); ++fails; }  /* Near zero. */

    uint8_t fails_arr[100]; memset(fails_arr, 1, sizeof fails_arr);  /* All failures. */
    q16_t oc = rf_olla_update(&cfg, 0, fails_arr, 100);  /* Drive the offset hard. */
    if (rf_q16_to_double(oc) < -10.01) { printf("  clamp breached: %.3f\n", rf_q16_to_double(oc)); ++fails; }

    q16_t qr[RF_NUM_MCS]; for (int m = 0; m < RF_NUM_MCS; ++m) qr[m] = S(20.0);  /* A quality report. */
    q16_t sc[2] = {S(5.0), S(25.0)}, bc[2] = {S(0.5), S(0.0)};  /* A simple curve. */
    rf_bler_curve_t curves[RF_NUM_MCS];                  /* Curves for the selector. */
    for (int m = 0; m < RF_NUM_MCS; ++m) { curves[m].sinr_db = sc; curves[m].bler = bc; curves[m].npts = 2; }
    uint8_t verdicts[2] = {0, 0};                        /* Two passed blocks. */
    rf_state_t s = ctx.state;
    for (int i = 0; i < 8; ++i) s = rf_state_step(&ctx, qr, 1, curves, verdicts, 2);  /* Step the machine. */
    if (s == RF_ST_FAULT) { printf("  FSM entered FAULT\n"); ++fails; }  /* Must not fault. */
    if (rf_reg_read(&regs, RF_REG_BLOCKS) == 0) { printf("  no blocks counted\n"); ++fails; }  /* Must count. */

    printf("[test_state] FSM + OLLA direction/drift/clamp -> %s\n", fails ? "FAIL" : "PASS");  /* Report. */
    return fails ? 1 : 0;                                /* Exit status. */
}
