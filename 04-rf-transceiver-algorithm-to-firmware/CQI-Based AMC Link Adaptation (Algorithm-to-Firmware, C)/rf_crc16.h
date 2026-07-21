/*
=========================================================================================================================
 *** rf_crc16 (header) ***
 Declarations for the CRC-16-CCITT block check.
=========================================================================================================================

 Description:
     Declares the CRC routines and the polynomial constants implemented in rf_crc16.c.

     Generator polynomial x^16 + x^12 + x^5 + 1, written as the constant 0x1021 with the implicit leading one, and an
     all-zero initial register, matching the reference.

 Supporting files:
     implemented in   rf_crc16.c
     reference        crc16_bits.m, append_crc.m, check_crc.m
=========================================================================================================================
*/
#ifndef RF_CRC16_H
#define RF_CRC16_H

#include <stdint.h>
#include <stddef.h>

#define RF_CRC16_POLY   0x1021u   /* x^16 + x^12 + x^5 + 1, implicit leading one. */
#define RF_CRC16_INIT   0x0000u   /* All-zero initial register (matches the reference). */

uint16_t rf_crc16_bits (const uint8_t *bits, size_t nbits);          /* CRC over a one-bit-per-byte array. */
uint16_t rf_crc16_bytes(const uint8_t *data, size_t nbytes);         /* CRC over packed bytes. */
int      rf_crc16_check(const uint8_t *block_bits, size_t nbits_with_crc);  /* One if the block passes, zero if not. */

#endif /* RF_CRC16_H */
