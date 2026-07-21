/*
=========================================================================================================================
 *** rf_state ***
 RF transceiver control state machine and outer-loop update.
=========================================================================================================================

 Description:
     This file implements the control sequencing of one slot and the outer-loop link-adaptation (OLLA) correction. The
     state machine advances through idle, configure, transmit, receive, measure, and adapt, and returns to configure
     for the next slot. The ordering enforces the feedback constraint of the closed loop: the scheme of a slot is
     selected in the configure state, before any measurement of that slot exists, so no slot can influence its own
     transmission.

     The complete procedure operates as follows. The outer loop corrects the residual bias of the calibrated prediction. After each block verdict the SINR offset
     is decreased by a fixed step on a failure and increased by a smaller step on a success. The two steps are related
     by the ratio target / (1 - target), which makes the expected offset drift zero exactly when the block error rate
     equals the target; the loop therefore converges the long-run error rate to the target without measuring it
     directly. A symmetric clamp bounds the offset. All control and status values pass through the register-map
     abstraction, which keeps the sequencing logic independent of the physical register layout.

 Input / Output:
     Given per function below.

 Supporting files:
     header      rf_state.h       (declares the states, the configuration, the context, and the functions)
     header      rf_regmap.h      (register read and write for control and status)
     header      rf_mcs.h         (the scheme selector called in the configure step)
     header      rf_fixed.h       (Q16.16 type)
     reference   the run loop of run_cqi_amc_main.m, and update_olla_offset.m
     calls       rf_mcs_select (in rf_mcs.c), rf_reg_read / rf_reg_write (in rf_regmap.h)
=========================================================================================================================
*/
#include "rf_state.h"

/*
=========================================================================================================================
 *** rf_state_init ***
 Set the controller to its start-up state.
=========================================================================================================================

 Description:
     This function initializes the controller before the first slot. The register file is attached, the state is set to
     idle, the configuration is copied, the block counters are cleared, and the initial offset and the target are
     written to their registers.

 Input:
     ctx    The controller context to initialize.
     regs   The register file to use.
     cfg    The adaptation settings to copy in.

 Output:
     (none; ctx and regs are initialized)
=========================================================================================================================
*/
void rf_state_init(rf_ctx_t *ctx, rf_regfile_t *regs, const rf_adapt_cfg_t *cfg)
{
    ctx->regs = regs;                                 /* Remember where the registers live. */
    ctx->state = RF_ST_IDLE;                          /* Everyone starts idle. */
    ctx->cfg = *cfg;                                  /* Take our own copy of the settings. */
    ctx->blocks = 0;                                  /* No blocks counted yet. */
    ctx->crc_errors = 0;                              /* No failures yet. */
    rf_reg_write(regs, RF_REG_STATE, RF_ST_IDLE);     /* Publish the state. */
    rf_reg_write(regs, RF_REG_OLLA_OFFSET, (uint32_t)cfg->olla_offset_db);  /* Publish the starting offset. */
    rf_reg_write(regs, RF_REG_TARGET_BLER, (uint32_t)cfg->target_bler);     /* Publish the target. */
}

/*
=========================================================================================================================
 *** rf_olla_update ***
 Update the outer-loop offset from the CRC verdicts of the slot.
=========================================================================================================================

 Description:
     This function applies the outer-loop update once per slot, exactly as the reference does. The fraction of failed
     blocks among all layer codewords of the slot pulls the offset down by the failure step, and the complementary
     successful fraction pushes it up by the smaller success step; the two contributions are combined in one
     fraction-weighted update and the result is clamped to the configured range. With the steps in the target-locked
     ratio, the expected update is zero exactly when the failure fraction equals the target, so the loop converges the
     long-run block error rate to the target without measuring it directly.

 Input:
     cfg          The settings (the two step sizes and the clamp).
     offset       The current offset in decibels, Q16.16.
     crc_fail     One flag per block, 1 if it failed, 0 if it passed.
     num_blocks   How many blocks this slot had.

 Output:
     return value   The updated, clamped offset.
=========================================================================================================================
*/
q16_t rf_olla_update(const rf_adapt_cfg_t *cfg, q16_t offset,
                     const uint8_t *crc_fail, size_t num_blocks)
{
    if (num_blocks == 0) return offset;               /* No verdicts: the offset is unchanged. */

    size_t nfail = 0;                                 /* Count the failed blocks of the slot. */
    for (size_t i = 0; i < num_blocks; ++i)           /* One verdict per block. */
        if (crc_fail[i]) ++nfail;

    /* Fraction-weighted asymmetric update, as in the reference: the failed fraction pulls the offset down by the
     * failure step and the successful fraction pushes it up by the smaller success step. */
    int64_t up   = (int64_t)cfg->olla_step_up_db   * (int64_t)(num_blocks - nfail);  /* Success contribution. */
    int64_t down = (int64_t)cfg->olla_step_down_db * (int64_t)nfail;                 /* Failure contribution. */
    offset = (q16_t)(offset + (q16_t)((up - down) / (int64_t)num_blocks));           /* Apply the weighted step. */

    if (offset >  cfg->olla_clamp_db) offset =  cfg->olla_clamp_db;   /* Clamp above the limit. */
    if (offset < -cfg->olla_clamp_db) offset = -cfg->olla_clamp_db;   /* Clamp below the limit. */
    return offset;                                    /* The updated offset. */
}

/*
=========================================================================================================================
 *** rf_state_step ***
 Advance the control state machine by one state.
=========================================================================================================================

 Description:
     This function advances the state machine by one state and performs that state's work. Idle enables the transmit
     and receive paths. Configure runs the BLER-constrained selection and writes the chosen scheme and the selection
     status to the registers. Transmit and receive are pass-through states handled by the layer below. Measure counts
     the CRC verdicts of the slot and publishes the running totals. Adapt applies the outer-loop update, publishes the
     new offset, and returns to configure. The new state is written to the state register on every step.

 Input:
     ctx              The controller context.
     quality_report   Per-layer, per-scheme effective SINR, used in the configure step.
     nt               Number of spatial layers.
     curves           Calibrated error curves, used in the configure step.
     crc_fail         Per-block pass/fail flags, used in the measure and adapt steps.
     num_blocks       How many blocks this slot had.

 Output:
     return value   The new state (also written to the registers).
=========================================================================================================================
*/
rf_state_t rf_state_step(rf_ctx_t *ctx,
                         const q16_t *quality_report, size_t nt,
                         const rf_bler_curve_t curves[RF_NUM_MCS],
                         const uint8_t *crc_fail, size_t num_blocks)
{
    rf_regfile_t *r = ctx->regs;                      /* Short name for the registers. */

    switch (ctx->state) {                             /* Do whatever the current step calls for. */

    case RF_ST_IDLE:                                  /* Fresh start. */
        rf_reg_write(r, RF_REG_CTRL, RF_CTRL_TX_EN | RF_CTRL_RX_EN);  /* Turn on transmit and receive. */
        ctx->state = RF_ST_CONFIGURE;                 /* Go choose a scheme. */
        break;

    case RF_ST_CONFIGURE: {                           /* Decide before we transmit. */
        q16_t crit; rf_sel_status_t st;
        int mcs = rf_mcs_select(quality_report, nt, curves,
                                ctx->cfg.target_bler, ctx->cfg.olla_offset_db,
                                ctx->cfg.criterion, &crit, &st);       /* Pick the scheme. */
        rf_reg_write(r, RF_REG_MCS, (uint32_t)mcs);   /* Publish the choice. */
        rf_reg_write(r, RF_REG_STATUS, (uint32_t)st); /* Publish how it went. */
        ctx->state = RF_ST_TRANSMIT;
        break;
    }

    case RF_ST_TRANSMIT:                              /* The layer below sends the slot. */
        ctx->state = RF_ST_RECEIVE;
        break;

    case RF_ST_RECEIVE:                              /* The layer below receives the slot. */
        ctx->state = RF_ST_MEASURE;
        break;

    case RF_ST_MEASURE: {                             /* Count how the blocks did. */
        uint32_t fails = 0;
        for (size_t i = 0; i < num_blocks; ++i) fails += (crc_fail[i] ? 1u : 0u);  /* Count the failures. */
        ctx->blocks     += (uint32_t)num_blocks;      /* Running total of blocks. */
        ctx->crc_errors += fails;                     /* Running total of failures. */
        rf_reg_write(r, RF_REG_BLOCKS, ctx->blocks);          /* Publish the totals. */
        rf_reg_write(r, RF_REG_CRC_ERRORS, ctx->crc_errors);
        ctx->state = RF_ST_ADAPT;
        break;
    }

    case RF_ST_ADAPT:                                 /* Nudge the correction and go again. */
        ctx->cfg.olla_offset_db =
            rf_olla_update(&ctx->cfg, ctx->cfg.olla_offset_db, crc_fail, num_blocks);  /* Update the offset. */
        rf_reg_write(r, RF_REG_OLLA_OFFSET, (uint32_t)ctx->cfg.olla_offset_db);        /* Publish it. */
        ctx->state = RF_ST_CONFIGURE;                 /* Round we go for the next slot. */
        break;

    default:                                          /* Shouldn't get here. */
        ctx->state = RF_ST_FAULT;
        break;
    }

    rf_reg_write(r, RF_REG_STATE, (uint32_t)ctx->state);  /* Publish the new state. */
    return ctx->state;                                /* Tell the caller where we are. */
}
