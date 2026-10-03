"""Serial console driver shared by the calculinux-qemuarm test scripts."""

import os
import pty
import re
import select
import shlex
import subprocess
import time

PROMPT = "CALCULINUX-TEST# "

# Terminal escape sequences in command output: OSC (e.g. systemd >= 258's
# shell integration wraps every command in "\e]3008;...\e\\" context
# markers) and CSI (colours, cursor movement).
ESCAPES = re.compile(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b\[[0-?]*[ -/]*[@-~]")


def boot_command(args):
    """Command that boots the machine on this terminal (see add_boot_args)."""
    if args.cmd:
        return shlex.split(args.cmd)
    return ["runqemu", args.machine, args.image, "wic", "nographic", "slirp", "snapshot"]


def add_boot_args(ap):
    ap.add_argument("--machine", default="calculinux-qemuarm")
    ap.add_argument("--image", default="calculinux-image")
    ap.add_argument("--boot-timeout", type=int, default=600)
    ap.add_argument("--cmd", help="command that boots the machine on this terminal "
                    "(default: runqemu ... nographic slirp snapshot), e.g. "
                    "'./calculinux-emulator-x86_64.AppImage --nographic'")


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

    def login(self, timeout):
        """Log in as root/root and switch to a prompt run() can match."""
        self.expect(r"login: ", timeout)
        self.send("root")
        self.expect(r"Password: ", 30)
        self.send("root")
        self.expect(r"[#$] ", 60)
        self.send("export PS1='%s'; stty -echo" % PROMPT)
        self.expect(re.escape(PROMPT), 30)

    def run(self, command, timeout=60):
        """Run a shell command; return (exit status, output)."""
        self.buf = ""
        self.send("%s; echo \"@@RC=$?@@\"" % command)
        m = self.expect(r"([\s\S]*?)@@RC=(\d+)@@", timeout)
        self.expect(re.escape(PROMPT), 30)
        return int(m.group(2)), ESCAPES.sub("", m.group(1))

    def close(self):
        if self.proc.poll() is None:
            os.killpg(self.proc.pid, 9)
            self.proc.wait()


class Checks:
    """Collects PASS/FAIL results and prints them as they happen."""

    def __init__(self):
        self.failures = []

    @staticmethod
    def step(name):
        print("==> " + name, flush=True)

    def check(self, name, ok, detail=""):
        print("    [%s] %s%s" % ("PASS" if ok else "FAIL", name,
                                (": " + detail.strip()) if detail and not ok else ""),
              flush=True)
        if not ok:
            self.failures.append(name)
        return ok

    def report(self, log_path):
        print("serial log: " + os.path.abspath(log_path))
        if self.failures:
            print("FAILED: " + ", ".join(self.failures))
            return 1
        print("ALL CHECKS PASSED")
        return 0
