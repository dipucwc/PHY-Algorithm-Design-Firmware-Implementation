/*
=========================================================================================================================
 *** rf_regmap ***
 Register-map abstraction for the RF transceiver control block.
=========================================================================================================================

 Description:
     Defines a small set of memory-mapped registers that the control firmware writes to configure the transceiver and
     reads to observe its status, together with simple read and write accessors.

     Each register has a fixed byte offset in a control block. During host testing the block is an ordinary array; on
     real hardware the same code points at the hardware address instead, so the control logic never changes. This is why
     the MCS selector and the state machine talk to the register map rather than to hardware directly.

 Input / Output:
     The accessors take a register-file pointer and a register offset; documented at each function.

 Supporting files:
     used by     rf_state.c
     reference   (the register interface a real transceiver would expose)
=========================================================================================================================
*/
#ifndef RF_REGMAP_H
#define RF_REGMAP_H

#include <stdint.h>

/* Byte offsets of the registers in the control block. */
typedef enum {
    RF_REG_CTRL        = 0x00,  /* Control: bit zero is transmit enable, bit one is receive enable. */
    RF_REG_MCS         = 0x04,  /* Selected MCS index, zero to eight. */
    RF_REG_TARGET_BLER = 0x08,  /* Target BLER, Q16.16. */
    RF_REG_OLLA_OFFSET = 0x0C,  /* Outer-loop offset in decibels, Q16.16, signed. */
    RF_REG_EFF_SINR    = 0x10,  /* Last reported effective SINR in decibels, Q16.16. */
    RF_REG_STATE       = 0x14,  /* Current state-machine state. */
    RF_REG_STATUS      = 0x18,  /* Last selection status code. */
    RF_REG_CRC_ERRORS  = 0x1C,  /* Running count of CRC-failed blocks. */
    RF_REG_BLOCKS      = 0x20,  /* Running count of total blocks. */
    RF_REG_COUNT       = 0x24   /* Size of the register block in bytes. */
} rf_reg_offset_t;

#define RF_CTRL_TX_EN   (1u << 0)   /* Transmit-enable bit in the control register. */
#define RF_CTRL_RX_EN   (1u << 1)   /* Receive-enable bit in the control register. */

/* The register file. On host it is an array; on target, point it at the hardware aperture. */
typedef struct {
    volatile uint32_t reg[RF_REG_COUNT / 4];
} rf_regfile_t;

/* rf_reg_read: read one register. Input: rf, off. Output: the 32-bit register value. */
static inline uint32_t rf_reg_read(const rf_regfile_t *rf, rf_reg_offset_t off)
{
    return rf->reg[off >> 2];                          /* Offset is in bytes; the array is in words. */
}

/* rf_reg_write: write one register. Input: rf, off, val. Output: (none). */
static inline void rf_reg_write(rf_regfile_t *rf, rf_reg_offset_t off, uint32_t val)
{
    rf->reg[off >> 2] = val;                           /* Store into the corresponding word. */
}

#endif /* RF_REGMAP_H */
