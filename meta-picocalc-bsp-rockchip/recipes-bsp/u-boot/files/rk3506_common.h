/* SPDX-License-Identifier:     GPL-2.0+ */
/*
 * (C) Copyright 2024 Rockchip Electronics Co., Ltd
 *
 */

#ifndef __CONFIG_RK3506_COMMON_H
#define __CONFIG_RK3506_COMMON_H

#include "rockchip-common.h"

#ifdef CONFIG_ENV_IS_IN_MMC
#define CONFIG_SYS_MMC_ENV_DEV     0
#define CONFIG_SYS_MMC_ENV_PART    0
#endif
#undef CONFIG_ENV_OFFSET
#undef CONFIG_ENV_OFFSET_REDUND
#define CONFIG_SYS_REDUNDAND_ENVIRONMENT
#define CONFIG_ENV_OFFSET	 0x600000
#define CONFIG_ENV_OFFSET_REDUND (CONFIG_ENV_OFFSET + CONFIG_ENV_SIZE)


#define COUNTER_FREQUENCY		24000000
#define CONFIG_SYS_MALLOC_LEN		(16 << 20)
#define CONFIG_SYS_CBSIZE		1024
#define CONFIG_SYS_TEXT_BASE		0x00200000
#define CONFIG_SYS_INIT_SP_ADDR		0x00600000
#define CONFIG_SYS_LOAD_ADDR		0x00008000
#define CONFIG_SYS_BOOTM_LEN		(64 << 20)	/* 64M */
#define CONFIG_SYS_SDRAM_BASE		0
#define SDRAM_MAX_SIZE			0xc0000000
#define CONFIG_SYS_NONCACHED_MEMORY	(1 << 20)	/* 1 MiB */

/* SPL */
#define CONFIG_SPL_FRAMEWORK
#define CONFIG_SPL_TEXT_BASE		0x03f00000
#define CONFIG_SPL_MAX_SIZE		0x40000
#define CONFIG_SPL_BSS_START_ADDR	0x03fe0000
#define CONFIG_SPL_BSS_MAX_SIZE		0x20000
#define CONFIG_SPL_STACK		0x03f00000

#define GICD_BASE			0xff581000
#define GICC_BASE			0xff582000

#define ATAGS_OFFSET			0x62000
#define ATAGS_SIZE			0x01000

/* secure otp */
#define OTP_UBOOT_ROLLBACK_OFFSET	0x350
#define OTP_UBOOT_ROLLBACK_WORDS	2	/* 64 bits, 2 words */
#define OTP_ALL_ONES_NUM_BITS		32
#define OTP_SECURE_BOOT_ENABLE_ADDR	0x20
#define OTP_SECURE_BOOT_ENABLE_SIZE	1
#define OTP_RSA_HASH_ADDR		0x180
#define OTP_RSA_HASH_SIZE		32

/* MMC/SD IP block */
#define CONFIG_BOUNCE_BUFFER
#define CONFIG_PRAM			6144

#ifndef CONFIG_SPL_BUILD
/* usb mass storage */
#define CONFIG_USB_FUNCTION_MASS_STORAGE
#define CONFIG_ROCKUSB_G_DNL_PID	0x350f

#define CONFIG_LIB_HW_RAND
#define CONFIG_PREBOOT

/*
 *     fdt:  396K - 1M   (was 396K - 524K; enlarged for DTBs with __symbols__)
 *   Image:  1M+256k - 16M
 *  zImage:  16M - 24M
 * ramdisk:  24M - ...
 *
 * NOTE: kernel_addr_r was moved from 0x108000 (1M+32K) to 0x140000 (1M+256K)
 * to leave ~832 KB for the FDT.  The trimmed DTB with selective __symbols__
 * is typically ~80 KB, but this headroom protects against future growth and
 * allows U-Boot to expand the FDT with boot arguments without risk.
 */
#define ENV_MEM_LAYOUT_SETTINGS \
	"scriptaddr=0x00b00000\0"	\
	"pxefile_addr_r=0x00c00000\0"	\
	"fdt_addr_r=0x00063000\0"	\
	"kernel_addr_r=0x00140000\0"	\
	"kernel_addr_c=0x01100000\0"	\
	"ramdisk_addr_r=0x01800000\0"

#include <config_distro_bootcmd.h>

#define CONFIG_EXTRA_ENV_SETTINGS \
	ENV_MEM_LAYOUT_SETTINGS												\
	"partitions=" PARTS_RKIMG											\
	"calculinux_bootcmd="												\
 	"env exists BOOT_ORDER || setenv BOOT_ORDER A B; "						\
	"for boot_part_letter in ${BOOT_ORDER}; do "						\
	    "part number ${devtype} ${devnum} ROOT_${boot_part_letter} distro_bootpart_hex; " \
	    "setexpr distro_bootpart fmt %d ${distro_bootpart_hex}; " \
	    "run scan_dev_for_boot; "								  \
	"done\0"												  \
	ROCKCHIP_DEVICE_SETTINGS								  \
	RKIMG_DET_BOOTDEV										  \
	BOOTENV

#undef RKIMG_BOOTCOMMAND
#define RKIMG_BOOTCOMMAND								\
	"run rkimg_bootdev; run calculinux_bootcmd;"
#endif
#endif
