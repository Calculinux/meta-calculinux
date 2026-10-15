# Moving the Lyra to a mainline kernel: survey, RMIO prototype, and plan

Status: **branch-comparison survey complete; RMIO pinctrl prototype built,
tested on hardware and published** (2026-09-30). Upstream outreach drafted,
not yet sent. Nothing in this document changes what Calculinux ships today —
the vendor 6.1 kernel stays as-is until the workstreams below land.

Source materials: `~/repos/calculinux/kernel-update/` (workspace: mainline
clone, build trees, bring-up artifacts), the approved plan at
`~/.claude/plans/i-do-think-i-d-lovely-metcalfe.md`, and the 2026-09-28/30
survey session. All facts below were checked against source, TRM, lore, or
real hardware; the rare inference is marked **[inference]**.

Why we're looking: (1) MIPI DSI (the dsi-adapter / FL7707N panel work) needs
the mainline DSI/VOP stack; (2) the M0 (Cortex-M0) driver work in
picocalc-drivers should sit on a maintained base, ideally with an
upstreamable remoteproc driver; (3) a mainline base turns the kernel into
"vanilla + shrinking patch set" instead of an ever-growing vendor fork.

## 1. Branch-comparison survey: the available kernel sources

Four sources were surveyed (2026-09-28), plus the U-Boot situation.

| Source | Basis | RK3506 state | Verdict |
|---|---|---|---|
| `Calculinux/luckfox-linux-6.1-rk3506` | vendor 6.1 BSP (org fork of LuckFox's `0xd61/luckfox-linux-6.1-rk3506`) | Works; our 4 local commits | **Kept** as shipping kernel and DT reference |
| `megi/linux` branch `luckfox-6.18` (codeberg) | Rockchip's *pre-upstream* RK3506 code rebased onto 6.18 | Boots to shell; **vendor** clock/reset ID numbering | Reference only — not a base |
| `wdalmut/rk3506-framework` | Buildroot for the Lyra Plus; vendor 6.1 **and** mainline 7.2.3 options | Carries Rockchip's stalled pinctrl series + DTS only | Good prior art; its `docs/MAINLINE-STATO-E-RISCHI.md` is the most careful write-up available |
| torvalds mainline (7.3-rc5, 2026-09-27) | vanilla | Drivers present, **no DTS at all** | **Target** |

### 1.1 Calculinux vendor 6.1 (ships today)

Fork of the LuckFox 6.1 BSP with exactly four commits (plus seven
`file://` patches in `linux-rockchip_6.1.bbappend`):

- `815d6a4`/`577e2ab` overlayfs restore ioctl (later moved **out** of the
  kernel tree — see §5);
- `342ec34` `dwc2: detect gadget unplug via SOF when VBUS cannot drop`
  (PicoCalc's USB cannot see VBUS fall, so unplug detection rides on
  stop-frame silence; upstream PR #17, merged to our fork 2026-09-02);
- `c26ba68` PR #18 "Move the overlayfs restore ioctls out of the kernel tree"
  (squash-merge of the branch; the bbappend pin moved to it in PR #210).

Recipe facts (matter for a mainline successor): packaging is vendor
`zboot.img` (`ROCKCHIP_KERNEL_IMAGES=0`, `ROCKCHIP_KERNEL_COMPRESSED=1`);
`KBUILD_DEFCONFIG=rk3506_luckfox_defconfig`; config assembled from
`recipes-kernel/linux/files/*.cfg` fragments (base-configs, display,
filesystems, fonts, led, dto, …); `DEPENDS += "picocalc-devicetree"`; and a
two-pass DTC dance that trims the `__symbols__` section (full `-@` compilation
bloated the DTB 75 KB → 536 KB on the 3,100-label RMIO pinctrl dtsi, exceeding
the *vendor* U-Boot's FDT region — the mainline recipe drops this, see the
integration bullet in §7).

### 1.2 megi's `luckfox-6.18`

A single-commit shallow snapshot (base `8e691d4b04`, Ondrej Jirman, 2025-04-06):
Rockchip's own **older, pre-upstream** RK3506 port applied on 6.18. Key
properties:

- Its `rockchip,rk3506-cru.h` matches the **vendor** 6.1 file byte-for-byte —
  device trees written for it will *not* work on mainline later (different IDs,
  §2). 6.18-LTS longevity is therefore useless to us: nothing moves forward
  from it.
- No display: no VOP/DSI drivers; several DT compatibles have no driver in the
  tree (PWM, FSPI, CPU scaling); the RNG node uses a vendor-BSP driver.
- The valuable part is its **`rockchip_set_rmio()`** extension
  (`drivers/pinctrl/pinctrl-rockchip.c`, ~60 lines) plus its
  `rk3506-pinctrl-rmio.dtsi` — the ground truth for RMIO register math.

Role: **reference for DT nodes and the RMIO patch, never a base.**

### 1.3 `wdalmut/rk3506-framework`

Buildroot distro for the Lyra Plus with two kernel options (vendor 6.1,
mainline 7.2.3). Its Italian status/risk doc (`docs/MAINLINE-STATO-E-RISCHI.md`,
initially 2026-09-03 at 6.19, updated to the 7.2.3 pin) is the best prior art
and survived verification except where noted here. Load-bearing claims,
confirmed:

- **No LTS release includes RK3506.** Support entered mainline in
  **v6.19-rc1** — one release *after* the 6.18 LTS, so the first LTS to contain
  it will be a 2026-yearly LTS (candidate: 7.y, end of 2026).
- **Vendor DTBs boot silently with wrong clocks on mainline** — the clock IDs
  were renumbered upstream (e.g. `PCLK_UART0` 113 → 99). A mixed
  vendor-DTB/mainline-kernel combination does not fail loudly; it just runs on
  the wrong clocks. Never mix the two kernels' DTBs.
- The USB2 PHY runs without any Linux driver, relying on whatever state
  U-Boot/resets left it in (still true in 7.3, §2).
- It carries Rockchip's 7-patch pinctrl/RMIO series plus generated DTS and
  *no other driver changes*, so its mainline option is equally blocked on RMIO.

### 1.4 Mainline 7.3-rc5

Checked against a local clone (§3.5). Inventory in §2.

### 1.5 U-Boot and the firmware chain are unaffected by the kernel choice

Calculinux already ships **mainline U-Boot v2026.07** (PR #142) with the
Armbian/RK3506 patch stack, and its firmware chain comes from
`armbian/rkbin` (`SRCREV 1d3c610`, DDR init `rk3506_ddr_750MHz_v1.09.bin` +
OP-TEE `rk3506_tee_v2.10.bin`), with the `SPL_OPTEE_IMAGE` plumbing patch.
The TEE/DDR/OTP blobs therefore travel with us unchanged to any kernel —
important for the M0 (the SiP call is answered by the TEE, not the kernel,
§4).

**Conclusion of the survey: move to mainline** (start on the current -rc,
target the first LTS containing RK3506), keep vendor 6.1 as a *second kernel
provider*, and treat megi's tree as documentation.

## 2. What mainline 7.3 has and lacks for the RK3506

**Present** (files verified in the 7.3-rc5 clone):

- `drivers/clk/rockchip/{clk-rk3506.c,rst-rk3506.c}` + dt-binding headers;
- `pinctrl-rockchip` RK3506 banks **without RMIO**, plus a (previously
  undocumented) `rockchip,ioc1` syscon for bank-1 iomux/pull/drive;
- Display: **VOP** (`rockchip_vop_reg.c` rk3506_common), **MIPI-DSI**
  (`dw-mipi-dsi-rockchip.c` rk3506 chip data), **Inno DSI D-PHY**
  (`phy-rockchip-inno-dsidphy.c`) — all since v7.0;
- `dwmac-rk` (GMAC), `clk`/`rst`, bindings for i2c-rk3x, spi-rockchip,
  dw-mshc, saradc, snps-dw-wdt, dw-apb-uart, pinctrl; SFC (SPI-NAND/flash).

**Absent** (checked):

- **Any `rk3506.dtsi` or board DTS** — confirmed still true per the August
  2026 U-Boot "Miscellaneous updates for RK3506" series: *"There is no rk3506
  DTSI available either in Linux kernel or U-Boot, so this fallback
  technically doesn't even exist (yet)."*
- **RMIO** (secondary pin matrix — §3); **USB2 PHY** register hooks (the
  RK3528 USB2 series of May 2026 touches the shared 480 MHz PHY clock control
  for "RK3528 and RK3506" but is not in 7.3);
- TSADC, OTP (the Feb/Mar 2026 OTP series covers RK3528/3562/3568 only —
  RK3506 mentioned in a commit message but *not* included), **cpufreq/PVTPLL**,
  PWM v4 (Frattaroli's MFPWM series is at v5, Apr 2026), mailbox, an RK3506
  compatible for `rockchip_sai.c` (only `rockchip,rk3576-sai` matches),
  FL7707N panel driver.

**Renumbered IDs** (vendor 6.1 → mainline 7.3), which is what breaks the DT ABI
silently:

| Resource | vendor | mainline |
|---|---|---|
| `HCLK_M0` | 74 | 60 |
| `STCLK_M0` | 104 | 90 |
| `PCLK_TIMER` | 76 | 62 |
| `CLK_TIMER0_CH5` | 82 | 68 |
| `SRST_H_M0` | 90 | 35 |
| `SRST_M0_JTAG` | 91 | 36 |
| `SRST_HRESETN_M0_AC` | 10 | `SRST_H_M0_AC` = 8 |
| `PCLK_UART0` | 113 | 99 |
| `SCLK_UART0` | 118 | 104 |

Upstream in motion that affects this: Chaoyi Chen's **DSI timing/lane-rate
series** (v4, Aug 2026; Heiko requested a v5) adds RK3506 `max_bit_rate_per_lane
= 1.5 Gbps`, PX30-style PHY timing and an 11 %-overhead bandwidth calc — needed
for panels at the higher pixel clocks; Jonas Karlman's U-Boot series implies
`OF_UPSTREAM` for RK3506 the moment an upstream `rk3506.dtsi` exists (making
him a natural Series-B reviewer, §7).

## 3. RMIO — the keystone

### 3.1 Why RMIO dominates everything

RMIO (Rockchip Matrix I/O) is a second mux stage on 32 pads: the pad's iomux
routes the signal to the matrix, and a per-pin register then selects one of
~99 peripheral functions. On the PicoCalc **every peripheral lives behind it**
(Lyra `RM_IO*n` balls → matrix → STM32/I2C2, ILI9488/SPI0, SD/SPI1). Without
RMIO support, a mainline kernel boots with a dead keyboard, dead LCD and dead
SD slot.

Encodings in the wild:

- **Vendor 6.1**: RMIO expressed as out-of-range `rockchip,pins` mux values
  (>15, e.g. `<0 RK_PA4 85 …>`); the BSP carries `rockchip_set_rmio()` which
  maps mux−15 to the register;
- **megi 6.18**: same idea, ~60-line `rockchip_set_rmio()` + a 15k-line
  generated `rk3506-pinctrl-rmio.dtsi`;
- **Rockchip upstream v4**: custom `rockchip,rmio-pins` matrix property + the
  generated dtsi — rejected, §3.2.

Fixed pad wiring (TRM ch. 19 table 19-1; matches vendor `rk3506-pinctrl-rmio.dtsi`
exactly — 32 distinct combos, none varies):

```
RM_IO0..23  = gpio0.A0..C7            (bank 0, pins 0..23)
RM_IO24..27 = gpio1.B1,B2,B3,C2       (bank 1, pins 9,10,11,18)
RM_IO28..31 = gpio1.C3,D1,D2,D3       (bank 1, pins 19,25,26,27)
```

(Note: RM_IO28/30 = GPIO1_C3/D2 — the very pads Calculinux's dtsi assigns to
the SD slot on `spi1`; the matrix is also why the keyboard-IRQ doc's uart1-vs-SD
pinmux question can never be resolved by "routing": it is matrix arbitration,
not pin shortage.)

PicoCalc usage: 10 pins — RM_IO4-7 (LCD, SPI0), RM_IO10/11 (keyboard, I2C2),
RM_IO28-31 (SD, SPI1).

### 3.2 Rockchip's v4 series and why it stalled

`[PATCH v4 0/7] pinctrl: rockchip: Add RK3506 and RV1126B pinctrl and RMIO
support` (Ye Zhang, 2025-12-27; [thread](https://lore.kernel.org/linux-rockchip/20251227114957.3287944-1-ye.zhang@rock-chips.com/)).
Read in full from the mbox (19 messages). Positions on record:

- **Linus Walleij** (Jan 2026): *"No custom invented properties please."*
  Proposed the standard-`pinmux` shape — each pin state gets `iomux {}` and
  `rmio {}` subnodes carrying `pinmux = <a << 16 | b << 8 | c>` — and deferred
  to the DT binding maintainers, **"especially Conor"** (Dooley).
  **Conor never replied.** No v5 has appeared since 2026-02-08.
- **Krzysztof Kozlowski**: rejected the 25k-line generated RMIO dtsi —
  *"Upstream is not your SDK"*; boards define only the groups they use.
- Patches 1-4 (RV1126B pinctrl, GPIO V2.x) gathered acks independently of RMIO.

Incentive analysis (owner's read): Rockchip funds upstreaming to *shrink its
fork*. An upstream-shaped RMIO doesn't do that — its SDK and customer DTS keep
the vendor mux>15 encoding regardless, so it would carry its own form anyway,
and reshaping all customer DTS for an investor-agreeable payback is off the
table. **Assumption adopted: Rockchip will not continue the RMIO series;
Calculinux owns it end-to-end, including future maintenance.** Rockchip stays
a source of hardware facts (register map, pin ranges, RK2116's multiple RMIO
instances) and Ye Zhang's authorship/`Co-developed-by` is credited wherever
their register logic is reused. The same test governs all other drivers
("does this upstream shape ≈ vendor code? if yes, check lore — Rockchip may
send it themselves").

### 3.3 TRM-verified facts (RK3506 TRM Part 1 V1.2, ch. 19 + 5.5)

- Registers live in `GRF_PMU` at `0xFF910000`: 32 selects
  `RM_IO*_sel` at offsets `0x80 + 4·pin` (through `0xfc`), 7-bit
  `func_sel` in the low byte, mirrored/high-byte write mask (vendor:
  `rmask 0x7f007f`, write `0x7f0000 | func`). `grf_pmu` size is genuinely
  `0x4000` per the TRM address map.
- Function list (99 entries, identical on all 32 pins): 0 = none; 0x13/0x14 =
  I2C2 SCL/SDA; 0x43-0x46 = SPI0; 0x48-0x4B = SPI1; 0x0D = D-PHY TE, etc.
- The pad's iomux is **always 4'h7** when RMIO is in use — i.e. derivable from
  the RMIO pin, which shapes the binding discussion (§3.4).
- **One-function-per-pin rule**: a function selected on two RMIO pins connects
  to neither. Enforced in our driver (§3.4).
- `GRF_PMU` offsets `0x2000-0x2500` (CPU isolation) **abort on non-secure read**
  (secure-locked, presumably by OP-TEE). A full regmap debugfs dump of the
  `0x4000` window therefore hung the CPU during bring-up; the fix is declaring
  the syscon window `0x2000` (dump then ends safely at `0x1ffc`).

### 3.4 The prototype (published)

Branch [`rk3506-rmio`](https://github.com/Calculinux/linux/commits/rk3506-rmio)
on `Calculinux/linux` (org fork of torvalds/linux, created specifically so a
true fork shares objects with upstream — a flattening snapshot hits GitHub's
2 GiB pack cap, which it actually did on first push), based on
`linusw/linux-pinctrl` `devel` (2026-09-24). Three commits, ~500 LOC:

1. `c91edc5` `dt-bindings: pinctrl: rockchip: Document rockchip,ioc1` —
   the driver has looked up `rockchip,ioc1` for RK3506 since pinctrl support
   landed (`dbd2317`), but the binding never described it, so **every RK3506
   DT fails schema check today**. Fixes-tagged, stand-alone.
2. `0f7cb03` `dt-bindings: pinctrl: rockchip: Add generic pinmux groups and RMIO`
   — group nodes may carry an `iomux` subnode (`pinmux = <RK_PINMUX(bank, pin, func)>`
   + generic pinconf) and an optional `rmio` subnode (`pinmux = <RK_RMIO(rmio, pin, func)>`);
   `rockchip,rmio` syscon phandle **allowed only for rk3506** (Krzysztof's
   if/then point); `rockchip,pins` untouched for everyone else.
3. `356316b` `pinctrl: rockchip: Support generic pinmux groups and RK3506 RMIO`
   — parses the new shape (existing `pinconf_generic_parse_dt_config()` reused);
   writes the **RMIO function before** flipping the pad iomux (a pad never
   drives the outgoing function), with atomic-ish revert on failure; enforces
   the TRM one-function-per-pin rule (`-EBUSY` on conflict; stale selections
   left by bootloader/previous state on pins nobody currently uses are
   cleared); duplicate pins/functions within a group rejected; pinmux groups
   with no pin config emit no config map (the pinctrl core rejects empty
   config maps); register math per §3.3 with per-SoC table (RK2116-ready
   encoding: id in the high byte).

Board group example (PicoCalc I2C2):

```dts
i2c2_rmio10_11: i2c2-rmio10-11 {
    iomux {
        pinmux = <RK_PINMUX(0, RK_PB2, 7)>,
                 <RK_PINMUX(0, RK_PB3, 7)>;
        bias-disable;
    };
    rmio {
        pinmux = <RK_RMIO(0, 10, 19)>,
                 <RK_RMIO(0, 11, 20)>;
    };
};
```

Open shape question (put to Conor in the draft): since the TRM makes the pad
derivable from the RMIO pin, is the `iomux` node cargo cult, or does
maintainer preference keep both nodes? Either is a small parser change; the
prototype validates agreement between the two.

### 3.5 Build & test method (reusable)

- **Dev tree**: blobless clone of torvalds/linux at
  `kernel-update/mainline` with remotes `linusw/linux-pinctrl`
  (`devel`, `for-next`) and `mmind/linux-rockchip` (`for-next`,
  `v7.4-armsoc/dts32`); `b4` + `dtschema` installed as uv tools; cross builds
  with the host Clang 22 (`make LLVM=1`), no cross-gcc needed.
- **Config**: `multi_v7_defconfig` + `kernel-update/configs/rk3506-bringup.config`
  (ARCH_ROCKCHIP, CRU, pinctrl, DW APBUART, I2C, SPI/SFC, dw-mshc+MMC_SPI,
  SARADC, PL330, DWC2+configfs RNDIS/ECM/NCM, EXT4/OVERLAY/SQUASH, debugfs+devmem,
  LEDs, plus `CONFIG_CMDLINE="console=ttyS0,1500000 clk_ignore_unused"` +
  `CMDLINE_EXTEND=y` — the Calculinux boot script passes `console=ttyFIQ0`,
  which only exists in the vendor kernel).
- **Test image**: plain `dtc` FIT (`bringup/mainline-test.its`): unpacked
  zImage at `0x140000`, bring-up DTB (`rk3506g-luckfox-lyra-picocalc.dtb`) at
  `0x63000`. The WIP bring-up DT lives on local branch `rk3506-lyra-wip`
  (not pushed yet — push it when reviewers should be able to reproduce).
- **Hardware test without a serial console**: the boot
  script prefers `/data/fit/zboot_merged_<slot>.img` when
  `FIT_LAST_TRIED != data` and stores `FIT_LAST_TRIED=data` before `bootm`;
  preinit resets it to 0 after a good boot (works under mainline too). So:
  back up slot B's data-FIT → install the test FIT → reboot → test over SSH
  (RNDIS gadget `usb-gadget-network.sh` tolerates the mainline module
  layout; the link is back in ~40 s) → restore FIT (byte-identical, stamp
  unchanged, `FIT_LAST_TRIED=0`) → reboot. A hang resolves itself: power-cycle
  falls back to the `/boot` FIT (vendor kernel).
- **Checks** (`bringup/rmio-check.sh` + live follow-ups): pinmux-pins claims,
  `grf_pmu` regmap readback of all RMIO selects (MMIO reads refused by
  `/dev/mem` on 32-bit ARM → read through regmap debugfs, first 1 KiB only
  pre-fix), `i2cdetect -y 2`, mmc_spi dmesg + block devices, pinctrl error
  scan.

### 3.6 Results (hardware test, 2026-09-29/30; board-visible RAM 128 MiB)

| Check | Result |
|---|---|
| Kernel | `7.3.0-rc1-00043-ge3120e5d4295` (pinctrl `devel` + 3 commits), boots |
| RMIO pads claimed | all 10: gpio0-4..7 (spi0-rmio4-7), gpio0-10/11 (i2c2-rmio10-11), gpio1-19/25/26/27 (spi1-rmio28-31) |
| RMIO register readback | **10/10 OK** (RM_IO10=`0x13` I2C2_SCL, RM_IO4=`0x46` SPI0_CSN0, RM_IO29=`0x48` SPI1_CLK, …) |
| Stray selection | RM_IO21 holds one function (thermal-shutdown/TSADC CTRL output) set earlier in the boot chain; correctly *left alone* by the conflict logic |
| I2C2 | keyboard controller STM32 @0x1f + RTC @0x68 present |
| SPI1 | PicoCalc SD card detected, `mmcblk1p1` (a transient `spi1: Failed to setup device: -22` precedes the successful detect) |
| `grf_pmu` limited to `0x2000` | full 2048-register regmap dump ends at `0x1ffc`, no abort |
| pinctrl errors / `-EBUSY` | none |
| Device restored | byte-identical FIT, vendor kernel back, env unchanged |

Schema regression: `dtbs_check` against `rockchip,pinctrl.yaml` over **all
287 in-tree Rockchip DTBs (241 arm64, 46 arm)** in the `wt-base`/`wt-rmio`
worktrees → **zero new warnings** versus unpatched `devel` (`dtbcheck.sh` +
`dtbcheck-*-arm*` dirs retain the trees). Still owed: live boots on
**Rock Pi S (RK3308)** and **Rock Pi 4 (RK3399)** diffing
`/sys/kernel/debug/pinctrl/*/pinmux-pins` and `pinconf-pins` against unpatched
(`make bindeb-pkg` .debs for Armbian-SD planned).

Bring-up log issues filed for Series B
(`bringup/logs/lyra-mainline-e3120e5d4295-dmesg.txt`): CMA default 64 MiB
fails on the board's 128 MiB; `adc-keys` has no keymap; CPU nodes lack
`clock-frequency`.

## 4. Consequences for the M0 (Cortex-M0) work

Deep-written in `kernel-update/notes/rk3506-m0-memory.md` (TRM Part 1 ch. 7 +
[nvitya/rk3506-mcu](https://github.com/nvitya/rk3506-mcu) issues #1-#3 + the
attached #2 patch, vs. our `picocalc_rk3506_rproc` and audio firmware).
Headline findings:

- **Portability is excellent**: the vendor kernel has *no* RK3506 remoteproc
  or mailbox driver at all; our drivers ride on generic remoteproc + the SiP
  call answered by rkbin's OP-TEE (kernel-independent), hrtimers,
  reserved-memory and ALSA. Port cost = DT ID renumbering (§2 table, use
  60/90/62/68 for the four clocks we hold) + API churn (`hrtimer_init` →
  `hrtimer_setup`; `.remove` now void; LCD's `drm_fbdev_generic_setup` →
  `drm_client_setup` family).
- **SRAM/TCM regime**: System SRAM slices at `0xFFF80000/0x…4000/0x…8000`
  (16 KiB each). Stock TEE sub-op `CODE_START_ADDR=0xFFF84000` flips
  SRAM1+SRAM2 into M0 TCM and there is **no unmap sub-op** (reload impossible);
  *any other* start address leaves the SRAM AXI-readable and the firmware
  reloadable. **Our design exploits this**: audio firmware linked at
  `0xFFF88000`, 16 KiB, ELF entry passed as start address. First 4 KiB of
  SRAM0 is off-limits (OP-TEE/boot use).
- **Driver TODOs adopted** (from nvitya #2's patch, kluoyun): issue the SiP
  call **on CPU0** (`work_on_cpu(0, …)` — the vendor TEE maps the secure SGRF
  on the boot CPU); **hold `SRST_H_M0` while stopped** and pulse
  `SRST_H_M0_AC` before changing the address map; `wmb()/dsb` between firmware
  copy and core release; verify the `PMU_INT_MASK_CON` (`0xFF90000C`) stop
  value (`0x00060006` theirs vs `0x00060002` ours — bits 2/1 are
  `mcu_rst_dis_cfg`/`glb_int_mask_mcu`).
- **Isolation/firewall**: `GRF_PMU_MCU_ISO_*` (`0xFF911000+`) gate what the
  M0 may reach; first check when "the M0 can't see X". Our M0 reaches the
  DDR ring at `0x03C00000` under our boot chain (mainline U-Boot + rkbin TEE),
  unlike nvitya's self-built TF-A setup (also: his TF-A broke Linux's ability
  to write the MCU_ISO registers).
- **Clocks**: rproc node must hold the M0's clocks (mainline IDs above);
  `clk_disable_unused` will otherwise kill them (known Rockchip AMP footgun).
- **Debug**: M0 NVIC fed by a 125:4 INTMUX at `0xFF2A0000`; SWD exists but its
  enable path is undocumented (suspected `SGRF_PMU` write; vendor U-Boot has a
  commented `writel(0x00220000, 0xff960000)` selecting "jtag m1" = GPIO0C6/C7).
- **Tee options settled against us**: binary-patching
  `rk3506_tee_v2.10.bin` (kluoyun's unmap trick) is **out** — the rkbin
  LICENSE forbids deriving/modifying the binary, and its author states a
  patched TEE stops fused devices booting (recoverable, not brick, but not
  shippable). The **clean route** is upstream OP-TEE: there is now an **RK3506
  port** (`plat-rockchip`, commit `d66a5170a370`, 2026-06-17, Owen O'Hehir,
  merged after 4.10.0 — DDR firewall, SGRF slave opening, ARM32 PSCI without
  SYSTEM_RESET/OFF, secondary-CPU bring-up) but **no MCU SiP handler**. Adding
  a Rockchip-compatible `0x82000028` handler (+ unmap, e.g. `CODE_START_ADDR=0`)
  to it would yield reloadable 32 KiB TCM in open source; **blocker**: the
  SGRF_PMU MCU registers (`mcu_tcm_selN`, code-start, M0 clock/debug enables)
  are not in TRM Part 1 (Part 2 is not public) — sources are Part 2 itself or
  Owen (whose port uses SGRF layouts), and the RK3528 vendor SPL sequence shows
  the shape. Must then verify M0→DDR master rights and reboot-without-PSCI-
  SYSTEM_RESET.
- **Secure boot is a non-issue for Calculinux**: the fuse is a *secure* OTP
  byte (`0x20`, Secure OTPC `0xFF520000`, `0xFF`=enabled) unreadable from
  Linux; any board that boots our **unsigned** idbloader/SPL cannot be fused,
  so every Calculinux board is by construction unfused. **[inference chain,
  no fused board observed]**

Open M0 decisions (parked): TCM-vs-AXI performance benchmark; test-boot an
upstream OP-TEE build; message to Owen O'Hehir about the SGRF_PMU MCU
registers.

## 5. Disposition of Calculinux's local kernel modifications

| Item | Where | Fate on mainline |
|---|---|---|
| overlayfs restore ioctl (~800 LOC) | was vendor-fork commits; **now out-of-tree** `Calculinux/overlayfs` (one branch per kernel series: `linux-6.1` Lyra, `linux-6.12` QEMU; `CONFIG_OVERLAY_FS=n` in both trees, module loaded by preinit; `ovl-restore --state`) | Ships this way on vendor 6.1 (PRs #208+#210, Sept 2026) — the kernel side is the *shrinking* part now. For mainline: the module needs a `linux-7.x` branch before the mainline recipe can carry it; the ioctl itself remains a future upstream candidate in its own right (separate session is shaping it) |
| `dwc2` SOF unplug detection | vendor-fork `342ec34` (upstream PR #17) | **Keep local** to whichever kernel ships (PicoCalc quirk; possible `linux-usb` RFC someday, out of scope) |
| configfs DT overlays (`0001-of-configfs-overlay-interface.patch`, `dto.cfg`) | bbappend | **Drop** on mainline: overlays are compiled into the DT for reboot; the mainline recipe omits the patch and `CONFIG_OF_CONFIGFS`. Keep `__symbols__` generation — `merge-dt-overlays-boot`/`fdtoverlay` still resolve phandles through it. Runtime-configfs hints in picocalc-drivers overlay comments (`m0-audio-overlay.dts`) get updated when the drivers port |
| depmod skip (`depmod-skip-when-echo.patch`) | bbappend | Expected **unnecessary on mainline**; build once and drop if clean |
| btrfs print-tree warn fix | bbappend | Same: build on mainline, drop if clean |
| mmc-spi NULL-regulator guard | bbappend | **Retest on mainline**; drop if the shutdown crash doesn't reproduce (may already be fixed upstream) |
| spi-rockchip max SCLK 100 MHz | bbappend | Re-apply for mainline (LCD SPI speed depends on it; also available as the opt-in 100 MHz DT overlay from picocalc-drivers) |
| lib/fonts Terminus 6x12 console font | bbappend | Re-apply for mainline (console font parity; PR #186) |
| btrtl firmware format v2 | bbappend | Re-apply for mainline (RTL Bluetooth firmware format support) |
| fbcon scrollback restore (654 LOC patch, on disk) | unreferenced in current `SRC_URI` | Already dead weight; **do not resurrect** |
| `luckfox-dts-support.patch` (12 lines, on disk) | unreferenced in current `SRC_URI` | Leftover; ignore |

## 6. Feature gaps a mainline machine starts out with (and the queue to close them)

Lost relative to vendor 6.1 until ported, rough order of value/effort (each
gated by the lore-search/incentive test of §3.2):

1. **CPU frequency scaling / PVTPLL** — CPU stays at whatever U-Boot sets;
   biggest single hole, largest effort (last).
2. **Thermal (TSADC)** — no governor without it.
3. **OTP (nvmem)** — the Mar-2026 merged series restructured word sizing;
   adding rk3506 is small.
4. **SAI compatible** for the PCM5102A I2S overlay (if the IP matches rk3576).
5. **USB2 PHY** GRF table in `phy-rockchip-inno-usb2.c`, coordinated with the
   RK3528/RK3506 `clkout_ctl_phy` 480 MHz series.
6. **DSI**: test Chaoyi Chen's v5 on hardware, `Tested-by` (the DSI panel work
   waits on this plus the next two).
7. **FL7707N panel driver** (`drivers/gpu/drm/panel/`) — the dsi-adapter
   overlay relies on vendor `simple-panel-dsi` + DT `panel-init-sequence`,
   which mainline doesn't speak; ~300-line upstreamable panel driver from the
   adapter's init sequence.
8. **Backlight** — the adapter's `pwm-backlight` sits on a PWM **v4** channel;
   blocked on Frattaroli's MFPWM series landing (v5, Apr 2026), then an
   rk3506 compatible. Interim: GPIO backlight.
9. **Mailbox** (needed if M0→A7 interrupts are ever wanted) and the **M0
   remoteproc binding** (new; syscon phandles instead of raw PMU/CRU/GRF
   ioremapping; `memory-region` for the SRAM slice instead of hard-coded
   addresses; document the closed SiP ABI — precedent: i.MX rproc uses SMC).
10. **PWM v4** (also unlocks the PWM-audio M0-less path today) — same MFPWM
    gate.

Also: U-Boot's `OF_UPSTREAM` for RK3506 is blocked precisely on an upstream
`rk3506.dtsi` existing, so Series B unblocks that path too (Jonas Karlman as
natural reviewer).

## 7. The plan (approved 2026-09-29)

Full text: `~/.claude/plans/i-do-think-i-d-lovely-metcalfe.md`. Shape:

- **Workstream 0 — dev tree/tooling**: done (`kernel-update/mainline` blobless
  clone + pinctrl/rockchip remotes; b4, dtschema, checkpatch, `CHECK_DTBS`;
  publish model = true forks of torvalds/linux under the Calculinux org).
- **Workstream A — RMIO (Series A)**: prototype **done and published**
  (§3.4). Remaining: send the draft reply on the v4 thread
  (`kernel-update/bringup/rmio-outreach-draft.txt` — asks Conor to confirm the
  `iomux {}`/`rmio {}` shape, offers the RK2116 register-layout question to
  Ye Zhang, suggests letting acked patches 1-4 go ahead without RMIO); then
  v5 or adaptation once the binding shape settles.
- **Workstream B — SoC + board DTS (Series B, to Heiko's tree)**: rewrite
  `rk3506.dtsi` on **mainline IDs** (starting from megi's, include only
  nodes with mainline drivers/bindings), then `rk3506g-luckfox-lyra.dts`
  (boards we own first: Lyra; Plus/B later) + `arm/rockchip.yaml` compatible;
  must be `dtbs_check`-clean; the bring-up `rk3506-lyra-wip` branch is the
  seed (fix the three §3.6 dmesg items first).
- **Workstream C — per-driver series** (§6 list, one small series each, lore
  search first).
- **Integration (parallel, internal)**: a `linux-mainline` recipe in
  `meta-picocalc-bsp-rockchip` alongside vendor 6.1 as a *second kernel
  provider* (the two DTBs are **not interchangeable** — mixing boots with
  wrong clocks, §1.3/§2); picocalc-drivers port (DRM fbdev API, `hrtimer_setup`,
  void `.remove`, M0 overlay clock/reset IDs) against it. Mainline-specific
  recipe simplifications: drop vendor `zboot` packaging; the `__symbols__`
  trimming can go away (no 15k-line RMIO dtsi, and mainline U-Boot has room);
  drop configfs-DTO; keep the fragment mechanism.
- **Verification gates**: per series `checkpatch --strict`, `dt_binding_check`,
  `CHECK_DTBS`; shared-driver regression on **Rock Pi S (RK3308)** and
  **Rock Pi 4 (RK3399)** (boot Armbian from SD, diff pinctrl debugfs against
  unpatched) + the 287-DTB schema sweep (re-run after every change); on Lyra:
  RMIO claims + register readback, keyboard/LCD/SD all functioning.
- **Rules**: nothing is emailed/posted by the assistant — drafts and `b4`
  staging only, the user reviews and sends from their own account with DCO
  `Signed-off-by`; the prototype commits currently carry
  `Assisted-by: Claude:claude-opus-5-5` (per `coding-assistants.rst`) but no
  `Signed-off-by` — `b4 prep`/trailers before sending; Rockchip authorship
  credited where their register code is reused.

## 8. Open items (as of 2026-09-30)

1. Rock Pi S / Rock Pi 4 regression boots (`bindeb-pkg` .debs for plain
   `pinctrl/devel` vs `rk3506-rmio` can be built in advance).
2. User code review of the 3 prototype commits, then send the v4-thread reply
   (placeholder left in the draft: the Rock Pi comparison).
3. Conor's answer on node shape (two subnodes vs driver-deriving `iomux`).
4. Push `rk3506-lyra-wip` if/when reproducible bring-up matters to reviewers.
5. Series B: fix CMA 64 MiB → suit the 128 MiB board, add `clock-frequency`
   to CPU nodes, drop/quiet `adc-keys`, then the SoC dtsi + board DTS to
   Heiko.
6. M0: decide the parking lot (§4 — benchmark, upstream-OP-TEE test boot,
   Owen O'Hehir outreach); adopt the rproc TODOs (CPU0 SMC, reset-hold, wmb)
   in picocalc_drivers.
7. `Calculinux/overlayfs`: a `linux-7.x` branch before the mainline recipe
   can carry the restore ioctls.
8. Track: Chaoyi Chen DSI v5; MFPWM/PWM-v4 v5; the RK3528/RK3506 USB2 PHY
   clock series; the first LTS containing RK3506 (pin target for the LTS
   switch).
9. The `grf_pmu` `0x2000` window limit must be revisited in Series B (we can
   declare 0x4000 in the *binding* if we add a regmap flag to skip the
   secured half for debug dumps, or keep 0x2000 and document why).

## 9. Artifacts & sources

| Artifact | Location |
|---|---|
| Working dev tree, WIP bring-up branch, fork remote `calculinux` | `~/repos/calculinux/kernel-update/mainline` |
| Published prototype (3 commits on pinctrl `devel`) | `github.com/Calculinux/linux` branch `rk3506-rmio` (head `356316b878d6`) |
| Outreach draft (v4-thread reply, ready minus Rock Pi para) | `kernel-update/bringup/rmio-outreach-draft.txt` |
| Bring-up config / FIT template / check script / boot log | `kernel-update/configs/rk3506-bringup.config`, `bringup/mainline-test.its`, `bringup/rmio-check.sh`, `bringup/logs/lyra-mainline-e3120e5d4295-dmesg.txt` |
| 287-DTB schema sweep trees + runner | `kernel-update/wt-base`, `wt-rmio`, `dtbcheck-*`, `configs/dtbcheck.sh` |
| M0 memory/OP-TEE/secure-boot notes | `kernel-update/notes/rk3506-m0-memory.md` |
| Approved plan | `~/.claude/plans/i-do-think-i-d-lovely-metcalfe.md` |
| Persistent memory notes | `mainline-kernel-rk3506-status`, `rk3506-upstreaming-plan`, `rk3506-docs`, `lyra-ssh-test-boot` (project memory dir, meta-calculinux) |
| Vendor kernel fork (ships) | `github.com/Calculinux/luckfox-linux-6.1-rk3506` (4 commits; PR #17 dwc2, #18 ioctl move-out) |
| Current recipe | `meta-picocalc-bsp-rockchip/recipes-kernel/linux/linux-rockchip_6.1.bbappend` (pinned at `c26ba687e`, PR #210) |
| megi reference tree | `codeberg.org/megi/linux` branch `luckfox-6.18` (local: `kernel-update/linux`) |
| wdalmut prior art | `github.com/wdalmut/rk3506-framework` → `docs/MAINLINE-STATO-E-RISCHI.md` |
| Rockchip RMIO series | [lore v4 thread](https://lore.kernel.org/linux-rockchip/20251227114957.3287944-1-ye.zhang@rock-chips.com/) (19 msgs, mbox retained in the survey session) |
| Maintainer positions | Linus Walleij's two-subnode sketch: [lore](https://lore.kernel.org/linux-rockchip/CAD++jL=fri43Q1XbMJoOUeoWJw9RwMDJLjcjO8zSbyHb7z+Dzg@mail.gmail.com/) |
| In-flight upstream | DSI v4 [lkml 17400378](https://ratatoskr.run/lkml/2026/08/17400378/t) · U-Boot RK3506 misc [17368461](https://ratatoskr.run/u-boot/2026/08/17368461/t) · MFPWM v5 [3520983](https://ratatoskr.run/lkml/2026/04/3520983/t) · OTP (no RK3506) [3403857](https://ratatoskr.run/linux-arm-kernel/2026/02/3403857/t) · USB2 PHY clock [3545844](https://ratatoskr.run/linux-devicetree/2026/05/3545844/t) · upstream OP-TEE RK3506 port `d66a5170a370` (2026-06-17) |
| Hardware docs | RK3506 TRM Part 1 V1.2 (esp. ch. 4 M0, 5.5 GRF_PMU, 7 SRAM, 13 mailbox, 18 IOC, **19 RMIO**, 23 SAI, 31 PWM), RK3506G2 datasheet V1.3, pinout xlsx, REF schematic (kept by the survey operator) |
| Calculinux-side PRs touching this area | #142 (mainline U-Boot 2026.07) · #208/#210 (overlayfs out-of-tree + pin) · #186 (console font) · related: picocalc-drivers#34 (keyboard IRQ — RM_IO ball cross-reference) |
