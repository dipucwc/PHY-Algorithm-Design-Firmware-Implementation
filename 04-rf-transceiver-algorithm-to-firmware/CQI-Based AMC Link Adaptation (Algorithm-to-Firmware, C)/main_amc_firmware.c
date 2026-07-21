/*
=========================================================================================================================
 *** main_amc_firmware ***
 Main program for the Project 2 RF PHY link-adaptation firmware (CQI-based AMC, 8x8 and 16x16 MIMO-OFDM).
=========================================================================================================================

 Description:
     This is the main program of the Project 2 link-adaptation firmware. It executes the deployable kernels of the
     CQI-based adaptive modulation and coding chain, ported from the verified MATLAB model, through one slot so that
     the complete closed loop is visible in one file. The Monte Carlo sweep, the calibration of the error curves, and
     the plotting of the MATLAB model are evaluation infrastructure and are not part of the firmware; the firmware
     executes the per-slot decision only.

     The complete procedure operates as follows, in the loop order of the reference. The measurement stage estimates
     the per-stream post-equalization SINR from the estimated channel and builds the per-layer, per-candidate quality
     report of the slot. The mapping stage reduces the per-resource-element SINR
     values of a codeword to one effective SINR in decibels. The selection stage chooses the scheme with the highest
     spectral efficiency whose predicted block error rate satisfies the 0.10 target, reading the predictions from
     calibrated curves. The control stage advances the state machine through the slot: the scheme is selected before
     the slot's own measurements exist, the CRC verdicts are counted, and the outer-loop offset is updated toward the
     target. The final stage demonstrates the CRC block check that defines block success. Each stage calls one
     supporting kernel, and each kernel corresponds to one MATLAB reference function.

 Supporting functions:

     rf_eesm_eff_sinr_db, rf_eesm_eff_sinr_db_mcs
         Collapse the per-resource-element SINR values of a codeword into one effective SINR in decibels (rf_eesm.c).

     rf_exp_neg_q16, rf_ln_q16, rf_ten_log10_q16
         Fixed-point exponential, logarithm, and decibel conversion used by the mapping (rf_math.c).

     rf_bler_interp
         Reads a predicted block error rate off a calibrated curve by monotone interpolation (rf_mcs.c).

     rf_mcs_select
         Selects the transmission MCS of the slot under the block-error-rate target (rf_mcs.c).

     rf_state_init, rf_state_step
         Initialize and advance the RF control state machine through one slot (rf_state.c).

     rf_olla_update
         Updates the outer-loop offset from the CRC verdicts toward the target (rf_state.c).

     rf_crc16_bits, rf_crc16_check
         Compute the CRC of a block and check whether a received block is intact (rf_crc16.c).

     rf_conv_encode_k7, rf_select_puncture_mask, rf_apply_puncturing, rf_depuncture_llr
         Encode with the rate-1/2 mother code and raise the rate by puncturing; restore erasures for the decoder
         (rf_coding.c).

     rf_cqi_delay_init, rf_cqi_delay_step
         Enforce the CQI feedback delay with a first-in-first-out report buffer (rf_coding.c).

     rf_reg_read, rf_reg_write
         Read and write the transceiver control and status registers (rf_regmap.h).

     rf_post_eq_sinr, rf_quality_report, rf_estimate_cqi
         Estimate the per-stream SINR from the channel, build the quality report, and form the uncorrected CQI
         (rf_quality.c).

 Input:
     (none)   The program is self-contained; it builds an example quality report and calibrated curves in code.

 Output:
     return value   Zero on normal completion.
     stdout         One line per stage showing the result (effective SINR, selected MCS, state cycle, CRC check).

 Supporting files:
     header      rf_eesm.h, rf_mcs.h, rf_state.h, rf_regmap.h, rf_crc16.h, rf_fixed.h
     sources     rf_math.c, rf_eesm.c, rf_mcs.c, rf_state.c, rf_crc16.c
     reference   main_cqi_amc_8x8.m / main_cqi_amc_16x16.m (the MATLAB main scripts this pipeline mirrors)
=========================================================================================================================
*/
#include <stdio.h>
#include <string.h>
#include "rf_eesm.h"
#include "rf_mcs.h"
#include "rf_state.h"
#include "rf_crc16.h"
#include "rf_quality.h"

/* A tiny shortcut so the numbers below read as plain decimals instead of fixed-point conversions. */
static q16_t Q(double x) { return rf_double_to_q16(x); }

int main(void)
{
    /* ---- Stage 1: measure the channel and build the quality report --------------------------------------------- */

    const size_t Nr = 2, Nt = 2, Nsc = 4;             /* A small two-stream link over four subcarriers. */
    cplx_t Hk[4] = { cx(1.0, 0.0), cx(0.3, 0.1),      /* One estimated channel used at every subcarrier here. */
                     cx(0.1, -0.2), cx(0.9, 0.0) };
    double sinr_lin[2 * 4];                           /* The per-stream, per-subcarrier SINR profile. */
    double s2[2];                                     /* Per-stream SINR at one subcarrier. */
    rf_post_eq_sinr(Hk, Nr, Nt, 0.05, 1.0, s2);       /* Estimate the SINR from the channel alone. */
    for (size_t k = 0; k < Nsc; ++k) {                /* Replicate across the subcarriers of the slot. */
        sinr_lin[0 * Nsc + k] = s2[0];                /* Stream one. */
        sinr_lin[1 * Nsc + k] = s2[1];                /* Stream two. */
    }

    printf("measure: per-stream SINR = %.2f / %.2f (linear)\n", s2[0], s2[1]);

    /* ---- Stage 2: turn the profile into the per-layer quality report ------------------------------------------- */

    static q16_t report2[2 * RF_NUM_MCS];             /* The Nt-by-nine report of the slot. */
    rf_quality_report(sinr_lin, Nt, Nsc, report2);    /* One effective SINR per layer and candidate. */
    q16_t eff = report2[3];                           /* Layer one, candidate three, as the printed sample. */

    printf("report : layer-1 effective SINR (MCS 3) = %.2f dB\n", rf_q16_to_double(eff));

    /* ---- Stage 3: pick the biggest scheme that still meets the target ------------------------------------------ */

    /* Give each scheme a simple two-point error curve: bad at low SINR, clean at high SINR. */
    static q16_t csn[RF_NUM_MCS][2], cbl[RF_NUM_MCS][2];
    rf_bler_curve_t curves[RF_NUM_MCS];
    double cross[RF_NUM_MCS] = {5,7,8,11,13,15,15,17,19};  /* Where each scheme crosses the target. */
    for (int m = 0; m < RF_NUM_MCS; ++m) {
        csn[m][0] = Q(cross[m] - 2.0); cbl[m][0] = Q(0.5);   /* Below the crossing, errors are high. */
        csn[m][1] = Q(cross[m] + 2.0); cbl[m][1] = Q(0.0);   /* Above it, errors vanish. */
        curves[m].sinr_db = csn[m]; curves[m].bler = cbl[m]; curves[m].npts = 2;
    }

    q16_t qr[RF_NUM_MCS];                             /* The quality report the selector reads. */
    for (int m = 0; m < RF_NUM_MCS; ++m) qr[m] = Q(20.0);   /* Pretend the link is at 20 dB. */

    q16_t crit; rf_sel_status_t st;
    int mcs = rf_mcs_select(qr, 1, curves, Q(0.10), 0, RF_CRIT_MEAN, &crit, &st);  /* Choose under a 0.10 target. */

    printf("select : MCS = %d, predicted BLER = %.3f, status = %d\n", mcs, rf_q16_to_double(crit), (int)st);

    /* ---- Stage 4: run the control state machine through one slot ----------------------------------------------- */

    rf_regfile_t regs; memset(&regs, 0, sizeof regs); /* The control registers, empty to start. */
    rf_adapt_cfg_t cfg = {
        .olla_offset_db    = 0,                       /* Start the correction at zero. */
        .olla_step_down_db = Q(0.5),                  /* Back off this much after a failed block. */
        .olla_step_up_db   = Q(0.5 * 0.10 / 0.90),    /* Creep up this much after a good one (tuned to 0.10). */
        .olla_clamp_db     = Q(10.0),                 /* Never let the correction run away. */
        .target_bler       = Q(0.10),                 /* Aim for one block in ten failing. */
        .criterion         = RF_CRIT_MEAN             /* Average the layers when judging a scheme. */
    };
    rf_ctx_t ctx; rf_state_init(&ctx, &regs, &cfg);   /* Set up the controller. */

    uint8_t verdicts[2] = {0, 0};                     /* Two blocks this slot, both passed. */
    for (int i = 0; i < 6; ++i)                        /* Step once through the full state cycle. */
        rf_state_step(&ctx, qr, 1, curves, verdicts, 2);

    printf("control: state cycled, blocks counted = %u, MCS register = %u\n",
           rf_reg_read(&regs, RF_REG_BLOCKS), rf_reg_read(&regs, RF_REG_MCS));

    /* ---- Stage 5: check a block with the CRC ------------------------------------------------------------------ */

    uint8_t info[32];                                 /* The information bits we want to protect. */
    for (int i = 0; i < 32; ++i) info[i] = (uint8_t)(((unsigned)i * 5u + 1u) & 1u);  /* Any repeatable pattern. */
    uint16_t crc = rf_crc16_bits(info, 32);           /* Work out their CRC at the transmitter. */

    uint8_t block[48];                                /* The block we "receive": info followed by the CRC. */
    memcpy(block, info, 32);                          /* Copy the information bits. */
    for (int b = 0; b < 16; ++b)                      /* Append the sixteen CRC bits, top bit first. */
        block[32 + b] = (uint8_t)((crc >> (15 - b)) & 1u);

    int ok = rf_crc16_check(block, 48);               /* At the receiver, does it check out? */

    printf("crc    : block check = %s\n", ok ? "PASS (remainder zero)" : "FAIL");

    return 0;                                          /* Done. */
}
