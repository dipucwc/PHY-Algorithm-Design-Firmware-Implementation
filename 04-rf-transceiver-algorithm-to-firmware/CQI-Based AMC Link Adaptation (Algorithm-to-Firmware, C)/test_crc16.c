/*
=========================================================================================================================
 *** test_crc16 ***
 Golden-vector test for the CRC-16 block check.
=========================================================================================================================

 Description:
     This test verifies that the C CRC produces the identical 16-bit remainder as the MATLAB reference over a range of
     message lengths. The quantity under test is the checksum itself, and the requirement is bit-exactness: because the
     block error rate of the whole physical layer is defined by this check, any deviation in even one remainder would
     change which blocks count as delivered. The purpose of the test is therefore to prove that the shift-register form
     used in the firmware computes the same polynomial division as the bit-vector form of the reference.

     The complete procedure runs in three steps. In the first step, the test reads the vector file, in which every line
     carries one case: the message length, the message bits packed as a hexadecimal string, and the reference remainder
     computed by the export script with the reference division. In the second step, each message is unpacked to one bit
     per byte, most-significant bit first, and the C CRC is computed over exactly those bits. In the third step, every
     computed remainder is compared with its reference for exact equality, any mismatch is printed with both values,
     and the test reports one summary line with the case and mismatch counts, returning zero only when every remainder
     matches.

 Input:
     vectors/crc16_vectors.csv   Per case: message length, message bits as hex, and the reference CRC as hex.

 Output:
     return value   Zero if the test passes, one if it fails.
     stdout         One line with the number of cases, the number of mismatches, and PASS or FAIL.

 Supporting files:
     header      rf_crc16.h (the function under test)
     reference   crc16_bits.m
=========================================================================================================================
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "rf_crc16.h"

/*
 hex2bits: unpack a hex string into one bit per byte, most-significant bit first.
     Input : hex     the hex string.
             nbits   the number of bits to produce.
     Output: bits    the filled bit array; returns the number of bits written.
*/
static int hex2bits(const char *hex, int nbits, uint8_t *bits)
{
    int nbytes = (nbits + 7) / 8, bi = 0;                /* Byte count and bit index. */
    for (int i = 0; i < nbytes; ++i) {                   /* One hex byte at a time. */
        char b[3] = { hex[2*i], hex[2*i+1], 0 };         /* Two hex digits. */
        unsigned v = (unsigned)strtoul(b, NULL, 16);     /* Their value. */
        for (int k = 7; k >= 0 && bi < nbits; --k)       /* Unpack, most-significant first. */
            bits[bi++] = (v >> k) & 1u;
    }
    return bi;
}

int main(void)
{
    FILE *f = fopen("vectors/crc16_vectors.csv", "r");   /* Open the vector file. */
    if (!f) { printf("FAIL: cannot open vectors\n"); return 2; }
    char line[8192];
    if (!fgets(line, sizeof line, f)) { fclose(f); return 2; }  /* Skip the header. */

    int cases = 0, fails = 0;                            /* Counters. */
    while (fgets(line, sizeof line, f)) {                /* One case per line. */
        int len = atoi(strtok(line, ","));               /* Message length. */
        char *hex = strtok(NULL, ",");                   /* Message as hex. */
        unsigned ref = (unsigned)strtoul(strtok(NULL, ","), NULL, 16);  /* Reference CRC. */
        uint8_t bits[4096];                              /* Bit buffer. */
        hex2bits(hex, len, bits);                        /* Unpack the message. */
        unsigned got = rf_crc16_bits(bits, (size_t)len); /* Compute the C CRC. */
        if (got != ref) {                                /* Must match exactly. */
            printf("  len=%d ref=%04x got=%04x MISMATCH\n", len, ref, got); ++fails;
        }
        ++cases;                                         /* One case done. */
    }
    fclose(f);

    printf("[test_crc16] %d cases, %d mismatches -> %s\n",  /* Report the result. */
           cases, fails, fails ? "FAIL" : "PASS");
    return fails ? 1 : 0;                                /* Exit status. */
}
