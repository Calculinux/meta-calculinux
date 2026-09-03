#!/bin/sh
# RAUC slot-post-install: migrate vendor U-Boot → mainline (or bump mainline).
# Abort with a flash-WIC message if the bootloader cannot be applied over OTA.
set -eu

UBOOT_SEEK_BYTES=32768
UBOOTENV_OFFSET_BYTES=6291456    # 6 MiB (vendor + field GPT ubootenv)
UBOOTENV_SIZE_BYTES=1048576      # 1 MiB
ROOT_A_EXPECT_BYTES=8388608      # 8 MiB (field cards / new WIC)
VENDOR_ENV_OFFSET=6291456        # 6 MiB (same as ubootenv)
ENV_SIZE=32768                   # 0x8000
BLOB_PATH_REL="usr/lib/calculinux/u-boot-rockchip.bin"
BACKUP_PATH="/data/uboot-ota-backup.bin"
BACKUP_SHA_PATH="/data/uboot-ota-backup.sha256"
FW_ENV_PATH="/etc/fw_env.config"
FW_ENV_BAK="/data/uboot-ota-fw_env.config.bak"
NEW_FW_ENV="\
/dev/disk/by-partlabel/ubootenv	0x0000000	0x8000
/dev/disk/by-partlabel/ubootenv	0x0008000	0x8000
"

flash_wic() {
	msg=$1
	printf '%s\n' \
		"ERROR: $msg" \
		"This card cannot take the bootloader over OTA." \
		"Flash the full Calculinux WIC image to the SD card instead." \
		>&2
	exit 1
}

flash_wic_may_brick() {
	printf '%s\n' \
		"ERROR: Bootloader write failed and restore also failed." \
		"The card may not boot. Flash the full Calculinux WIC image." \
		>&2
	exit 1
}

# Bytes → MiB string for messages (integer division).
bytes_mib() {
	echo $(($1 / 1048576))
}

# Logical sector size for $1 (e.g. /dev/mmcblk0). Default 512.
disk_sector_size() {
	disk=$1
	base=$(basename "$disk")
	ss=
	if [ -r "/sys/block/$base/queue/logical_block_size" ]; then
		ss=$(cat "/sys/block/$base/queue/logical_block_size")
	elif command -v blockdev >/dev/null 2>&1; then
		ss=$(blockdev --getss "$disk" 2>/dev/null || true)
	fi
	case "$ss" in
		*[!0-9]*|"") echo 512 ;;
		*) echo "$ss" ;;
	esac
}

# Return partition start (bytes) for PARTLABEL=$1 on disk $2, or empty.
# lsblk START is always in sectors; -b only affects SIZE.
partlabel_start_bytes() {
	label=$1
	disk=$2
	ss=$(disk_sector_size "$disk")
	lsblk -n -o START,PARTLABEL "$disk" 2>/dev/null \
		| awk -v l="$label" -v ss="$ss" '
			$2 == l { print $1 * ss; exit }
		'
}

# Preflight: ROOT_A must start at 8 MiB. Args: start_bytes. Echo ok|fail.
preflight_root_a() {
	start=$1
	if [ -z "$start" ]; then
		echo fail
		return 1
	fi
	if [ "$start" -ne "$ROOT_A_EXPECT_BYTES" ]; then
		echo fail
		return 1
	fi
	echo ok
	return 0
}

# Preflight: blob must fit under ubootenv. Args: blob_size. Echo ok|fail.
preflight_blob_size() {
	size=$1
	max=$((UBOOTENV_OFFSET_BYTES - UBOOT_SEEK_BYTES))
	if [ -z "$size" ] || [ "$size" -le 0 ] || [ "$size" -gt "$max" ]; then
		echo fail
		return 1
	fi
	echo ok
	return 0
}

sha256_file() {
	sha256sum "$1" | awk '{ print $1 }'
}

read_range_to_file() {
	# Read $3 bytes from $1 at offset $2 into $4 (offset must be 4096-aligned).
	disk=$1
	seek=$2
	count=$3
	dest=$4
	bs=4096
	skip=$((seek / bs))
	dd if="$disk" bs="$bs" skip="$skip" status=none 2>/dev/null \
		| head -c "$count" >"$dest"
	got=$(stat -c%s "$dest")
	[ "$got" -eq "$count" ]
}

disk_range_sha() {
	disk=$1
	seek=$2
	count=$3
	tmp=$(mktemp)
	if ! read_range_to_file "$disk" "$seek" "$count" "$tmp"; then
		rm -f "$tmp"
		return 1
	fi
	sha=$(sha256_file "$tmp")
	rm -f "$tmp"
	printf '%s\n' "$sha"
}

write_range() {
	# Write $3 to $1 starting at byte offset $2 (must be 4096-aligned).
	disk=$1
	seek=$2
	src=$3
	bs=4096
	seek_blocks=$((seek / bs))
	dd if="$src" of="$disk" bs="$bs" seek="$seek_blocks" conv=fsync,notrunc status=none
}

reload_partition_table() {
	disk=$1
	partx -u "$disk" 2>/dev/null || true
	udevadm settle --timeout=5 2>/dev/null || sleep 1
}

# Ensure GPT entry named ubootenv is 1 MiB at 12 MiB. Leaves other partitions alone.
ensure_ubootenv_gpt() {
	disk=$1
	start=$(partlabel_start_bytes ubootenv "$disk" || true)
	if [ -n "$start" ] && [ "$start" -eq "$UBOOTENV_OFFSET_BYTES" ]; then
		sz=$(lsblk -b -n -o SIZE,PARTLABEL "$disk" 2>/dev/null \
			| awk '$2 == "ubootenv" { print $1; exit }')
		if [ -n "$sz" ] && [ "$sz" -eq "$UBOOTENV_SIZE_BYTES" ]; then
			return 0
		fi
	fi

	# Delete existing ubootenv partition number(s), then create at 12 MiB.
	nums=$(sgdisk -p "$disk" 2>/dev/null | awk '
		$0 ~ /ubootenv/ && $1 ~ /^[0-9]+$/ { print $1 }
	')
	for n in $nums; do
		sgdisk -d "$n" "$disk" >/dev/null
	done

	# Absolute sector start: 12 MiB / 512 = 24576; size 1 MiB = 2048 sectors.
	# Partition number 0 = first free.
	sgdisk -n "0:24576:+2048" -c "0:ubootenv" "$disk" >/dev/null
	reload_partition_table "$disk"
	i=0
	while [ ! -e /dev/disk/by-partlabel/ubootenv ] && [ "$i" -lt 10 ]; do
		sleep 1
		i=$((i + 1))
	done
	start=$(partlabel_start_bytes ubootenv "$disk" || true)
	if [ -z "$start" ] || [ "$start" -ne "$UBOOTENV_OFFSET_BYTES" ]; then
		return 1
	fi
	return 0
}

read_vendor_boot_vars() {
	disk=$1
	cfg=$(mktemp)
	printf '%s\t0x%x\t0x%x\n' "$disk" "$VENDOR_ENV_OFFSET" "$ENV_SIZE" >"$cfg"
	printf '%s\t0x%x\t0x%x\n' "$disk" "$((VENDOR_ENV_OFFSET + ENV_SIZE))" "$ENV_SIZE" >>"$cfg"
	# Best-effort: missing env is OK (fresh or already migrated).
	BOOT_ORDER=$(fw_printenv -c "$cfg" -n BOOT_ORDER 2>/dev/null || true)
	BOOT_A_LEFT=$(fw_printenv -c "$cfg" -n BOOT_A_LEFT 2>/dev/null || true)
	BOOT_B_LEFT=$(fw_printenv -c "$cfg" -n BOOT_B_LEFT 2>/dev/null || true)
	rm -f "$cfg"
}

write_migrated_env() {
	[ -e /dev/disk/by-partlabel/ubootenv ] || return 1
	cfg=$(mktemp)
	printf '%s\n' "$NEW_FW_ENV" >"$cfg"
	# Seed defaults if vendor read failed
	order=${BOOT_ORDER:-A}
	a_left=${BOOT_A_LEFT:-1}
	b_left=${BOOT_B_LEFT:-1}
	fw_setenv -c "$cfg" BOOT_ORDER "$order" || { rm -f "$cfg"; return 1; }
	fw_setenv -c "$cfg" BOOT_A_LEFT "$a_left" || { rm -f "$cfg"; return 1; }
	fw_setenv -c "$cfg" BOOT_B_LEFT "$b_left" || { rm -f "$cfg"; return 1; }
	rm -f "$cfg"
	return 0
}

retarget_fw_env_config() {
	mkdir -p /data
	if [ -f "$FW_ENV_PATH" ]; then
		cp -a "$FW_ENV_PATH" "$FW_ENV_BAK"
	else
		rm -f "$FW_ENV_BAK"
	fi
	printf '%s\n' "$NEW_FW_ENV" >"$FW_ENV_PATH"
}

revert_fw_env_config() {
	if [ -f "$FW_ENV_BAK" ]; then
		cp -a "$FW_ENV_BAK" "$FW_ENV_PATH"
		rm -f "$FW_ENV_BAK"
	fi
}

restore_backup() {
	disk=$1
	size=$2
	if [ ! -f "$BACKUP_PATH" ] || [ ! -f "$BACKUP_SHA_PATH" ]; then
		return 1
	fi
	write_range "$disk" "$UBOOT_SEEK_BYTES" "$BACKUP_PATH" || return 1
	got=$(disk_range_sha "$disk" "$UBOOT_SEEK_BYTES" "$size")
	want=$(cat "$BACKUP_SHA_PATH")
	[ "$got" = "$want" ]
}

run_self_check() {
	fail=0
	# ROOT_A at 8 MiB proceeds
	if ! out=$(preflight_root_a "$ROOT_A_EXPECT_BYTES"); then
		echo "FAIL: 8 MiB ROOT_A should pass" >&2
		fail=1
	elif [ "$out" != ok ]; then
		echo "FAIL: 8 MiB ROOT_A expected ok got $out" >&2
		fail=1
	else
		echo "ok: ROOT_A at 8 MiB proceeds"
	fi

	# ROOT_A at 16 MiB (old mistaken layout) must abort
	bad16=$((16 * 1048576))
	if out=$(preflight_root_a "$bad16"); then
		echo "FAIL: 16 MiB ROOT_A should fail" >&2
		fail=1
	else
		echo "ok: ROOT_A at 16 MiB aborts"
	fi

	# ROOT_A at 24 MiB aborts
	bad=$((24 * 1048576))
	if out=$(preflight_root_a "$bad"); then
		echo "FAIL: 24 MiB ROOT_A should fail" >&2
		fail=1
	else
		echo "ok: ROOT_A at 24 MiB aborts"
	fi

	# Blob that fits under 6 MiB env (e.g. 4 MiB)
	if ! out=$(preflight_blob_size 4000000); then
		echo "FAIL: 4 MiB blob should pass" >&2
		fail=1
	else
		echo "ok: 4 MiB blob fits"
	fi

	# Blob too large (would hit env at 6 MiB)
	if out=$(preflight_blob_size 7000000); then
		echo "FAIL: oversized blob should fail" >&2
		fail=1
	else
		echo "ok: oversized blob aborts"
	fi

	# lsblk START is sectors → bytes (16384 sectors * 512 = 8 MiB)
	got=$(printf '16384 ROOT_A\n' | awk -v l=ROOT_A -v ss=512 '
		$2 == l { print $1 * ss; exit }
	')
	if [ "$got" != "8388608" ]; then
		echo "FAIL: sector→byte got $got want 8388608" >&2
		fail=1
	else
		echo "ok: lsblk START sectors convert to bytes"
	fi

	[ "$fail" -eq 0 ]
}

slot_post_install() {
	# Only for rootfs
	case "${RAUC_SLOT_CLASS:-}" in
		rootfs) ;;
		*) exit 0 ;;
	esac

	mount_point=${RAUC_SLOT_MOUNT_POINT:-}
	[ -n "$mount_point" ] || flash_wic "RAUC_SLOT_MOUNT_POINT unset"

	blob="$mount_point/$BLOB_PATH_REL"
	[ -f "$blob" ] || flash_wic "Missing $BLOB_PATH_REL in new rootfs"

	blob_size=$(stat -c%s "$blob")
	if ! preflight_blob_size "$blob_size" >/dev/null; then
		flash_wic "u-boot-rockchip.bin is ${blob_size} bytes; exceeds gap before ubootenv at $(bytes_mib "$UBOOTENV_OFFSET_BYTES") MiB"
	fi

	root_a_dev=$(readlink -f /dev/disk/by-partlabel/ROOT_A 2>/dev/null || true)
	[ -n "$root_a_dev" ] || flash_wic "ROOT_A partition not found"

	disk="/dev/$(lsblk -n -o PKNAME "$root_a_dev" 2>/dev/null || true)"
	[ -b "$disk" ] || flash_wic "Could not resolve disk for ROOT_A ($root_a_dev)"

	root_a_start=$(partlabel_start_bytes ROOT_A "$disk" || true)
	if ! preflight_root_a "${root_a_start:-}" >/dev/null; then
		flash_wic "ROOT_A starts at ${root_a_start:-unknown} bytes ($(bytes_mib "${root_a_start:-0}") MiB); need $ROOT_A_EXPECT_BYTES (8 MiB) so U-Boot at 2 MiB fits below it"
	fi

	blob_sha=$(sha256_file "$blob")
	on_disk=$(disk_range_sha "$disk" "$UBOOT_SEEK_BYTES" "$blob_size" || true)
	if [ -n "$on_disk" ] && [ "$on_disk" = "$blob_sha" ]; then
		echo "U-Boot already matches $blob_sha; nothing to write"
		exit 0
	fi

	# Env: migrate vendor→12 MiB only when ubootenv is not already usable there.
	# Later mainline blob bumps must leave BOOT_* alone.
	env_at_12m=0
	start_env=$(partlabel_start_bytes ubootenv "$disk" || true)
	if [ -n "$start_env" ] && [ "$start_env" -eq "$UBOOTENV_OFFSET_BYTES" ]; then
		cfg=$(mktemp)
		printf '%s\n' "$NEW_FW_ENV" >"$cfg"
		if fw_printenv -c "$cfg" -n BOOT_ORDER >/dev/null 2>&1; then
			env_at_12m=1
		fi
		rm -f "$cfg"
	fi

	if [ "$env_at_12m" -eq 0 ]; then
		read_vendor_boot_vars "$disk"
		if ! ensure_ubootenv_gpt "$disk"; then
			flash_wic "Could not place GPT ubootenv at 12 MiB"
		fi
		if ! write_migrated_env; then
			flash_wic "Could not write migrated U-Boot environment at 12 MiB"
		fi
	fi

	retarget_fw_env_config

	# Backup region that will be overwritten (includes vendor env at 6 MiB)
	mkdir -p /data
	if ! read_range_to_file "$disk" "$UBOOT_SEEK_BYTES" "$blob_size" "$BACKUP_PATH"; then
		revert_fw_env_config
		flash_wic "Failed to read bootloader backup"
	fi
	bak_sha=$(sha256_file "$BACKUP_PATH")
	printf '%s\n' "$bak_sha" >"$BACKUP_SHA_PATH"
	[ "$(cat "$BACKUP_SHA_PATH")" = "$bak_sha" ] \
		|| { revert_fw_env_config; flash_wic "Failed to record bootloader backup"; }

	wrote=0
	if write_range "$disk" "$UBOOT_SEEK_BYTES" "$blob"; then
		wrote=1
		got=$(disk_range_sha "$disk" "$UBOOT_SEEK_BYTES" "$blob_size")
		if [ "$got" = "$blob_sha" ]; then
			rm -f "$BACKUP_PATH" "$BACKUP_SHA_PATH" "$FW_ENV_BAK"
			echo "U-Boot updated to $blob_sha"
			exit 0
		fi
	fi

	# Verify/write failed — restore
	if [ "$wrote" -eq 1 ] || [ -f "$BACKUP_PATH" ]; then
		if restore_backup "$disk" "$blob_size"; then
			revert_fw_env_config
			rm -f "$BACKUP_PATH" "$BACKUP_SHA_PATH"
			flash_wic "Bootloader write verification failed; previous bootloader restored"
		fi
		revert_fw_env_config
		flash_wic_may_brick
	fi

	revert_fw_env_config
	flash_wic "Bootloader write failed before backup could be used"
}

case "${1:-}" in
	--self-check)
		run_self_check
		;;
	slot-post-install)
		slot_post_install
		;;
	*)
		# Other hook points (if any): ignore
		exit 0
		;;
esac
