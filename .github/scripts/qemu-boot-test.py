#!/usr/bin/env python3
"""End-to-end boot test for calculinux-qemuarm over the serial console.

Run inside the kas build environment (runqemu must be on PATH):

    kas-container shell kas-calculinux-qemuarm.yaml -c \
        "python3 ../../repo/.github/scripts/qemu-boot-test.py"

Checks, in order:
  1. U-Boot runs boot.scr and boots the slot's /boot FIT (first boot).
  2. Linux reaches a login prompt; root can log in.
  3. Booted from RAUC slot A, U-Boot env is readable from Linux,
     overlayfs is mounted over /etc, systemd finished booting.
  4. merge-dt-overlays-boot writes /data/fit/zboot_merged_a.img, and after
     a reboot U-Boot boots that FIT from OVERLAY_DATA.
  5. rauc mark-active switches BOOT_ORDER to B and the next boot runs
     slot B (via U-Boot's by-PARTLABEL bootcmd).
"""

import argparse
import sys

from qemu_console import Checks, Console, add_boot_args, boot_command


def main():
    ap = argparse.ArgumentParser()
    add_boot_args(ap)
    ap.add_argument("--log", default="qemu-boot-test.log")
    args = ap.parse_args()

    checks = Checks()
    step, check = checks.step, checks.check

    with open(args.log, "w") as log:
        con = Console(boot_command(args), log)
        run = con.run

        def login():
            con.login(args.boot_timeout)

        try:
            step("first boot: U-Boot boot script -> /boot FIT")
            con.expect(r"Booting FIT boot", 300)
            check("U-Boot booted the /boot FIT", True)

            step("login")
            login()
            check("root login", True)

            step("system state")
            rc, out = run("cat /proc/cmdline")
            check("booted RAUC slot A", "rauc.slot=A" in out, out)
            rc, out = run("fw_printenv BOOT_ORDER")
            check("U-Boot env readable (fw_printenv)", rc == 0 and "BOOT_ORDER=A" in out, out)
            rc, out = run("rauc status")
            check("rauc status", rc == 0, out)
            rc, out = run("findmnt -n -o FSTYPE /etc")
            check("overlayfs on /etc", "overlay" in out, out)
            rc, out = run("systemctl is-system-running --wait", timeout=300)
            check("systemd finished booting", out.strip().splitlines()[-1:] in (["running"], ["degraded"]), out)
            if "degraded" in out:
                _, failed = run("systemctl --failed --no-legend")
                print("    (degraded) failed units:\n" + failed, flush=True)

            step("device-tree overlay FIT on /data")
            rc, out = run("/usr/lib/systemd/merge-dt-overlays-boot.sh", timeout=120)
            check("merge-dt-overlays-boot", rc == 0, out)
            rc, out = run("ls /data/fit/zboot_merged_a.img")
            check("merged FIT written for slot A", rc == 0, out)
            run("sync")
            con.send("reboot")

            step("second boot: U-Boot -> /data FIT")
            con.expect(r"Booting FIT data", 300)
            check("U-Boot booted the merged FIT from OVERLAY_DATA", True)
            login()
            rc, out = run("cat /proc/cmdline")
            check("still on RAUC slot A", "rauc.slot=A" in out, out)

            step("A/B switch: mark slot B active, reboot")
            rc, out = run("rauc status mark-active other", timeout=120)
            check("rauc mark-active other", rc == 0, out)
            rc, out = run("fw_printenv BOOT_ORDER")
            check("BOOT_ORDER now prefers B", "BOOT_ORDER=B A" in out, out)
            run("sync")
            con.send("reboot")
            con.expect(r"Found valid slot B", 300)
            check("U-Boot picked slot B", True)
            login()
            rc, out = run("cat /proc/cmdline")
            check("booted RAUC slot B", "rauc.slot=B" in out, out)
            rc, out = run("rauc status")
            check("rauc reports slot B booted", rc == 0 and "rootfs.1 (B)" in out, out)
            con.send("poweroff")
        except TimeoutError as e:
            check("boot sequence", False, str(e))
        finally:
            con.close()

    return checks.report(args.log)


if __name__ == "__main__":
    sys.exit(main())
