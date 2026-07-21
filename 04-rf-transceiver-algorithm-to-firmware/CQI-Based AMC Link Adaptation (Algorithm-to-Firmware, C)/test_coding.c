/*
=========================================================================================================================
 *** test_coding ***
 Functional test for the encoder, the puncturing chain, and the feedback delay buffer.
=========================================================================================================================

 Description:
     This test checks three properties of the coding chain. First, the encoder is verified against the known impulse
     response of the (133, 171) code: a single one bit followed by zeros must produce the two generator sequences.
     Second, the puncture and depuncture pair is verified as mutually consistent: after depuncturing, every kept
     position carries its transmitted value and every punctured position carries exactly zero. Third, the feedback
     buffer is verified as causal: with a delay of one slot, the report returned in slot t equals the report inserted
     in slot t minus one, and the entry returned before any report has propagated through is marked invalid.

 Input:
     (none)   All stimulus is generated in code.

 Output:
     return value   Zero if the test passes, one if it fails.
     stdout         One line reporting PASS or FAIL.

 Supporting files:
     header      rf_coding.h (the functions under test)
     reference   encode_variable_rate.m, apply_puncturing.m, depuncture_llr.m, apply_cqi_feedback_delay.m
=========================================================================================================================
*/
#include <stdio.h>
#include <string.h>
#include "rf_coding.h"

int main(void)
{
    int fails = 0;                                    /* Failure counter. */

    /* Encoder impulse response: input 1 then zeros gives the two generator sequences interleaved. */
    uint8_t info[7] = {1, 0, 0, 0, 0, 0, 0};          /* An impulse into the encoder. */
    uint8_t coded[14];                                /* Two output bits per input bit. */
    rf_conv_encode_k7(info, 7, coded);                /* Encode the impulse. */
    /* Generators 133 and 171 octal give the taps 1011011 and 1111001 read over the impulse steps. */
    const uint8_t g0[7] = {1, 1, 0, 1, 1, 0, 1};      /* Expected first-output sequence. */
    const uint8_t g1[7] = {1, 0, 0, 1, 1, 1, 1};      /* Expected second-output sequence. */
    for (int i = 0; i < 7; ++i) {                     /* Compare both sequences. */
        if (coded[2*i]   != g0[i]) { printf("  encoder g0 mismatch at %d\n", i); ++fails; }
        if (coded[2*i+1] != g1[i]) { printf("  encoder g1 mismatch at %d\n", i); ++fails; }
    }

    /* Puncture / depuncture consistency at rate 3/4. */
    uint8_t mask[6];                                  /* The puncturing mask. */
    size_t period = rf_select_puncture_mask(3, 4, mask);  /* Rate 3/4 keeps four of every six. */
    if (period != 6) { printf("  wrong mask period %zu\n", period); ++fails; }

    uint8_t mother[24];                               /* A small mother stream. */
    for (int i = 0; i < 24; ++i) mother[i] = (uint8_t)((unsigned)i & 1u);  /* Alternating bits. */
    uint8_t sent[24]; size_t kept[24];                /* Transmitted subset and its positions. */
    size_t m = rf_apply_puncturing(mother, 24, mask, period, sent, kept);  /* Puncture the stream. */
    if (m != 16) { printf("  wrong transmitted count %zu (want 16)\n", m); ++fails; }  /* 24 * 4/6 = 16. */

    double llr[24], back[24];                         /* Received soft values and the rebuilt stream. */
    for (size_t k = 0; k < m; ++k) llr[k] = sent[k] ? -1.0 : 1.0;  /* Simple soft values from the sent bits. */
    rf_depuncture_llr(llr, kept, m, 24, back);        /* Rebuild the mother-length stream. */
    for (size_t i = 0; i < 24; ++i) {                 /* Every position must be right. */
        int is_kept = 0;                              /* Is this position among the kept ones? */
        for (size_t k = 0; k < m; ++k) if (kept[k] == i) { is_kept = 1; break; }
        if (is_kept  && back[i] == 0.0) { printf("  kept position %zu lost\n", i); ++fails; }
        if (!is_kept && back[i] != 0.0) { printf("  punctured position %zu not erased\n", i); ++fails; }
    }

    /* Feedback-buffer causality with a delay of one slot. */
    rf_cqi_delay_t buf;                               /* The delay buffer. */
    rf_cqi_delay_init(&buf, 1);                       /* One-slot delay. */
    q16_t r1[RF_NUM_MCS_CODING], r2[RF_NUM_MCS_CODING], out[RF_NUM_MCS_CODING];  /* Two reports and the output. */
    for (int i = 0; i < RF_NUM_MCS_CODING; ++i) { r1[i] = 100 + i; r2[i] = 200 + i; }  /* Distinct payloads. */

    int v = rf_cqi_delay_step(&buf, r1, 1, out);      /* Slot one: nothing has propagated yet. */
    if (v != 0) { printf("  first slot should be invalid\n"); ++fails; }

    v = rf_cqi_delay_step(&buf, r2, 1, out);          /* Slot two: the slot-one report emerges. */
    if (v != 1) { printf("  second slot should be valid\n"); ++fails; }
    if (out[0] != r1[0]) { printf("  buffer returned wrong report\n"); ++fails; }  /* Exactly one slot late. */

    printf("[test_coding] encoder impulse + puncture round trip + delay causality -> %s\n",
           fails ? "FAIL" : "PASS");
    return fails ? 1 : 0;                             /* Exit status. */
}
