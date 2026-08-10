/* Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn> */
/* SPDX-License-Identifier: MulanPSL-2.0 */

#include "crc.h"

#include <stddef.h>

#include "crc_regs.h"

static volatile uint32_t *crc_register32(uintptr_t base, uint32_t offset) {
    return (volatile uint32_t *)(base + (uintptr_t)offset);
}

static volatile uint16_t *crc_register16(uintptr_t base, uint32_t offset) {
    return (volatile uint16_t *)(base + (uintptr_t)offset);
}

static volatile uint8_t *crc_register8(uintptr_t base, uint32_t offset) {
    return (volatile uint8_t *)(base + (uintptr_t)offset);
}

static uint32_t crc_read_register(uintptr_t base, uint32_t offset) {
    return *crc_register32(base, offset);
}

static void crc_write_register(uintptr_t base, uint32_t offset, uint32_t value) {
    *crc_register32(base, offset) = value;
}

static uint32_t crc_width_mask(crc_width_t width) {
    uint32_t mask;

    switch (width) {
    case CRC_WIDTH_7_BITS:
        mask = UINT32_C(0x0000007F);
        break;
    case CRC_WIDTH_8_BITS:
        mask = UINT32_C(0x000000FF);
        break;
    case CRC_WIDTH_16_BITS:
        mask = UINT32_C(0x0000FFFF);
        break;
    case CRC_WIDTH_32_BITS:
        mask = UINT32_C(0xFFFFFFFF);
        break;
    default:
        mask = 0U;
        break;
    }

    return mask;
}

static bool crc_config_valid(const crc_config_t *config) {
    uint32_t mask;

    if (config == NULL) {
        return false;
    }
    mask = crc_width_mask(config->width);
    return (mask != 0U) && ((config->polynomial & UINT32_C(1)) != 0U) &&
           ((config->polynomial & ~mask) == 0U);
}

static uint32_t crc_config_value(const crc_config_t *config) {
    uint32_t value = (uint32_t)config->width;

    if (config->reflect_input) {
        value |= CRC_CONFIG_REFLECT_IN_MASK;
    }
    if (config->reflect_output) {
        value |= CRC_CONFIG_REFLECT_OUT_MASK;
    }
    if (config->byte_swap) {
        value |= CRC_CONFIG_BYTE_SWAP_MASK;
    }
    return value;
}

crc_status_t crc_get_profile(crc_profile_t profile, crc_config_t *config) {
    if (config == NULL) {
        return CRC_STATUS_INVALID_ARGUMENT;
    }

    config->byte_swap = false;
    config->lock_config = false;
    switch (profile) {
    case CRC_PROFILE_CRC7_MMC:
        config->polynomial = UINT32_C(0x09);
        config->initial_value = UINT32_C(0x00);
        config->xor_out = UINT32_C(0x00);
        config->width = CRC_WIDTH_7_BITS;
        config->reflect_input = false;
        config->reflect_output = false;
        break;
    case CRC_PROFILE_CRC8_SMBUS:
        config->polynomial = UINT32_C(0x07);
        config->initial_value = UINT32_C(0x00);
        config->xor_out = UINT32_C(0x00);
        config->width = CRC_WIDTH_8_BITS;
        config->reflect_input = false;
        config->reflect_output = false;
        break;
    case CRC_PROFILE_CRC16_CCITT_FALSE:
        config->polynomial = UINT32_C(0x1021);
        config->initial_value = UINT32_C(0xFFFF);
        config->xor_out = UINT32_C(0x0000);
        config->width = CRC_WIDTH_16_BITS;
        config->reflect_input = false;
        config->reflect_output = false;
        break;
    case CRC_PROFILE_CRC16_ARC:
        config->polynomial = UINT32_C(0x8005);
        config->initial_value = UINT32_C(0x0000);
        config->xor_out = UINT32_C(0x0000);
        config->width = CRC_WIDTH_16_BITS;
        config->reflect_input = true;
        config->reflect_output = true;
        break;
    case CRC_PROFILE_CRC32_ISO_HDLC:
        config->polynomial = UINT32_C(0x04C11DB7);
        config->initial_value = UINT32_C(0xFFFFFFFF);
        config->xor_out = UINT32_C(0xFFFFFFFF);
        config->width = CRC_WIDTH_32_BITS;
        config->reflect_input = true;
        config->reflect_output = true;
        break;
    default:
        return CRC_STATUS_INVALID_ARGUMENT;
    }
    return CRC_STATUS_OK;
}

crc_status_t crc_init(uintptr_t base, const crc_config_t *config) {
    uint32_t capability;
    uint32_t status;

    if ((base == (uintptr_t)0U) || !crc_config_valid(config)) {
        return CRC_STATUS_INVALID_ARGUMENT;
    }
    if ((crc_read_register(base, CRC_IP_ID_OFFSET) != CRC_IP_ID_VALUE) ||
        (crc_read_register(base, CRC_IP_VERSION_OFFSET) != CRC_IP_VERSION_VALUE)) {
        return CRC_STATUS_INCOMPATIBLE;
    }
    capability = crc_read_register(base, CRC_CAPABILITY_OFFSET);
    if (((capability & CRC_CAPABILITY_ABI_MASK) >> CRC_CAPABILITY_ABI_SHIFT) != CRC_ABI_VERSION) {
        return CRC_STATUS_INCOMPATIBLE;
    }
    status = crc_read_register(base, CRC_STATUS_OFFSET);
    if ((status & (CRC_STATUS_ACTIVE_MASK | CRC_STATUS_CONFIG_LOCKED_MASK)) != 0U) {
        return CRC_STATUS_ILLEGAL_STATE;
    }

    crc_write_register(base, CRC_ERROR_STATUS_OFFSET, CRC_ERROR_ALL_MASK);
    crc_write_register(base, CRC_CONFIG_OFFSET, crc_config_value(config));
    crc_write_register(base, CRC_POLYNOMIAL_OFFSET, config->polynomial);
    crc_write_register(base, CRC_INIT_OFFSET, config->initial_value);
    crc_write_register(base, CRC_XOR_OUT_OFFSET, config->xor_out);
    if (config->lock_config) {
        crc_write_register(base, CRC_CONFIG_LOCK_OFFSET, CRC_CONFIG_LOCK_MASK);
    }
    return CRC_STATUS_OK;
}

crc_status_t crc_start(uintptr_t base) {
    if (base == (uintptr_t)0U) {
        return CRC_STATUS_INVALID_ARGUMENT;
    }
    if ((crc_read_register(base, CRC_STATUS_OFFSET) & CRC_STATUS_ACTIVE_MASK) != 0U) {
        return CRC_STATUS_ILLEGAL_STATE;
    }
    crc_write_register(base, CRC_CTRL_OFFSET, CRC_CTRL_START_MASK);
    return CRC_STATUS_OK;
}

crc_status_t crc_update(uintptr_t base, const void *data, size_t length) {
    const uint8_t *bytes = (const uint8_t *)data;
    size_t index = 0U;

    if ((base == (uintptr_t)0U) || ((data == NULL) && (length != 0U))) {
        return CRC_STATUS_INVALID_ARGUMENT;
    }
    if ((crc_read_register(base, CRC_STATUS_OFFSET) & CRC_STATUS_ACTIVE_MASK) == 0U) {
        return CRC_STATUS_ILLEGAL_STATE;
    }

    while ((length - index) >= 4U) {
        uint32_t word = (uint32_t)bytes[index] | ((uint32_t)bytes[index + 1U] << 8U) |
                        ((uint32_t)bytes[index + 2U] << 16U) | ((uint32_t)bytes[index + 3U] << 24U);
        *crc_register32(base, CRC_DATA_OFFSET) = word;
        index += 4U;
    }
    if ((length - index) >= 2U) {
        uint16_t halfword =
            (uint16_t)((uint16_t)bytes[index] | (uint16_t)((uint16_t)bytes[index + 1U] << 8U));
        *crc_register16(base, CRC_DATA_OFFSET) = halfword;
        index += 2U;
    }
    if (index < length) {
        *crc_register8(base, CRC_DATA_OFFSET) = bytes[index];
    }
    return CRC_STATUS_OK;
}

crc_status_t crc_finish(uintptr_t base, uint32_t *result) {
    if ((base == (uintptr_t)0U) || (result == NULL)) {
        return CRC_STATUS_INVALID_ARGUMENT;
    }
    if ((crc_read_register(base, CRC_STATUS_OFFSET) & CRC_STATUS_ACTIVE_MASK) == 0U) {
        return CRC_STATUS_ILLEGAL_STATE;
    }
    crc_write_register(base, CRC_CTRL_OFFSET, CRC_CTRL_FINISH_MASK);
    *result = crc_read_register(base, CRC_RESULT_OFFSET);
    return CRC_STATUS_OK;
}

crc_status_t crc_abort(uintptr_t base) {
    if (base == (uintptr_t)0U) {
        return CRC_STATUS_INVALID_ARGUMENT;
    }
    if ((crc_read_register(base, CRC_STATUS_OFFSET) & CRC_STATUS_ACTIVE_MASK) == 0U) {
        return CRC_STATUS_ILLEGAL_STATE;
    }
    crc_write_register(base, CRC_CTRL_OFFSET, CRC_CTRL_ABORT_MASK);
    return CRC_STATUS_OK;
}

crc_status_t crc_compute(uintptr_t base, const crc_config_t *config, const void *data,
                         size_t length, uint32_t *result) {
    crc_status_t status;

    if (result == NULL) {
        return CRC_STATUS_INVALID_ARGUMENT;
    }
    status = crc_init(base, config);
    if (status == CRC_STATUS_OK) {
        status = crc_start(base);
    }
    if (status == CRC_STATUS_OK) {
        status = crc_update(base, data, length);
    }
    if (status == CRC_STATUS_OK) {
        status = crc_finish(base, result);
    }
    return status;
}

crc_status_t crc_get_status(uintptr_t base, crc_snapshot_t *snapshot) {
    uint32_t status;

    if ((base == (uintptr_t)0U) || (snapshot == NULL)) {
        return CRC_STATUS_INVALID_ARGUMENT;
    }
    status = crc_read_register(base, CRC_STATUS_OFFSET);
    snapshot->raw_status = status;
    snapshot->raw_state = crc_read_register(base, CRC_RAW_STATE_OFFSET);
    snapshot->result = (status & CRC_STATUS_RESULT_VALID_MASK) != 0U
                           ? crc_read_register(base, CRC_RESULT_OFFSET)
                           : 0U;
    snapshot->byte_count = crc_read_register(base, CRC_BYTE_COUNT_OFFSET);
    snapshot->error_status = crc_read_register(base, CRC_ERROR_STATUS_OFFSET);
    snapshot->active = (status & CRC_STATUS_ACTIVE_MASK) != 0U;
    snapshot->result_valid = (status & CRC_STATUS_RESULT_VALID_MASK) != 0U;
    snapshot->config_locked = (status & CRC_STATUS_CONFIG_LOCKED_MASK) != 0U;
    return snapshot->error_status == 0U ? CRC_STATUS_OK : CRC_STATUS_HARDWARE_ERROR;
}

crc_status_t crc_clear_errors(uintptr_t base, uint32_t mask) {
    if ((base == (uintptr_t)0U) || ((mask & ~CRC_ERROR_ALL_MASK) != 0U)) {
        return CRC_STATUS_INVALID_ARGUMENT;
    }
    crc_write_register(base, CRC_ERROR_STATUS_OFFSET, mask);
    return CRC_STATUS_OK;
}
