/* SPDX-License-Identifier: GPL-2.0-or-later */
/* Copyright Contributors to the U-Boot project. */

#ifndef __CONFIG_RK3506_COMMON_H
#define __CONFIG_RK3506_COMMON_H

#define CFG_CPUID_OFFSET        0xa

#include "rockchip-common.h"

#define CFG_IRAM_BASE           0xfff80000

#define CFG_SYS_SDRAM_BASE      0
#define CFG_SYS_SDRAM_RESERVE       SZ_1M
#define SDRAM_MAX_SIZE          0xc0000000

#undef ROCKCHIP_DEVICE_SETTINGS
#define ROCKCHIP_DEVICE_SETTINGS \
        "stdin=serial,usbkbd\0" \
        "stdout=serial,vidconsole\0" \
        "stderr=serial,vidconsole\0"

#define ENV_MEM_LAYOUT_SETTINGS         \
    "scriptaddr=0x00500000\0"       \
    "script_offset_f=0xffe000\0"        \
    "script_size_f=0x2000\0"        \
    "pxefile_addr_r=0x00600000\0"       \
    "kernel_addr_r=0x02080000\0"        \
    "kernel_comp_addr_r=0x08000000\0"   \
    "fdt_addr_r=0x01e00000\0"       \
    "fdtoverlay_addr_r=0x01f00000\0"    \
    "ramdisk_addr_r=0x06000000\0"       \
    "kernel_comp_size=0x2000000\0"

#define CFG_EXTRA_ENV_SETTINGS                                          \
    "fdtfile=" CONFIG_DEFAULT_FDT_FILE "\0"                             \
    ENV_MEM_LAYOUT_SETTINGS                                             \
    ROCKCHIP_DEVICE_SETTINGS                                            \
    "boot_targets=" BOOT_TARGETS "\0"                                   \
    "calculinux_bootcmd="                                               \
    "env exists BOOT_ORDER || setenv BOOT_ORDER A B; "                  \
    "for boot_part_letter in ${BOOT_ORDER}; do "                        \
        "part number ${devtype} ${devnum} ROOT_${boot_part_letter} distro_bootpart_hex; " \
        "setexpr distro_bootpart fmt %d ${distro_bootpart_hex}; "           \
        "run scan_dev_for_boot; "                                           \
    "done\0"


#undef RKIMG_BOOTCOMMAND
#define RKIMG_BOOTCOMMAND                           \
    "run rkimg_bootdev; run calculinux_bootcmd;"

#endif /* __CONFIG_RK3506_COMMON_H */
