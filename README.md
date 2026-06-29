# Surface Duo 2 — Android 12 → Android 11 downgrade (WORKING)

Roll a Surface Duo 2 back to the **final Android 11 build, `2022.521.8`**, from a bricked /
half-flashed state. This kit is the result of a full recovery done on **2026-06-29** on device
`0F001JX211900A` (product `surfaceduo2`). It boots clean: setup screen, working touch, stable.

> **Bootloader must be UNLOCKED** (`fastboot getvar unlocked` → `yes`). This wipes all data.

---

## Download the flashables (GitHub Release)

The large binaries (the rebuilt `super` and the partition images) are **not in git** — they're in
the latest [**Release**](../../releases/latest). Download from there, then:

1. Put `images.zip` next to `flash_all.bat` and **extract it** so you have an `images/` folder.
2. Download **all** the `super_built.img.part*` files (part00 … part12), put them in the same folder,
   and run **`join_super.bat`** (Windows) or `bash join_super.sh` — this reassembles `super_built.img`.
   Optionally verify: `certutil -hashfile super_built.img SHA256` vs `super_built.img.sha256`.

### Mirror — original `.img` and OTA downloads
Direct download links for the source images and the official OTA updates (Android 11 **and** 12):
**https://fs.nekos.farm/folder/cmqyviz2o000901pcpn8fg8op**
Use these if you want the stock OTA zips (e.g. to sideload, or to rebuild `super` yourself per the
*Rebuilding* section below).

## TL;DR — just fix my Duo 2

1. Get the flashables from the Release (above): extract `images/`, join `super_built.img`.
2. Put the phone in the bootloader: power off, then hold **Volume‑Up + Power** (or `adb reboot bootloader`).
3. Confirm it's seen: `fastboot devices`
4. Double‑click **`flash_all.bat`** (or run it from a terminal in this folder).
5. Wait ~4–5 min. It reboots itself. First boot after the wipe takes 2–5 min — be patient.

That's it. The rest of this file explains *why* it works, so you can fix it again from scratch.

---

## What was actually wrong (root cause)

The Duo 2 is a **Virtual A/B** device with a **single, non‑slotted `super`** partition that holds the
dynamic logical partitions `system / system_ext / product / vendor / odm` (each slot‑suffixed, e.g.
`system_a`). The real `super` partition is **15,032,385,536 bytes** (`0x380000000`).

Every popular "community" Duo 2 `super.img` floating around (the one in `fastboot_surface_ROM`,
the MIO‑Kitchen `duo2_output`, etc.) was **built wrong for this device**. `lpdump` of it shows:

| field | community super (BAD) | what the device needs |
|---|---|---|
| super block‑device size | **9,126,805,504** | **15,032,385,536** |
| logical partition names | `system` (no suffix) | `system_a` (slot‑suffixed) |
| group name | `main` | `surface_dynamic_partitions` |

`liblp` validates the super size stored in the metadata against the *real* partition size. Because
the community image claimed 9.13 GB on a 15.03 GB partition, **liblp rejected the metadata** →
the device enumerated **zero logical partitions** → `init` could not mount `/system` `/vendor` →
**boot‑loop straight back to the bootloader.**

Symptoms this produced along the way:
- "Boots to setup, no touch, SetupWizard crash‑loops, reboots" → mismatched/garbage `vendor`.
- Boot‑loop to bootloader → broken `super` metadata (above).
- `adb sideload` of the official OTA fails with **`ErrorCode::kInstallDeviceOpenError` (7)** →
  `update_engine` can't open the target dynamic partitions, *because the super metadata is broken*.
  (The official OTA can't repair a super whose metadata it can't even read.)

## The fix

Rebuild a **correct `super`** with `lpmake`, using the genuine Microsoft A11 logical‑partition
images and the **real geometry**, then flash it together with the genuine boot chain and a
**verity‑disabled `vbmeta`**. Authoritative geometry came from the OTA payload manifest:

```
super device size : 15032385536
metadata slots    : 2          metadata max size: 65536
group             : surface_dynamic_partitions   size 7511998464
partitions (slot a, sizes = exact image sizes):
  system_a      1124737024
  system_ext_a   215367680
  product_a     3720089600
  vendor_a      1637969920
  odm_a            1224704
```

`vbmeta` is flashed with **verification + verity disabled** (header flags `0x3`) so dm‑verity does
not trip on the rebuilt super. On an unlocked device the broken AVB signature is ignored.

---

## Files in this kit

```
flash_all.bat            One-click full flash (firmware + boot chain + super + wipe). USE THIS.
super_built.img          The corrected, WORKING super (lpmake, genuine A11 content). ~6.7 GB sparse.
fastboot.exe + *.dll     Bundled fastboot (Windows).
images/                  Genuine MS A11 (2022.521.8) partition images, extracted from the OTA payload:
   boot dtbo vendor_boot vm-bootsys        (slot-a boot chain)
   vbmeta_system  vbmeta                   (stock AVB)
   vbmeta_disabled.img                     (vbmeta with verity+verification OFF — flashed to vbmeta_a)
   abl aop bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster
   modem qupfw sfsecapp shrm tz uefisecapp xbl xbl_config   (radio/SoC firmware)
bin/                     lpmake / lpdump / lpunpack  (Linux x86-64 static; run via WSL)
build/                   How super_built.img and vbmeta_disabled.img were made (for full rebuild):
   build_super.sh        lpmake invocation that produces super_built.img
   make_vbmeta_disabled.sh   patches stock vbmeta -> verity/verification disabled
   parse_payload.py      reads geometry/partition sizes from the OTA payload.bin
   unsparse_head.py      partial sparse->raw, used to lpdump sparse supers
```

---

## Full manual procedure (what flash_all.bat does)

All commands from this folder, device in **bootloader** mode.

```bat
:: firmware -> BOTH slots (genuine A11; safe to repeat)
for %P in (abl aop bluetooth cpucp devcfg dsp featenabler hyp imagefv keymaster ^
           modem qupfw sfsecapp shrm tz uefisecapp xbl xbl_config) do (
   fastboot flash %P_a images\%P.img
   fastboot flash %P_b images\%P.img
)

:: boot chain -> slot a
fastboot flash boot_a        images\boot.img
fastboot flash dtbo_a        images\dtbo.img
fastboot flash vendor_boot_a images\vendor_boot.img
fastboot flash vm-bootsys_a  images\vm-bootsys.img

:: AVB: root vbmeta with verity OFF, system stock
fastboot flash vbmeta_a         images\vbmeta_disabled.img
fastboot flash vbmeta_system_a  images\vbmeta_system.img

:: the corrected super (single, non-slotted)
fastboot flash super super_built.img

:: clean user data (fixes downgrade FBE/SetupWizard crash-loop)
fastboot erase userdata
fastboot erase metadata

:: boot slot a
fastboot set_active a
fastboot reboot
```

### Pre‑boot sanity check (optional but recommended)
After flashing, before `reboot`, verify the device's own liblp now reads the super:
```
fastboot reboot fastboot                 ::  -> fastbootd
fastboot getvar is-logical:system_a      ::  -> yes   (was MISSING before the fix)
fastboot getvar partition-size:system_a  ::  -> 0x430A2000  (= 1124737024)
fastboot reboot
```
If `system_a` shows up as a logical partition with the right size, it will boot.

---

## Rebuilding super_built.img from scratch

You need the 5 genuine logical‑partition images. Extract them from the official OTA
(`ota_c1-11-customer_2022.521.8.zip`) with `payload-dumper`:
`system.img system_ext.img product.img vendor.img odm.img`.
Put them in `build/src/`, then (paths are /mnt/c WSL style — edit to taste):

```bash
wsl -d Ubuntu bash build/build_super.sh        # -> super_built.img  (see script for the lpmake call)
wsl -d Ubuntu bash build/make_vbmeta_disabled.sh
```

`build_super.sh` is the exact `lpmake` command, with the geometry table above baked in.

---

## Notes / gotchas

- **Only slot A is populated.** Slot B is left as‑is (unbootable). To make both slots healthy,
  flash the same boot chain to `_b` and rebuild a super that also defines `_b` partitions, or just
  take an official OTA once booted (it will populate B via snapshot).
- **`super` is NOT slotted** on this device — it's `fastboot flash super`, never `super_a`/`super_b`.
  Any script that flashes `super_a`/`super_b` (incl. the official `flashscript.txt`) is wrong here.
- **WSL**: the default distro `xWSL` was a broken WSL1 — the lp tools were run via `wsl -d Ubuntu`.
  (`C:\Users\Kake\.wslconfig` had an invalid `pageReporting=true` line that blocked WSL from
  starting; it was commented out.)
- Touch not working at setup is almost always a wrong/garbage `vendor` partition. A correct,
  genuine `super` (this kit) fixes it.
- Do **not** wipe/flash `persist` (touch & sensor calibration) or `xbl_config` unless you know why.
```
```
