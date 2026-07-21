/*
=========================================================================================================================
 *** rf_coding ***
 Variable-rate convolutional encoding chain: mother-code encoder, puncturing, depuncturing, and the feedback delay.
=========================================================================================================================

 Description:
     This file implements the transmit-side coding operations and the feedback buffer of the link-adaptation chain. It
     contains the constraint-length-7 rate-1/2 convolutional encoder with generator polynomials (133, 171) octal, the
     puncturing mask selection and application that raise the coding rate to 2/3 or 3/4, the depuncturing that restores
     the punctured positions as zero-valued erasures for the soft decoder, and the first-in-first-out delay buffer that
     enforces the causality of the CQI feedback.

     The complete procedure operates as follows, along the reference chain. The encoder shifts each information bit through a six-bit register and
     produces two output bits per input bit from the two generator taps, which yields the rate-1/2 mother stream. The
     puncturing stage tiles a short periodic mask over that stream and transmits only the positions marked one; the
     rate-2/3 mask keeps three of every four mother bits and the rate-3/4 mask keeps four of every six, which are the
     standard patterns for this code. At the receiver, depuncturing writes each received log-likelihood ratio back to
     its kept position and leaves every punctured position at exactly zero, because a zero log-likelihood ratio states
     no preference between the two bit values, which is the correct treatment of a position that was never transmitted.
     The feedback buffer holds the per-slot quality reports for the configured number of slots, so the report measured
     in slot t drives the transmitter only in slot t plus the delay; before the first report has propagated through,
     the buffer returns an empty indication and the transmitter falls back to its initial scheme.

 Input / Output:
     Given per function below.

 Supporting files:
     header      rf_coding.h      (declares the functions and the delay-buffer type)
     header      rf_fixed.h       (Q16.16 type used by the buffered reports)
     reference   encode_variable_rate.m, select_puncturing_pattern.m, apply_puncturing.m, depuncture_llr.m,
                 apply_cqi_feedback_delay.m
     calls       none
=========================================================================================================================
*/
#include "rf_coding.h"
#include <string.h>

/*
=========================================================================================================================
 *** rf_conv_encode_k7 ***
 Constraint-length-7 rate-1/2 convolutional encoder, generators (133, 171) octal.
=========================================================================================================================

 Description:
     This function encodes an information-bit stream with the rate-1/2 mother code. Each input bit enters a six-bit
     shift register, and the two output bits are the parities of the register taps selected by the two generator
     polynomials. The register starts at zero, and the caller appends six zero tail bits to the information stream when
     termination in the zero state is required, as the reference does.

 Input:
     info_bits    Information bits, one per byte (0 or 1), including any tail bits.
     n            Number of input bits.

 Output:
     coded_bits   Encoded output, two bits per input bit, one per byte (caller-allocated, length 2 * n).
=========================================================================================================================
*/
void rf_conv_encode_k7(const uint8_t *info_bits, size_t n, uint8_t *coded_bits)
{
    unsigned reg = 0;                                 /* Six-bit shift register, initially zero. */
    const unsigned G0 = 0155;                         /* Generator 133 octal over the seven positions (bit-reversed form). */
    const unsigned G1 = 0117;                         /* Generator 171 octal over the seven positions (bit-reversed form). */

    for (size_t i = 0; i < n; ++i) {                  /* One input bit per step. */

        unsigned in = (unsigned)(info_bits[i] & 1u);  /* The incoming information bit. */
        unsigned state = (in << 6) | reg;             /* Seven-position window: input bit plus register. */

        unsigned p0 = state & G0;                     /* Taps of the first generator. */
        unsigned p1 = state & G1;                     /* Taps of the second generator. */

        p0 ^= p0 >> 4; p0 ^= p0 >> 2; p0 ^= p0 >> 1;  /* Parity of the first tap set. */
        p1 ^= p1 >> 4; p1 ^= p1 >> 2; p1 ^= p1 >> 1;  /* Parity of the second tap set. */

        coded_bits[2 * i]     = (uint8_t)(p0 & 1u);   /* First output bit of this step. */
        coded_bits[2 * i + 1] = (uint8_t)(p1 & 1u);   /* Second output bit of this step. */

        reg = state >> 1;                             /* Shift the register for the next bit. */
    }
}

/*
=========================================================================================================================
 *** rf_select_puncture_mask ***
 Puncturing mask for a requested coding rate.
=========================================================================================================================

 Description:
     This function returns the periodic puncturing mask that converts the rate-1/2 mother code into the requested rate.
     The rate-1/2 mask transmits every position, the rate-2/3 mask transmits three of every four mother bits, and the
     rate-3/4 mask transmits four of every six. These are the standard patterns for the constraint-length-7 code.

 Input:
     rate_num   Coding-rate numerator (1, 2, or 3).
     rate_den   Coding-rate denominator (2, 3, or 4).

 Output:
     mask       The mask, one entry per mother bit of one period (caller-allocated, at least 6 entries).
     return value   The mask period in mother bits, or zero for an unsupported rate.
=========================================================================================================================
*/
size_t rf_select_puncture_mask(int rate_num, int rate_den, uint8_t *mask)
{
    if (rate_num == 1 && rate_den == 2) {             /* Rate 1/2: transmit everything. */
        mask[0] = 1; mask[1] = 1;
        return 2;
    }
    if (rate_num == 2 && rate_den == 3) {             /* Rate 2/3: keep three of every four. */
        mask[0] = 1; mask[1] = 1; mask[2] = 1; mask[3] = 0;
        return 4;
    }
    if (rate_num == 3 && rate_den == 4) {             /* Rate 3/4: keep four of every six. */
        mask[0] = 1; mask[1] = 1; mask[2] = 1; mask[3] = 0; mask[4] = 0; mask[5] = 1;
        return 6;
    }
    return 0;                                         /* Unsupported rate. */
}

/*
=========================================================================================================================
 *** rf_apply_puncturing ***
 Remove punctured positions from the mother-code output.
=========================================================================================================================

 Description:
     This function tiles the periodic mask over the mother-code stream and copies out only the positions marked one.
     The list of kept positions is also recorded, so that the depuncturing routine can restore the erasures at exactly
     the removed locations.

 Input:
     mother_bits   The mother-code bit stream, one bit per byte.
     n             Length of the mother stream.
     mask          The puncturing mask over one period.
     period        The mask period.

 Output:
     out_bits         The transmitted subset of the stream (caller-allocated).
     kept_positions   The mother-stream index of each transmitted bit (caller-allocated).
     return value     The number of transmitted bits.
=========================================================================================================================
*/
size_t rf_apply_puncturing(const uint8_t *mother_bits, size_t n,
                           const uint8_t *mask, size_t period,
                           uint8_t *out_bits, size_t *kept_positions)
{
    size_t m = 0;                                     /* Count of transmitted bits. */

    for (size_t i = 0; i < n; ++i) {                  /* Walk the mother stream. */
        if (mask[i % period]) {                       /* This position is marked for transmission. */
            out_bits[m] = mother_bits[i];             /* Copy the bit out. */
            kept_positions[m] = i;                    /* Record where it came from. */
            ++m;
        }
    }

    return m;                                         /* Number of bits actually transmitted. */
}

/*
=========================================================================================================================
 *** rf_depuncture_llr ***
 Restore punctured positions as zero-valued erasure log-likelihood ratios.
=========================================================================================================================

 Description:
     This function rebuilds the mother-code-length soft stream for the decoder. Every position is first set to zero,
     which expresses no preference between the two bit values, and each received log-likelihood ratio is then written
     back to its kept position. The punctured positions remain at zero, which is the correct erasure statement for a
     position the transmitter never sent.

 Input:
     rx_llr           Received log-likelihood ratios of the transmitted bits.
     kept_positions   The mother-stream index of each transmitted bit.
     m                Number of transmitted bits.
     mother_len       Length of the mother stream.

 Output:
     mother_llr       The reconstructed soft stream (caller-allocated, length mother_len).
=========================================================================================================================
*/
void rf_depuncture_llr(const double *rx_llr, const size_t *kept_positions, size_t m,
                       size_t mother_len, double *mother_llr)
{
    for (size_t i = 0; i < mother_len; ++i)           /* Start every position as an erasure. */
        mother_llr[i] = 0.0;

    for (size_t k = 0; k < m; ++k)                    /* Restore each received value at its kept position. */
        mother_llr[kept_positions[k]] = rx_llr[k];
}

/*
=========================================================================================================================
 *** rf_cqi_delay_init / rf_cqi_delay_step ***
 Causal feedback buffer for the per-layer quality report.
=========================================================================================================================

 Description:
     These functions implement the CQI feedback delay as a first-in-first-out buffer. The initialization marks every
     slot of the buffer as empty. On each slot, the step function returns the oldest buffered report, shifts the buffer
     by one, and inserts the newest report at the tail. The report measured in slot t therefore drives the transmitter
     only in slot t plus the buffer depth, and until the first report has propagated through, the returned entry is
     marked invalid and the transmitter falls back to its initial scheme. The buffered payload is the uncorrected
     quality report, so the transmitter applies its current outer-loop offset at selection time.

 Input:
     buf          The delay-buffer state.
     depth        The delay in slots (at most RF_CQI_DELAY_MAX).
     new_report   The quality report measured in the current slot (RF_NUM_MCS entries per layer, nt layers).
     nt           Number of spatial layers.

 Output:
     out_report   The delayed report that drives the current slot (caller-allocated).
     return value   One if the returned report is valid, zero during the initial fill.
=========================================================================================================================
*/
void rf_cqi_delay_init(rf_cqi_delay_t *buf, size_t depth)
{
    if (depth > RF_CQI_DELAY_MAX) depth = RF_CQI_DELAY_MAX;  /* Bound the depth to the storage. */
    buf->depth = depth;                               /* Remember the configured delay. */
    for (size_t i = 0; i < depth; ++i)                /* Mark every slot as empty. */
        buf->valid[i] = 0;
}

int rf_cqi_delay_step(rf_cqi_delay_t *buf, const q16_t *new_report, size_t nt, q16_t *out_report)
{
    size_t entry_len = nt * RF_NUM_MCS_CODING;        /* Size of one buffered report. */
    int head_valid = buf->valid[0];                   /* Whether the oldest entry holds a real report. */

    if (head_valid)                                   /* Hand out the oldest report if there is one. */
        memcpy(out_report, buf->report[0], sizeof(q16_t) * entry_len);

    for (size_t i = 0; i + 1 < buf->depth; ++i) {     /* Shift the buffer toward the head. */
        memcpy(buf->report[i], buf->report[i + 1], sizeof(q16_t) * entry_len);
        buf->valid[i] = buf->valid[i + 1];
    }

    memcpy(buf->report[buf->depth - 1], new_report, sizeof(q16_t) * entry_len);  /* Insert the newest at the tail. */
    buf->valid[buf->depth - 1] = 1;

    return head_valid;                                /* Zero during the initial fill. */
}
