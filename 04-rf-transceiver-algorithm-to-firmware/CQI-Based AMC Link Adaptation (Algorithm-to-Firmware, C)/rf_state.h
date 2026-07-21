/*
=========================================================================================================================
 *** rf_state (header) ***
 Declarations for the RF control state machine and the outer-loop update.
=========================================================================================================================

 Description:
     Declares the state enumeration, the adaptation configuration, the controller context, and the three functions
     implemented in rf_state.c.

     Each declaration names the inputs and outputs; the full descriptions are in rf_state.c.

 Supporting files:
     implemented in   rf_state.c
     header           rf_regmap.h (register access), rf_mcs.h (selector and curve type), rf_fixed.h (Q16.16 type)
     reference        the run loop of run_cqi_amc_main.m, and update_olla_offset.m
=========================================================================================================================
*/
#ifndef RF_STATE_H
#define RF_STATE_H

#include "rf_regmap.h"
#include "rf_mcs.h"
#include "rf_fixed.h"

/* The states of one slot. */
typedef enum {
    RF_ST_IDLE = 0,     /* Start-up; enable transmit and receive. */
    RF_ST_CONFIGURE,    /* Select the MCS and write it. */
    RF_ST_TRANSMIT,     /* Lower layer transmits the slot. */
    RF_ST_RECEIVE,      /* Lower layer receives the slot. */
    RF_ST_MEASURE,      /* Count the CRC results of the slot. */
    RF_ST_ADAPT,        /* Update the outer-loop offset. */
    RF_ST_FAULT         /* Unexpected state. */
} rf_state_t;

/* Adaptation configuration held by the controller. */
typedef struct {
    q16_t olla_offset_db;      /* Current outer-loop offset, Q16.16. */
    q16_t olla_step_down_db;   /* Downward step on a failed block. */
    q16_t olla_step_up_db;     /* Upward step on a passed block. */
    q16_t olla_clamp_db;       /* Symmetric limit on the offset. */
    q16_t target_bler;         /* Target BLER, Q16.16. */
    rf_sel_criterion_t criterion;  /* Mean or worst-layer selection. */
} rf_adapt_cfg_t;

/* Everything the controller needs between steps. */
typedef struct {
    rf_regfile_t  *regs;       /* The register map. */
    rf_state_t     state;      /* Current state. */
    rf_adapt_cfg_t cfg;        /* Adaptation configuration. */
    uint32_t       blocks;     /* Running total block count. */
    uint32_t       crc_errors; /* Running CRC-failure count. */
} rf_ctx_t;

/* Initialize the controller. */
void rf_state_init(rf_ctx_t *ctx, rf_regfile_t *regs, const rf_adapt_cfg_t *cfg);

/* Advance the state machine by one state. */
rf_state_t rf_state_step(rf_ctx_t *ctx,
                         const q16_t *quality_report, size_t nt,
                         const rf_bler_curve_t curves[RF_NUM_MCS],
                         const uint8_t *crc_fail, size_t num_blocks);

/* Outer-loop offset update. */
q16_t rf_olla_update(const rf_adapt_cfg_t *cfg, q16_t offset,
                     const uint8_t *crc_fail, size_t num_blocks);

#endif /* RF_STATE_H */
