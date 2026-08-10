/* Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn> */
/* SPDX-License-Identifier: MulanPSL-2.0 */

#ifndef CRC_H
#define CRC_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef enum {
    CRC_STATUS_OK = 0,
    CRC_STATUS_INVALID_ARGUMENT = -1,
    CRC_STATUS_ILLEGAL_STATE = -2,
    CRC_STATUS_INCOMPATIBLE = -3,
    CRC_STATUS_HARDWARE_ERROR = -4
} crc_status_t;

typedef enum {
    CRC_WIDTH_7_BITS = 0,
    CRC_WIDTH_8_BITS = 1,
    CRC_WIDTH_16_BITS = 2,
    CRC_WIDTH_32_BITS = 3
} crc_width_t;

typedef enum {
    CRC_PROFILE_CRC7_MMC = 0,
    CRC_PROFILE_CRC8_SMBUS = 1,
    CRC_PROFILE_CRC16_CCITT_FALSE = 2,
    CRC_PROFILE_CRC16_ARC = 3,
    CRC_PROFILE_CRC32_ISO_HDLC = 4
} crc_profile_t;

typedef struct {
    uint32_t polynomial;
    uint32_t initial_value;
    uint32_t xor_out;
    crc_width_t width;
    bool reflect_input;
    bool reflect_output;
    bool byte_swap;
    bool lock_config;
} crc_config_t;

typedef struct {
    uint32_t raw_status;
    uint32_t raw_state;
    uint32_t result;
    uint32_t byte_count;
    uint32_t error_status;
    bool active;
    bool result_valid;
    bool config_locked;
} crc_snapshot_t;

crc_status_t crc_get_profile(crc_profile_t profile, crc_config_t *config);
crc_status_t crc_init(uintptr_t base, const crc_config_t *config);
crc_status_t crc_start(uintptr_t base);
crc_status_t crc_update(uintptr_t base, const void *data, size_t length);
crc_status_t crc_finish(uintptr_t base, uint32_t *result);
crc_status_t crc_abort(uintptr_t base);
crc_status_t crc_compute(uintptr_t base, const crc_config_t *config, const void *data,
                         size_t length, uint32_t *result);
crc_status_t crc_get_status(uintptr_t base, crc_snapshot_t *snapshot);
crc_status_t crc_clear_errors(uintptr_t base, uint32_t mask);

#endif
