/*
=========================================================================================================================
 *** rf_coding (header) ***
 Declarations for the variable-rate coding chain and the CQI feedback buffer.
=========================================================================================================================

 Description:
     This header declares the convolutional encoder, the puncturing operations, the depuncturing, and the feedback
     delay buffer implemented in rf_coding.c. Each declaration names the inputs and outputs; the full descriptions are
     in the source file.

 Supporting files:
     implemented in   rf_coding.c
     header           rf_fixed.h (Q16.16 type used by the buffered reports)
     reference        encode_variable_rate.m, select_puncturing_pattern.m, apply_puncturing.m, depuncture_llr.m,
                      apply_cqi_feedback_delay.m
=========================================================================================================================
*/
#ifndef RF_CODING_H
#define RF_CODING_H

#include "rf_fixed.h"
#include <stdint.h>
#include <stddef.h>

#define RF_NUM_MCS_CODING 9        /* Entries per layer in a buffered quality report. */
#define RF_CQI_DELAY_MAX  4        /* Largest supported feedback delay in slots. */
#define RF_MAX_LAYERS     16       /* Largest supported layer count. */

/* Rate-1/2 constraint-length-7 convolutional encoder, generators (133, 171) octal. */
void rf_conv_encode_k7(const uint8_t *info_bits, size_t n, uint8_t *coded_bits);

/* Puncturing mask for the requested rate; returns the mask period, or zero if unsupported. */
size_t rf_select_puncture_mask(int rate_num, int rate_den, uint8_t *mask);

/* Apply the mask to the mother stream; returns the number of transmitted bits. */
size_t rf_apply_puncturing(const uint8_t *mother_bits, size_t n,
                           const uint8_t *mask, size_t period,
                           uint8_t *out_bits, size_t *kept_positions);

/* Restore punctured positions as zero-valued erasure log-likelihood ratios. */
void rf_depuncture_llr(const double *rx_llr, const size_t *kept_positions, size_t m,
                       size_t mother_len, double *mother_llr);

/* First-in-first-out feedback buffer for the per-layer quality report. */
typedef struct {
    size_t depth;                                             /* Configured delay in slots. */
    q16_t  report[RF_CQI_DELAY_MAX][RF_MAX_LAYERS * RF_NUM_MCS_CODING];  /* Buffered reports. */
    int    valid[RF_CQI_DELAY_MAX];                           /* Whether each entry holds a real report. */
} rf_cqi_delay_t;

void rf_cqi_delay_init(rf_cqi_delay_t *buf, size_t depth);    /* Mark the buffer empty. */
int  rf_cqi_delay_step(rf_cqi_delay_t *buf, const q16_t *new_report, size_t nt, q16_t *out_report);

#endif /* RF_CODING_H */
