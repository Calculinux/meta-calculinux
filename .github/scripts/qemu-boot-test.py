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
import os
import pty
import re
import select
import shlex
import subprocess
import sys
import time

PROMPT = "CALCULINUX-TEST# "


class Console:
    def __init__(self, cmd, log):
        self.master, slave = pty.openpty()
        self.proc = subprocess.Popen(
            cmd, stdin=slave, stdout=slave, stderr=slave, start_new_session=True
        )
        os.close(slave)
        self.log = log
        self.buf = ""

    def expect(self, pattern, timeout):
        regex = re.compile(pattern)
        deadline = time.monotonic() + timeout
        while True:
            m = regex.search(self.buf)
            if m:
                self.buf = self.buf[m.end():]
                return m
            remaining = deadline - time.monotonic()
            if remaining <= 0 or self.proc.poll() is not None:
                raise TimeoutError("timed out waiting for %r" % pattern)
            ready, _, _ = select.select([self.master], [], [], min(remaining, 1))
            if ready:
                try:
                    data = os.read(self.master, 4096)
                except OSError:
                    data = b""
                text = data.decode("utf-8", "replace")
                self.log.write(text)
                self.log.flush()
                self.buf += text

    def send(self, line):
        os.write(self.master, (line + "\n").encode())

    def close(self):
        if self.proc.poll() is None:
            os.killpg(self.proc.pid, 9)
            self.proc.wait()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--machine", default="calculinux-qemuarm")
    ap.add_argument("--image", default="calculinux-image")
    ap.add_argument("--log", default="qemu-boot-test.log")
    ap.add_argument("--boot-timeout", type=int, default=600)
    ap.add_argument("--cmd", help="command that boots the machine on this terminal "
                    "(default: runqemu ... nographic slirp snapshot), e.g. "
                    "'./calculinux-emulator-x86_64.AppImage --nographic'")
    args = ap.parse_args()

    if args.cmd:
        cmd = shlex.split(args.cmd)
    else:
        cmd = ["runqemu", args.machine, args.image, "wic", "nographic", "slirp", "snapshot"]
    failures = []

    with open(args.log, "w") as log:
        con = Console(cmd, log)

        def step(name):
            print("==> " + name, flush=True)

        def check(name, ok, detail=""):
            print("    [%s] %s%s" % ("PASS" if ok else "FAIL", name,
                                    (": " + detail.strip()) if detail and not ok else ""),
                  flush=True)
            if not ok:
                failures.append(name)

        def login():
            con.expect(r"login: ", args.boot_timeout)
            con.send("root")
            con.expect(r"Password: ", 30)
            con.send("root")
            con.expect(r"[#$] ", 60)
            con.send("export PS1='%s'; stty -echo" % PROMPT)
            con.expect(re.escape(PROMPT), 30)

        def run(command, timeout=60):
            con.buf = ""
            con.send("%s; echo \"@@RC=$?@@\"" % command)
            m = con.expect(r"([\s\S]*?)@@RC=(\d+)@@", timeout)
            con.expect(re.escape(PROMPT), 30)
            return int(m.group(2)), m.group(1)

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

    print("serial log: " + os.path.abspath(args.log))
    if failures:
        print("FAILED: " + ", ".join(failures))
        return 1
    print("ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
