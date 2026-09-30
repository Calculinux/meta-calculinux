#!/usr/bin/env python3
"""overlayfs upper-layer ioctl test for calculinux-qemuarm.

Boots the machine like qemu-boot-test.py and exercises OVL_IOC_UPPER_STATE,
OVL_IOC_IS_RESTORABLE and OVL_IOC_RESTORE_LOWER through ovl-restore, on a
scratch overlay in /tmp and on the real /etc overlay (upper on /data):

  1. state of a lower-only name, a new upper file, a whiteout left by rm,
     an opaque directory and a name below it
  2. restore makes the lower file visible to both stat and readdir, and
     a second restore fails with EEXIST
  3. a whiteout with nothing below it reports ENODATA
  4. an xattr whiteout (zero-size file with trusted.overlay.whiteout) is
     treated as a whiteout
  5. malformed paths and paths on other filesystems are rejected
  6. the kernel logs no warnings

Run inside the kas build environment (runqemu must be on PATH):

    kas-container shell kas-calculinux-qemuarm.yaml -c \\
        "python3 /repo/.github/scripts/qemu-overlay-test.py"
"""

import argparse
import sys

from qemu_console import Checks, Console, add_boot_args, boot_command

SCRATCH = "/tmp/ovt"
M = SCRATCH + "/m"


def main():
    ap = argparse.ArgumentParser()
    add_boot_args(ap)
    ap.add_argument("--log", default="qemu-overlay-test.log")
    args = ap.parse_args()

    checks = Checks()
    step, check = checks.step, checks.check

    with open(args.log, "w") as log:
        con = Console(boot_command(args), log)
        run = con.run

        def state(mnt, path):
            """ovl-restore --state: (rc, [state, flags, mode]) or (rc, output)."""
            rc, out = run("ovl-restore --state %s %s 2>&1" % (mnt, path))
            fields = out.strip().splitlines()[-1].split("\t") if out.strip() else []
            if rc == 0 and len(fields) == 4 and fields[0] == path:
                return rc, fields[1:]
            return rc, out

        def expect_state(name, mnt, path, want_state, want_flags="-", want_mode=None):
            rc, got = state(mnt, path)
            ok = rc == 0 and got[0] == want_state and got[1] == want_flags
            if ok and want_mode is not None:
                ok = got[2] == want_mode
            check(name, ok, "rc=%d %r" % (rc, got))

        def expect_error(name, command, errno_text):
            rc, out = run(command + " 2>&1")
            check(name, rc != 0 and errno_text in out, "rc=%d %s" % (rc, out))

        try:
            step("boot and log in")
            con.login(args.boot_timeout)
            check("root login", True)
            rc, out = run("ovl-restore 2>&1; true")
            check("ovl-restore supports --state", "--state" in out, out)

            step("scratch overlay")
            for cmd in (
                "rm -rf %s && mkdir -p %s/lower/d %s/lower/o %s/upper %s/work %s"
                % (SCRATCH, SCRATCH, SCRATCH, SCRATCH, SCRATCH, M),
                "echo lower > %s/lower/d/f && echo lower > %s/lower/d/xw "
                "&& echo lower > %s/lower/o/x" % (SCRATCH, SCRATCH, SCRATCH),
                "mount -t overlay overlay -o lowerdir=%s/lower,upperdir=%s/upper,"
                "workdir=%s/work %s" % (SCRATCH, SCRATCH, SCRATCH, M),
            ):
                rc, out = run(cmd)
                check("setup: " + cmd.split()[0], rc == 0, out)

            step("state")
            expect_state("lower-only file is none", M, M + "/d/f", "none")
            run("touch %s/d/new" % M)
            expect_state("new file is upper", M, M + "/d/new", "upper", "-", "100644")
            run("rm %s/d/f" % M)
            expect_state("removed lower file is a whiteout", M, M + "/d/f", "whiteout")
            rc, out = run("ls %s/d" % M)
            check("whiteout hides f from readdir", rc == 0 and "f" not in out.split(), out)
            run("rm -rf %s/o && mkdir %s/o" % (M, M))
            expect_state("recreated dir is opaque", M, M + "/o", "upper", "opaque", "40755")
            expect_state("name below opaque dir has no lower dir", M, M + "/o/x",
                         "none", "no-lower-dir")

            step("restore")
            rc, out = run("ovl-restore --test %s %s/d/f" % (M, M))
            check("whiteout is restorable", rc == 0 and "Restorable" in out, out)
            rc, out = run("ovl-restore %s %s/d/f" % (M, M))
            check("restore succeeds", rc == 0, out)
            rc, out = run("cat %s/d/f" % M)
            check("lower file readable after restore", rc == 0 and "lower" in out, out)
            rc, out = run("ls %s/d" % M)
            check("lower file listed after restore (readdir cache)",
                  rc == 0 and "f" in out.split(), out)
            expect_state("restored name has no upper entry", M, M + "/d/f", "none")
            expect_error("second restore fails with EEXIST",
                         "ovl-restore %s %s/d/f" % (M, M), "File exists")
            expect_error("restoring an upper file fails with EEXIST",
                         "ovl-restore %s %s/d/new" % (M, M), "File exists")

            step("whiteout with nothing below")
            # Crafted directly in the upper dir; drop caches so overlay sees it.
            run("mknod %s/upper/o/z c 0 0 && echo 2 > /proc/sys/vm/drop_caches" % SCRATCH)
            expect_state("crafted whiteout below opaque dir", M, M + "/o/z",
                         "whiteout", "no-lower-dir")
            expect_error("--test reports ENODATA",
                         "ovl-restore --test %s %s/o/z" % (M, M), "No data available")
            expect_error("restore reports ENODATA",
                         "ovl-restore %s %s/o/z" % (M, M), "No data available")
            expect_state("whiteout removed anyway", M, M + "/o/z", "none", "no-lower-dir")

            step("xattr whiteout")
            rc, out = run(
                "touch %s/upper/d/xw && python3 -c \"import os; "
                "os.setxattr('%s/upper/d/xw', 'trusted.overlay.whiteout', b'')\" "
                "&& echo 2 > /proc/sys/vm/drop_caches" % (SCRATCH, SCRATCH))
            check("setup xattr whiteout", rc == 0, out)
            rc, out = run("cat %s/d/xw" % M)
            check("xattr whiteout hides the lower file", rc != 0, out)
            expect_state("xattr whiteout is a whiteout", M, M + "/d/xw", "whiteout")
            rc, out = run("ovl-restore %s %s/d/xw && cat %s/d/xw" % (M, M, M))
            check("xattr whiteout restored", rc == 0 and "lower" in out, out)

            step("argument checks")
            expect_error("relative path rejected",
                         "ovl-restore --state %s d/f" % M, "Invalid argument")
            expect_error("trailing slash rejected",
                         "ovl-restore --state %s %s/d/" % (M, M), "Invalid argument")
            expect_error("path on another filesystem rejected",
                         "ovl-restore --state %s /proc/version" % M,
                         "ross-device link")  # EXDEV (musl and glibc wording)
            run("umount %s" % M)

            step("real /etc overlay (upper on /data)")
            expect_state("image file is none", "/etc", "/etc/issue", "none")
            run("echo x > /etc/ovl-test-new")
            expect_state("new /etc file is upper", "/etc", "/etc/ovl-test-new", "upper")
            run("cp /etc/issue /tmp/issue.orig && rm /etc/issue")
            expect_state("removed image file is a whiteout", "/etc", "/etc/issue", "whiteout")
            rc, out = run("ovl-restore /etc /etc/issue && cmp /etc/issue /tmp/issue.orig")
            check("image file restored with original content", rc == 0, out)
            rc, out = run("ls /etc")
            check("restored image file listed", "issue" in out.split(), out)
            run("rm -f /etc/ovl-test-new")

            step("kernel log")
            rc, out = run("dmesg | grep -E 'WARNING|BUG|Oops|lockdep' || true")
            check("no kernel warnings", not out.strip(), out)

            con.send("poweroff")
        except TimeoutError as e:
            check("test sequence", False, str(e))
        finally:
            con.close()

    return checks.report(args.log)


if __name__ == "__main__":
    sys.exit(main())
