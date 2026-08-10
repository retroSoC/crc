/* Copyright (c) 2023-2026 Yuchi Miao <miaoyuchi@ict.ac.cn> */
/* SPDX-License-Identifier: MulanPSL-2.0 */

#include "crc.h"

#include <assert.h>
#include <stdint.h>

#include "crc_regs.h"

int main(void) {
    uint32_t registers[65] = {0U};
    const uintptr_t base = (uintptr_t)&registers[0];
    const uint8_t data[9] = {'1', '2', '3', '4', '5', '6', '7', '8', '9'};
    crc_config_t config;
    crc_snapshot_t snapshot;
    uint32_t result = 0U;

    registers[CRC_IP_ID_OFFSET / 4U] = CRC_IP_ID_VALUE;
    registers[CRC_IP_VERSION_OFFSET / 4U] = CRC_IP_VERSION_VALUE;
    registers[CRC_CAPABILITY_OFFSET / 4U] =
        (CRC_ABI_VERSION << CRC_CAPABILITY_ABI_SHIFT) | CRC_CAPABILITY_FEATURES;

    assert(crc_get_profile(CRC_PROFILE_CRC32_ISO_HDLC, &config) == CRC_STATUS_OK);
    assert(crc_init(base, &config) == CRC_STATUS_OK);
    registers[CRC_ERROR_STATUS_OFFSET / 4U] = 0U;
    assert(registers[CRC_CONFIG_OFFSET / 4U] == UINT32_C(0x0F));
    assert(registers[CRC_POLYNOMIAL_OFFSET / 4U] == UINT32_C(0x04C11DB7));
    assert(crc_start(base) == CRC_STATUS_OK);
    assert(registers[CRC_CTRL_OFFSET / 4U] == CRC_CTRL_START_MASK);

    registers[CRC_STATUS_OFFSET / 4U] = CRC_STATUS_ACTIVE_MASK;
    assert(crc_update(base, data, sizeof(data)) == CRC_STATUS_OK);
    registers[CRC_RESULT_OFFSET / 4U] = UINT32_C(0xCBF43926);
    assert(crc_finish(base, &result) == CRC_STATUS_OK);
    assert(result == UINT32_C(0xCBF43926));

    registers[CRC_STATUS_OFFSET / 4U] = CRC_STATUS_RESULT_VALID_MASK;
    registers[CRC_RAW_STATE_OFFSET / 4U] = UINT32_C(0x9B63D02C);
    registers[CRC_BYTE_COUNT_OFFSET / 4U] = 9U;
    assert(crc_get_status(base, &snapshot) == CRC_STATUS_OK);
    assert(snapshot.result_valid && (snapshot.byte_count == 9U));

    assert(crc_get_profile((crc_profile_t)99, &config) == CRC_STATUS_INVALID_ARGUMENT);
    assert(crc_start((uintptr_t)0U) == CRC_STATUS_INVALID_ARGUMENT);
    assert(crc_update(base, NULL, 1U) == CRC_STATUS_INVALID_ARGUMENT);
    assert(crc_finish(base, NULL) == CRC_STATUS_INVALID_ARGUMENT);
    assert(crc_clear_errors(base, UINT32_C(0x80)) == CRC_STATUS_INVALID_ARGUMENT);

    config.polynomial = UINT32_C(0x04C11DB6);
    assert(crc_init(base, &config) == CRC_STATUS_INVALID_ARGUMENT);
    registers[CRC_ERROR_STATUS_OFFSET / 4U] = CRC_ERROR_ACCESS_MASK;
    assert(crc_get_status(base, &snapshot) == CRC_STATUS_HARDWARE_ERROR);

    return 0;
}
