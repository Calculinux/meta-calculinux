---
name: calculinux-yocto
description: >-
  How to work properly in the Calculinux Yocto tree: KAS-managed bitbake builds, recipes,
  bbappends, meta-layers, sstate, build-failure investigation, and the walnascar (YP 5.2)
  -> wrynose (YP 6.0) stack split. Use this skill whenever you are operating in
  calculinux-build/meta-calculinux or dealing with bitbake, kas, poky, or OpenEmbedded concepts
  for this project - adding or updating a recipe or bbappend, building something, debugging a
  build or fetch failure, bumping an upstream layer pin (meta-retro, meta-lts-mixins,
  meta-openembedded, meta-arm, meta-rockchip, meta-rauc, meta-rtlwifi, meta-wayland),
  configuring the machine/kernel, planning or performing the YP 6.0 migration, or
  understanding why the build behaves oddly. Trigger it even when the user only says things
  like "poky", "meta-*", "bitbake error", "sstate", "KAS", "crates.io 403", or uses a codename
  like walnascar or wrynose without naming Yocto explicitly.
---

# Calculinux Yocto, KAS & BitBake

This skill teaches you to work *correctly* in the Calculinux Yocto tree (`meta-calculinux/`).
Most costly mistakes in this project are environmental (wrong build path, wrong stack,
improvised setup) rather than conceptual, so this document spends its first section on the
one rule that prevents all of them.

## RULE ZERO - never build your own build environment

There is exactly one sanctioned build path in this project: KAS inside the project's
container against the pinned checkouts, driven by exactly one of two entry points:

- **`make …` targets, run from `meta-calculinux/`** (per the README). The Makefile `cd`s to
  the build root (`BUILD_ROOT`, default `..`) before invoking KAS, so artifacts still land in
  the parent's `build/` - running make from the meta-layer is safe *because of* that cd.
- **Raw `./meta-calculinux/kas-container …`, run from the parent `calculinux-build/`**
  (the build root). KAS takes the current directory as its work dir, so the build tree appears
  exactly where you stood.

`meta-calculinux/`'s Makefile is the ONLY authoritative one. Never trust a Makefile found
loose in the build root itself - checkouts land there, and a stray copy was recently deleted.
The container image, the pinned repo checkouts, and the `patches/` are *the tested unit*; CI
runs the same unit. Everything else is an improvisation, and improvisations here do not
converge.

Recognize these drift behaviors - if you catch yourself about to do any of them, **stop**:

- cloning `poky` / `openembedded-core` / `bitbake` by hand, or using any checkout that KAS
  did not produce (`src-kas/` on main, `kas-work-wrynose*/` on wrynose);
- sourcing `oe-init-build-env` / `setup.sh` against a hand-made checkout, or running `bitbake`
  directly on the host;
- installing "build prerequisites" on the host (apt/dnf/python packages, g++, flex, …) to
  make an ad-hoc setup work;
- creating build directories, `conf/local.conf`, or `bblayers.conf` outside the KAS layout;
- patching the KAS container image, the `kas-container` script, or the kas yaml "just to get
  something building";
- running `kas-container` or `bitbake` DIRECTLY from inside `meta-calculinux/` - KAS creates
  `src-kas/` and `build/` in your CWD and scatters artifacts into the repo tree. The Makefile
  is the exemption: it cds to the build root first, which is exactly why `make` runs from
  `meta-calculinux/` while raw KAS runs from the parent.

Why this is a rule and not a preference: host-environment yak shaving is a bottomless swamp
here (modern host Python versions routinely break bitbake's server multiprocessing, distro
toolchain drift breaks natives, disk layouts trip diskmon), and none of that information
returns to the project - you burn hours producing no artifact and mutating state you had no
business touching. If the sanctioned flow itself is broken (container won't start, disk full,
network blocked), the correct move is to surface the exact error and stop - asking for help
costs minutes; rebuilding the environment around the problem costs days.

Scope discipline follows from the same principle. Authorized mutation surface per task type:

| Task | You may touch | You must not touch |
|---|---|---|
| Author a recipe | its recipe/bbappend/`files/` in the owning layer; the packagegroup and `calculinux-image.bb` `IMAGE_INSTALL` if delivery requires it | other recipes, kas yamls, `patches/`, container/host settings |
| Bump an upstream layer | that repo's pin in the kas file, `patches/` (regenerated), BBMASK entries | other layers' pins, recipes unrelated to the bump |
| Debug a failure | nothing (inspect logs; rerun tasks) | recipes/conf to "try something" unless you can name the defect it fixes |

If a solution suddenly requires reaching outside the row for your task, that is the smell of
a derailed approach - reconsider before typing.

## 1. Know your stack first

| | **walnascar** (current, `main`) | **wrynose** (in progress) |
|---|---|---|
| YP line | 5.2.x (pinned at the `walnascar-5.2.3` / `yocto-5.2.3` tag) | 6.0.x (pinned at release tags, `yocto-6.0.2`+) |
| Poky layout | **Single `poky` repo**, layers `meta` + `meta-poky`, pinned by commit | **Split Poky: three repos** — `bitbake` + `openembedded-core` + `meta-yocto`, pinned by release tags |
| Lives in | `main` branch | `wrynose` branch, plus worktree `.claude/worktrees/wrynose-merge-main` |
| Source checkouts | `src-kas/` in the build root | `kas-work-wrynose*` in the build root |
| Compat patches | `*-walnascar-compat.patch` in `patches/` | separate `*-wrynose-compat.patch` twins |

**Release policy** (frames everything dual-stack below): `main` is always the *active*
distribution; the next major release develops on a branch until it's ready to merge, and there
is **no intent to maintain two lines side by side**. Walnascar stays the release target until
the wrynose work completes, then releases shift to wrynose and walnascar stops receiving
edits. Consequently the dual-stack framing in this skill (§1 table, §7) is *transition
instrumentation* - after the merge it collapses into a single-stack description of what is
then just "the tree".

Why codenames lead: the project tracks releases by `DISTRO_CODENAME` (walnascar, wrynose), not
by YP number. The codename drives the opkg feed path (`opkg.calculinux.org/ipk/<codename>/…`)
and RAUC naming, so "which codename" is a more actionable question than "which YP number".

Hard constraints that come from this split:

- **sstate never survives across YP releases.** Signatures embed OE-core identity; a walnascar
  sstate cache contributes nothing to a wrynose build (and vice versa). CI cache keys are
  keyed per YP release for exactly this reason. Don't share caches, build dirs, or kas files
  across stacks.
- The unified `poky` repo was frozen before 6.0 - no `yocto-6*` tags exist there. A
  main-shaped manifest literally cannot express "poky at 6.0".
- In wrynose, **`bitbake` must be checked out as a *sibling* of `openembedded-core`** -
  `oe-init-build-env` locates bitbake via `$OEROOT/bitbake`, falling back to
  `$OEROOT/../bitbake`, and hard-errors otherwise. Flattening the three repos into one dir
  breaks sourcing.
- Layer ownership shifts on wrynose: `openembedded-core` serves `meta`, `meta-yocto` serves
  `meta-poky`; the compress-doc patch attaches to `openembedded-core`.
- Our own layers' `conf/layer.conf` grow a `wrynose` entry in `LAYERSERIES_COMPAT`
  (e.g. `"scarthgap walnascar wrynose"` on the migration branch).
- **Wrynose truth source:** for claims about the wrynose stack, trust the
  `wrynose-merge-main` worktree or `origin/wrynose` - a plain local `wrynose` branch ref may
  be a stale mid-merge snapshot (one eval run once "proved" the QEMU BSP layer had been
  deleted, resting on exactly that).

**Anti-hallucination guardrail:** pins, tags, versions, and branch heads all move; doc-stated
constants drift too (architecture/tune strings like `DEFAULTTUNE` are classic victims).
Before you assert any of them, read the live source of truth for the branch in question:
`kas-*.yaml`, the relevant `conf/layer.conf` / machine conf, and for arch/tune questions the
`deploy/ipk/<tune>/` directories. This skill describes the *shape* of the setup; the values
live in files, and files outrank prose.

## 2. Repository map

`meta-calculinux/` relative to the build root:

- `kas-base.yaml` — shared KAS fragment: pinned upstream repos (poky, meta-openembedded,
  meta-lts-mixins, meta-retro, meta-wayland) + `local_conf_header` blocks.
- `kas-luckfox-lyra-bundle.yaml` — the **device** config: machine `luckfox-lyra`; targets
  `calculinux-bundle` (RAUC A/B OTA image) + the apps packagegroup; adds meta-arm,
  meta-rockchip (vendor fork), meta-rtlwifi, meta-rauc.
- `kas-calculinux-qemuarm.yaml` — the **emulator** config: machine `calculinux-qemuarm` (Arm
  `virt`, 3× Cortex-A7 / 128 MiB — deliberately mirrored so packages and the opkg feed are
  shared between emulator and real hardware); targets `calculinux-image`; boots through the
  same U-Boot → RAUC A/B → DT-overlay FIT path as the device.
- `kas-container` — stock Siemens/KAS wrapper: runs KAS in `ghcr.io/siemens/kas/kas:*`;
  mounts the repo **read-only for `build`, read-write for `shell`** (the `--repo-ro` flag
  forces ro where needed); `--ssh-dir <dir>` / `--ssh-agent` forward git credentials. On
  aarch64 hosts the standard KAS image doesn't work — rebuild it from `Dockerfile.aarch64`
  first (README, "AARCH64 Host Support").
- Layers: `meta-calculinux-distro/` (distro conf, image + bundle recipes, RAUC/boot-chain
  recipes, bbappends), `meta-calculinux-apps/` (application recipes +
  `packagegroup-meta-calculinux-apps`), `meta-picocalc-bsp-rockchip/` (machine `luckfox-lyra`,
  rockchip kernel/u-boot/wic), `meta-calculinux-bsp-qemu/` (machine `calculinux-qemuarm`,
  `calculinux-emulator` AppImage), `meta-meshtastic/` (LoRa stack). Dependency direction:
  apps depends on distro + meshtastic + the scarthgap rust mixin; BSPs depend on distro.
  Put new recipes in the layer that owns the domain.
- `patches/` — upstream-layer compatibility/fix patches, applied by KAS at checkout time.
- `docs/` — hardware/design docs; `QEMU.md` doubles as the "adding another board" checklist.
- `.github/` — `copilot-instructions.md` is the **canonical house-style document** (when it
  and this skill disagree, it wins); `workflows-README.md` documents the CI lanes; workflows
  run time-boxed build passes, per-release sstate caches, PR feed publishing, a manual
  `cleanall.yml`, and a daily `upstream-watches.yml` that auto-refreshes rotating download
  URLs.

## 3. Golden operating rules

1. **Never pipe a long build into `head`/`tail`.** Closing stdout early SIGPIPEs the build
   mid-run and leaves the server/state inconsistent. Redirect to a file if you want bounded
   output.
2. **devtool is for local experimentation, never for delivering changes.** Convert experiments
   into proper recipes/bbappends under the layer (sources in `files/`) before proposing
   anything. Never commit devtool's workspace mutation of build conf.
3. **Override distro identity through the layer's knobs, not the YP variables.** CI sets
   `CALCULINUX_VERSION` / `CALCULINUX_CODENAME` (via `kas-ci-override.yaml`'s
   `local_conf_header`), never `DISTRO_VERSION` / `DISTRO_CODENAME` directly — local.conf is
   parsed *before* the distro conf, and poky sets `DISTRO_VERSION` with a hard `=`, so a
   local.conf value is silently discarded. Local tweaks go on the `CALCULINUX_*` variables.
4. **Patch hygiene: never hand-author or hand-edit patch files.** Whitespace mistakes
   silently invalidate patches. Workflow: check out the upstream repo at the pinned rev,
   make the change, regenerate with `git diff`/`git format-patch`, drop the result in
   `patches/` (layer-level) or the recipe's `files/`, mirroring the mail-header style of the
   existing patches (project identity `Calculinux <noreply@calculinux.org>`, `Signed-off-by`
   where the neighbours carry one). When an upstream bump
   changes what a compat patch applies against, *regenerate* it — don't edit it in place, and
   note the build runs `PATCHRESOLVE = "noop"`, so a stale patch fails the checkout hard.

## 4. Building and investigating failures in the container

### Everyday builds

From `meta-calculinux/` (the Makefile relocates itself to the build root first):

```bash
make image                      # device image  (kas-container build kas-luckfox-lyra-bundle.yaml)
make bundle                     # RAUC OTA bundle (bitbake calculinux-bundle); alias: make build
make shell                      # interactive bitbake shell - the default place to be while debugging
make recipe RECIPE=x48ng        # build one recipe (likewise clean-recipe, devshell RECIPE=…)
make qemu-image && make qemu    # emulate end-to-end (Ctrl-a x quits)
make list-recipes SEARCH=sdl    # find recipes;   make list-images
make sdk                        # populate_sdk for x86_64 + aarch64
make kernel-config FRAGMENT=rtc # menuconfig -> diffconfig fragment workflow
make status                     # where artifacts landed
make clean-all / clean-sstate   # nuclear options (artifacts / sstate cache)
```

Raw KAS equivalents, run from the parent `calculinux-build/` (the Makefile is sugar over
exactly these, minus its relocation cd):

```bash
./meta-calculinux/kas-container build  meta-calculinux/kas-luckfox-lyra-bundle.yaml
./meta-calculinux/kas-container shell  meta-calculinux/kas-luckfox-lyra-bundle.yaml
./meta-calculinux/kas-container shell  meta-calculinux/kas-….yaml -c "bitbake calc…"
./meta-calculinux/kas-container --ssh-dir ~/.ssh build …    # private repos / ssh git
```

`BUILD_ROOT=/path make …` relocates the build area. `kas build` mounts the repo
**read-only** — a mid-session "let me just edit the recipe" requires a `kas shell` session,
not a `kas build`. Artifacts: `build/tmp/deploy/images/<machine>/` (`*.wic(.gz)`, `*.raucb`,
SDK tarballs).

### The log and state map

Everything you need on failure lives under `build/` on the host and survives between
container sessions - you can grep from the host without re-entering the container.

- **Cooker log** - `build/tmp/log/cooker/<machine>/<timestamp>.log`: the chronicle of the
  run; the newest file is the run you just did. The decisive lines:
  `ERROR: Task (…:do_X) failed` and `ERROR: Logfile of failure stored in: …`.
- **Per-task logs** - `build/tmp/work/<tune-os>/<pn>/<version-r<rev>/temp/`:
  `log.do_<task>` (the actual output) and `run.do_<task>.<pid>` (the literal executed script
  - invaluable for "what exactly did it run?").
- **Server log** - `build/bitbake-cookerdaemon.log`: Python-level tracebacks (broken hosts,
  forkserver/multiprocessing issues) show up here, not in the cooker log. A wedged start
  (hang, `connect() failed`) usually means stale `bitbake.sock`/`bitbake.lock` + orphaned
  `bitbake-server`: kill the daemon, remove the socket and lockfile, retry.
- **Cache & downloads** - `build/sstate-cache/` (never mass-delete; CI treats it as
  precious); downloads live in the build dir's downloads path (respecting
  `DL_DIR`/`KAS_DL_DIR`; CI feeds off the `opkg.calculinux.org/.sources` mirror).
- **Stamp reality** - `INHERIT += "rm_work"` deletes *successful* workdirs, so any workdir
  still sitting in `tmp/work` belongs to something that failed or is pending. Survivors are
  failure sites by construction.

### Failure triage ladder

1. **Locate the verdict.** Newest cooker log → last `ERROR:` block → copy the
   "Logfile of failure stored in" path. One failed task names the cause; the hundreds of
   "NOTE: …" lines above it are scenery.
2. **Read the failure log.** `temp/log.do_<task>` for the error text,
   `temp/run.do_<task>` for the executed script. Act on the *last* real error in the task
   log, not the first warning.
3. **Classify, then act per class:**
   - *fetch* (403/checksum/timed out) → network or rotating upstream; `bitbake <pn> -c fetch`
     in a shell isolates it from the build; the standing patterns below cover the 403 and
     checksum cases.
   - *license* → `bitbake <pn> -c fetchlicense`; usually a missing/new upstream LICENSE file.
   - *configure* (autotools/cmake/ninja/meson) → re-run the offending command from
     `run.do_configure` by hand inside `bitbake <pn> -c devshell` with verbose build output.
   - *compile/link* → same technique for `do_compile`; musl or missing-header errors dominate
     (see distro constraints in §5).
   - *image/postinst* → image and rootfs logs under the image recipe's workdir; FIT/deploy
     staleness has a known surgical fix (step 6).
4. **Reproduce narrowly.** `bitbake <pn> -c <task> -f` forces exactly one task;
   `DEBUG_BUILD = "1"` in the environment buys verbose compile output. One task at a time -
   a full rebuild "to see if it still fails" burns the whole budget.
5. **Interrogate effective state.** `bitbake -e <VAR>` (effective value + where set),
   `bitbake -e > env.dump`, `bitbake-layers show-overlay <pn>` (which recipe/bbappend wins),
   `bitbake-layers show-recipes` (existence/spelling), `bitbake -g` (dependency graph proving
   *why* a task is scheduled).
6. **Clear state surgically.** `bitbake <pn> -c cleanstamp` (task stamps) or `-c cleansstate`
   (workdir + stamps) for the affected recipes; known case:
   `bitbake -c cleansstate virtual/kernel default-merged-fit` for stale merged-FIT
   deployments (documented in `docs/QEMU.md`). Never purge the sstate cache to chase one
   task.

### Standing failure patterns

The recurring ones, pre-diagnosed - match before theorizing:

- `HTTP 403` from crates.io / crate fetches falling back to the Yocto mirror and failing:
  the whole-value `FETCHCMD_wget` user-agent override regressed (crates.io 403s wget's
  default UA). Fix it as a *whole* value - the reason the append trap exists is documented
  inline in `kas-base.yaml`.
- `ChecksumMismatchError` on an archive whose upstream rotates URLs in place (has happened
  to the `aic8800` wifi firmware twice): refresh URL/checksum; note
  `upstream-watches.yml` auto-PRs the watched feeds - coordinate, don't fight it.
- Cargo: `no matching package named … found` → the meta-lts-mixins CARGO_HOME/UNPACKDIR
  compat patch failed to apply after a bump.
- Crash in `compress_doc` on alternatives with missing metadata → the poky patch addresses
  this; recurrence means a bump dropped the patch entry from the kas file.
- Wedged server startup / `connect() failed` → see the Server log bullet above.
- Disk-space HALTs → `BB_DISKMON_DIRS` thresholds are deliberately low (STOPTASKS 1 GB,
  HALT 100 MB); clear `tmp/` (rm_work already trims successes) or relocate the cache -
  don't raise the thresholds.
- Gratuitously different signatures between supposedly identical trees → check the
  `OEEquivHash` plumbing (`BB_SIGNATURE_HANDLER`, `SSTATE_HASHEQUIV_METHOD`) before
  suspecting content.

Quote discipline: every quotation in your answers should come from a file you actually read
this session. Paraphrase from memory beats a confident-but-stale quote - a miscited constant
(costs the reader a debugging detour) is worse than no quote at all.

## 5. Recipes and shipping apps

### How an app actually reaches the device (three distinct paths)

1. **Baked into the image (and therefore the RAUC bundle):** its PN is listed in
   `IMAGE_INSTALL` in `meta-calculinux-distro/recipes-core/image/calculinux-image.bb`. The
   list is explicit and hand-curated - that is how `sdl2-test`, `uwific`, etc. ship.
2. **Published to the opkg feed:** being *built* in an enabled layer publishes the ipk to
   `opkg.calculinux.org/ipk/<codename>/<channel>`; membership in
   `packagegroup-meta-calculinux-apps.bb` bundles the app set into an opkg meta-package the
   device can install from the overlay. The packagegroup is a KAS *target* (built and
   published on every run) - it does **not** auto-install into the image, and
   `CORE_IMAGE_EXTRA_INSTALL` in the device kas header carries only the wifi/firmware/driver
   lists, not the apps.
3. **Board extras:** `MACHINE_EXTRA_RDEPENDS` in the machine conf pulls in board-specific
   packages.

So "ship my app in the bundle" = recipe (apps layer) + PN in the packagegroup (feed
publication) **+** PN in `IMAGE_INSTALL` (baking). The latter two are separate decisions that
must both be made consciously; forgetting the `IMAGE_INSTALL` entry produces an app that
silently reaches only the feed. The `uwific` introduction commit (552cc71) is a worked
example of the three-file change.

Default when in doubt: **feed first, bake only when required.** Baking adds the app's
footprint to every rootfs and every RAUC payload on a 128 MiB machine - the image should stay
a minimal universal set. Bake only what must exist at first boot or is part of the intended
out-of-box experience; everything else ships via the feed and users opt in with opkg.

### Distro constraints

From `meta-calculinux-distro/conf/distro/calculinux-distro.conf` (read the inline comments -
they explain the *why* of nearly every non-obvious knob):

- **musl** libc (`TCLIBC = "musl"`) - no glibcisms in C/C++; for Rust, note what the in-tree
  `glkcli` patch does about `panic = "abort"` and similar.
- **No busybox** - `VIRTUAL-RUNTIME_base-utils = "packagegroup-calculinux-base-utils"`.
- **systemd**, `ROOT_HOME = "/home/root"` because the rootfs is read-only and `/root` would
  sit on it; recipes writing under `/root` as root need rethinking.
- Packaging is **ipk**; QA relaxed only on `patch-fuzz patch-status` - don't widen that.
- A large `PACKAGE_EXCLUDE` strips half of `linux-firmware`; new firmware means a deliberate
  override, not an assumption of presence.
- Target reality: 3× Cortex-A7, ~128 MiB RAM. `calculinux-qemuarm` mirrors it, so emulator
  and device share packages/feeds - validating in QEMU first is honest and fast.

### House style

(from `copilot-instructions.md`, enforced in review): prefer `${UNPACKDIR}`-relative paths
for build state; avoid bare `S = "${WORKDIR}"` (the `_git` recipes legitimately use
`${WORKDIR}/git` - that's fine, it's unpack output, not build scratch). Recipe *filenames*
are functional, not a matter of taste: bitbake derives the package version from the name
(`foo_1.2.3.bb` → PV `1.2.3`), and `_git` is a special suffix yielding `PV =
"1.0+git${SRCPV}"` plus unpack-to-a-git-checkout semantics - choose the filename to match how
the version is actually sourced. Pin upgrades via
`PREFERRED_VERSION_foo = "x%"` bbappends when the tree ships its own copy (the rust
`*_1.92.0.bbappend` files are the in-house pattern); pin `SRCREV` - floating
`SRCREV = "${AUTOREV}"` is the pattern that gets recipes BBMASKed.

**Rust & cargo notes:** toolchains are pinned to 1.92 via `local_conf_header`
(`PREFERRED_VERSION_rust/cargo(-native)/libstd-rs = "1.92%"`, sourced from
meta-lts-mixins' scarthgap-rust-mixin, which the apps layer already depends on - `inherit
cargo` just works). `RUST_LLVM_TARGETS` must stay consistent between native and target
rust-llvm or rustc references backends its libLLVM lacks; extending to new host/target
architectures means touching that list. Do not RDEPEND on target `rust`/`cargo` - a past
attempt made the image pull the whole LLVM build (removed in commit 35c1408, see its message
for the damage numbers). `Cargo.lock`/crate machinery (`-crates.inc`) only comes into play
for *crates.io/git-sourced dependencies*; a self-contained local source recipe (pure std,
vendored nothing) doesn't exercise it. If you do fetch crates: `FETCHCMD_wget` is overridden
*as a whole* in `kas-base.yaml` (crates.io 403s wget's default User-Agent) and any
`FETCHCMD_wget:append` would silently drop the wget binary from the command - change it as a
whole value or not at all.

Kernel options: `make kernel-config FRAGMENT=name` (menuconfig → diffconfig →
`meta-picocalc-bsp-rockchip/recipes-kernel/linux/files/<name>.cfg`). DT overlays: follow
`docs/DEVICE-TREE-OVERLAYS.md`.

## 6. Updating an upstream layer pin

The bread-and-butter maintenance task. Order matters:

1. **Pick the right upstream rev/branch.** Check the layer's `LAYERSERIES_COMPAT` on
   candidate revisions: choose the branch that still supports our series (usually the oldest
   series the maintainer kept alive). Bumping to a branch that dropped our series converts a
   bump into a compat-patch project - that's only wrong if you refuse to do that second half.
2. **Change the pin in the correct kas file** - shared layers in `kas-base.yaml`;
   machine-specific ones (meta-arm, meta-rockchip, meta-rauc, meta-rtlwifi) in the device or
   qemu kas file that imports them. One repos block per repo - duplicating a block across
   files causes confusing layer conflicts.
3. **Diff the layer between old and new revs** (`git log --oneline old..new`, `git diff` on
   `conf/layer.conf`): renamed/removed recipes, class switches, new `LAYERDEPENDS`. If the
   new rev's `LAYERSERIES_COMPAT` no longer lists our series, regenerate
   `patches/<layer>-<codename>-compat.patch` against it (golden rule 4) - or, if upstream has
   since blessed the series, *delete both the patch file and its kas entry* (the build runs
   `PATCHRESOLVE = "noop"`, so an obsolete-but-present patch fails the checkout hard). Media-heavy layers (audio/video/input
dependency soups like meta-retro) occasionally need a small *dependency-side* patch when a
newer upstream targets newer SDL/glib APIs - check consumers' `DEPENDS` versions during the
delta review; it's the exception, not the expectation.
4. **Audit BBMASK implications.** meta-retro's `slipr` and `mesa` are masked in
   `kas-base.yaml`'s `meta-retro-fixes` header (recorded rationale: problematic AUTOREV /
   missing dependencies - verify the current reason in the recipe itself before propagating
   it). New broken or autorev recipes in imported code deserve the same treatment; prefer the
   smallest globs that work, and re-check that existing mask paths still match - recipe
   moves silently void them.
5. **Expect signature churn.** An SRCREV bump refetches the layer's recipes and invalidates
   everything downstream for that subtree - a normal sstate miss *within* one YP release,
   not a cache purge. Never "help" by wiping the whole sstate dir.
6. **Validate incrementally, bottom-up:** `bitbake-layers show-recipes` in a shell (parse
   health) → the leaf recipes we consume → the `calculinux-image` / `calculinux-bundle`
   targets. Auditing consumers first (packagegroup entries, bbappends that pin recipes by
   exact name) catches rename-induced silence before the build does.
7. **Keep the bump atomic.** Pin + regenerated patches + any BBMASK go in one commit: CI's
   time-boxed passes make giant mixed-bump bisects miserable later.

## 7. The walnascar → wrynose (5.2 → 6.0) move *(transitional section)*

Migration is **in progress** - it lives on the `wrynose` branch (and the
`wrynose-merge-main` worktree under `.claude/worktrees/`). Once wrynose lands on main, this
section's comparison work is done: describe wrynose as the only stack (the sibling layout,
tag pins, and sstate/CI separation stay true; the walnascar column disappears). If you're answering a "how do I
X" question on wrynose, read *that* branch's `kas-*.yaml` / `layer.conf` - main's answers do
not transfer. Concrete deltas:

- **KAS repos block:** single `poky` → `bitbake` + `openembedded-core` + `meta-yocto`, all
  pinned by `tag: yocto-6.0.x` (release artefacts, not moving commits). Layer ownership
  shifts: `openembedded-core` serves `meta`, `meta-yocto` serves `meta-poky` (losing
  `meta-yocto` means losing `conf/distro/poky.conf` → every recipe dies at `require`); the
  compress-doc patch attaches to `openembedded-core`. Preserve the sibling layout KAS
  enforces (§1).
- **Per-series compat patches:** everything with a `*-walnascar-compat.patch` may need a
  `*-wrynose-compat.patch` twin where upstream hasn't blessed the series yet (meta-retro and
  meta-wayland have theirs on the migration branch); our own layers gain `wrynose` in
  `LAYERSERIES_COMPAT`.
- **Upgrade-safety gate:** `calculinux-distro.conf` defines `CALCULINUX_MIN_VERSION` /
  `CALCULINUX_MIN_BUILD_TIMESTAMP` (unset on main). Wrynose *should* set these to the last
  walnascar `DISTRO_VERSION` - full string including the `-channel+hash` tail - so devices
  only RAUC-upgrade forward into the new line once the gate is raised.
- **Separate universes:** distinct `DISTRO_CODENAME` → distinct feed paths, disjoint sstate
  and CI caches by construction. Note RAUC-compat strings are machine-defined and identical
  across branches - what separates the streams is the codename/feed/gate plumbing, not the
  RAUC strings.
- Companion pins (meta-arm, meta-openembedded, meta-rockchip, …) snap to 6.0-line revisions
  on wrynose; carrying main's pins into the new stack produces a Frankenstein mix where
  version-keyed bbappends silently stop matching.

## 8. Where to dig for authoritative documentation

### In-tree docs, pin-matched (highest authority, no network)

The Yocto Project documentation ships inside the checkouts - the exact revision you build:

- walnascar: `src-kas/poky/documentation/` (dev-manual, bsp-guide, kernel-customisation,
  reference-manual, … as reStructuredText) and `src-kas/poky/bitbake/doc/` (the bitbake user
  manual).
- wrynose: `kas-work-wrynose/bitbake/doc/` (bitbake manual travels with bitbake); note the
  6.0 `openembedded-core` checkout no longer carries a `documentation/` tree - use the online
  docs below for the 6.0 line. Some meta-layers ship their own docs in-tree (e.g.
  `meta-arm/documentation`).
- These are RST sources: `grep -ril "keyword" src-kas/poky/documentation/` finds the section
  faster than any website search, and it *matches your pin*.

### Curated online anchors

| Topic | Where |
|---|---|
| YP manuals (all) | https://docs.yoctoproject.org/ - select the branch matching your stack; the per-release **"Changes From Previous Revisions"** migration guides are the authoritative 5.2 → 6.0 delta |
| Bitbake user manual | https://docs.yoctoproject.org/bitbake/ (commands, `-e`/`-g`/tasks, scheduling) |
| KAS | https://kas.readthedocs.io/ (fragment model, `local_conf_header`, `repos`+`patches`, import/export) plus its container page for `kas-container` flags |
| RAUC | https://rauc.readthedocs.io/ (bundles, A/B slots, update flow) |
| musl porting | YP dev-manual porting chapter (in-tree copy preferred) |
| meta-openembedded | https://openembedded.github.io/ + per-layer READMEs (in the checkout, pinned, authoritative) |
| meta-lts-mixins (rust mixin) | repo README (git.yoctoproject.org/meta-lts-mixins, and in `src-kas/`) |
| meta-arm / meta-rockchip / meta-retro | in-checkout READMEs first; meta-arm.readthedocs.io; the meta-rockchip fork README (we build the vendor fork) |

### Authority ranking

Pin-matched in-tree docs (your exact checkout) > matching-branch online docs > other online
docs > general knowledge. Blog posts and forum threads are leads for hypotheses, never
citations - anything you act on from one must be re-verified against in-tree sources.

### Repo self-documentation

- `.github/copilot-instructions.md` — **canonical house rules** (build-dir discipline, patch
  hygiene, override conventions, recipe style). When it disagrees with this skill, it wins.
- `.github/workflows-README.md` — CI lanes, sstate cache strategy (keyed per YP release),
  the `.sources` mirror, PR-feed publishing.
- `docs/QEMU.md` — emulator rationale, end-to-end boot test, and the checklist for adding a
  new board (every machine-config knob).
- The `kas-*.yaml` comments and `calculinux-distro.conf` inline comments - dense, deliberate
  rationale for nearly every non-obvious knob; read them before changing the knob.
- `Makefile` — the sanctioned operation surface.
- ⚠️ Known doc drift: `README.md` links a `docs/RELEASE-PROCESS.md` that does not exist -
  the real release flow is `make release TAG=…` + tag-triggered CI.
- `.claude/worktrees/` holds teammates'/agents' in-flight work (incl. the wrynose merge).
  Inspect freely; never clobber.

Final reminder: this skill describes durable structure and hard-won traps. Values (pins,
versions, channel names, threshold sizes) live in the tree and drift - verify against the
current branch's files before stating them, and show the user the file rather than quoting
from memory.
