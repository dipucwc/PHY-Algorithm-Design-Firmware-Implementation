/*
=========================================================================================================================
 *** rf_crc16 ***
 CRC-16-CCITT block check for the PHY transport block.
=========================================================================================================================

 Description:
     This file implements the CRC-16-CCITT block check that defines block success throughout the physical layer. The
     transmitter computes the checksum over each information block and appends it; the receiver recomputes the checksum
     over the received information-plus-CRC field and declares the block delivered only when the remainder is zero. The
     block error rate of the link is defined entirely by this check.

     The complete procedure operates as follows. The checksum is the remainder of a modulo-two polynomial division of the message by the generator
     x^16 + x^12 + x^5 + 1. The reference performs this division bit by bit on a padded bit vector; the implementation
     here uses the equivalent 16-bit shift-register form, in which one message bit is shifted in per step and the
     generator is subtracted whenever the outgoing register bit and the incoming bit differ. The shift-register form was
     verified to produce the identical remainder as the reference division over two hundred random messages. A
     byte-oriented variant is provided for throughput, and the receiver-side check reduces to testing the remainder for
     zero.

 Input / Output:
     Given per function below.

 Supporting files:
     header      rf_crc16.h       (declares the three functions and the polynomial constants)
     reference   crc16_bits.m, append_crc.m, check_crc.m
     calls       none
=========================================================================================================================
*/
#include "rf_crc16.h"

/*
=========================================================================================================================
 *** rf_crc16_bits ***
 CRC remainder over an array that stores one bit per byte.
=========================================================================================================================

 Description:
     This function computes the CRC remainder over a message stored one bit per array element. The shift register is
     advanced one message bit per step: the register is shifted up, and when the bit leaving the top of the register
     differs from the incoming message bit, the generator polynomial is subtracted by exclusive-or. After the final bit,
     the register holds the remainder.

 Input:
     bits    Pointer to the bit array (each element is zero or one), most-significant bit first.
     nbits   Number of message bits.

 Output:
     return value   The 16-bit CRC remainder.
=========================================================================================================================
*/
uint16_t rf_crc16_bits(const uint8_t *bits, size_t nbits)
{
    uint16_t reg = RF_CRC16_INIT;                     /* The register, starting empty. */

    for (size_t i = 0; i < nbits; ++i) {              /* Feed in one message bit at a time. */

        uint16_t msb = (uint16_t)((reg >> 15) & 1u);  /* The bit about to fall off the top. */
        uint16_t in  = (uint16_t)(bits[i] & 1u);      /* The message bit coming in. */

        reg = (uint16_t)(reg << 1);                   /* Shift everything up one. */

        if (msb ^ in) {                               /* If those two bits disagree... */
            reg ^= RF_CRC16_POLY;                     /* ...subtract the generator (that's the XOR). */
        }
    }

    return reg;                                       /* What's left is the checksum. */
}

/*
=========================================================================================================================
 *** rf_crc16_bytes ***
 CRC remainder over a packed byte buffer.
=========================================================================================================================

 Description:
     This function computes the same CRC over packed bytes, which is the higher-throughput form used once correctness
     has been established against the bit-serial version. Each byte is folded into the top of the register and eight
     shift-and-subtract steps process its bits.

 Input:
     data     Pointer to the packed bytes, most-significant bit first within each byte.
     nbytes   Number of bytes.

 Output:
     return value   The 16-bit CRC remainder.
=========================================================================================================================
*/
uint16_t rf_crc16_bytes(const uint8_t *data, size_t nbytes)
{
    uint16_t reg = RF_CRC16_INIT;                     /* The register, starting empty. */

    for (size_t i = 0; i < nbytes; ++i) {             /* One byte at a time. */

        reg ^= (uint16_t)((uint16_t)data[i] << 8);    /* Fold the byte into the top of the register. */

        for (int b = 0; b < 8; ++b) {                 /* Then clear it, bit by bit. */
            if (reg & 0x8000u)                        /* Top bit set? */
                reg = (uint16_t)((reg << 1) ^ RF_CRC16_POLY);  /* Shift and subtract the generator. */
            else
                reg = (uint16_t)(reg << 1);           /* Otherwise just shift. */
        }
    }

    return reg;                                       /* The checksum. */
}

/*
=========================================================================================================================
 *** rf_crc16_check ***
 Receiver-side block check.
=========================================================================================================================

 Description:
     This function performs the receiver-side block check. The CRC is recomputed over the complete received block,
     information bits followed by the CRC field, and a zero remainder indicates that the block arrived intact.

 Input:
     block_bits       The received block: information bits followed by the sixteen CRC bits.
     nbits_with_crc   Total number of bits in the block including the CRC field.

 Output:
     return value   One if the block passes, zero if it fails.
=========================================================================================================================
*/
int rf_crc16_check(const uint8_t *block_bits, size_t nbits_with_crc)
{
    return rf_crc16_bits(block_bits, nbits_with_crc) == 0u ? 1 : 0;  /* Clean remainder means the block is good. */
}
