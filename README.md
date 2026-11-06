# ThinkPad X240 Hackintosh - macOS Sequoia (OpenCore)

OpenCore EFI, scripts, and notes for running **macOS Sequoia 15.8.2** on a **Lenovo ThinkPad X240** (Core i5-4300U, Intel HD 4400), upgraded from Ventura and root-patched for graphics with OpenCore Legacy Patcher (OCLP).

> These results come from one X240 unit (November 2026). Your results may differ, and a clean Sequoia install has not been tested. Always back up your data before you start.

## Repository contents

```
EFI/       OpenCore EFI folder (SMBIOS serials replaced with sample values)
scripts/   Scripts for installation, EFI repair, and diagnostics
```

Before using it, fill in your own serials (section 3.5). The audio layout in this repo is 15, and `boot-args` still includes `-v debug=0x100` so panic messages stay visible.

## Known problems

- **Bluetooth is disabled:** the latest `IntelBTPatcher` release (v2.4.0, February 2024) causes a kernel panic on Sequoia (section 8).
- **Heat:** on this unit the CPU reaches 94-98 C within 5 seconds under load (section 9).
- **CPU power saving** only reaches package C2. The cause is unknown.

## Warnings

- In OCLP, **do not choose "Build and Install OpenCore"**. Use **Post-Install Root Patch** only.
- macOS updates remove the root patch. Run it again after updating.
- Tahoe (macOS 26) has not been tested with this EFI.
- Do not upload your personal SMBIOS serials to GitHub.

## 1. Summary

| Item | Details |
|---|---|
| Laptop | Lenovo ThinkPad X240, Core i5-4300U, Intel HD Graphics 4400, 8 GB RAM |
| macOS | Sequoia 15.8.2 (24H232) |
| Bootloader | OpenCore 1.0.8 (DEBUG build) |
| SMBIOS | MacBookPro16,3 |
| Root patch | OCLP 2.5.1 |

## 2. Status

| Feature | Status |
|---|---|
| Sequoia 15.8.2 | Working |
| HD 4400 graphics | Working: 1536 MB VRAM, Metal 2 |
| Speaker audio | Layout 12: loud |
| Headset jack audio | Layout 15: has sound, output selected manually. Humming on layout 12 not investigated |
| Wi-Fi | `itlwm` and HeliPort running. No native Wi-Fi menu icon |
| Webcam | Detected on USB port 8 |
| Bluetooth | Disabled, see section 8 |
| Keyboard and trackpad | VoodooPS2 kexts loaded |
| Sleep/wake | Not tested |

## 3. EFI configuration

### 3.1 Kexts

| Kext | Version | Notes |
|---|---|---|
| Lilu | 1.7.2 | At least 1.6.8 is required for AMFIPass to load |
| AMFIPass | 1.4.1 | For the OCLP root patch |
| VirtualSMC, SMCProcessor, SMCSuperIO | 1.3.8 | SMC emulation and sensors |
| WhateverGreen | 1.7.1 | Graphics |
| AppleALC | 1.9.8 | ALC292 audio |
| AirportItlwm | 2.3.0 (Ventura build) | Wi-Fi, kernel 22.x only |
| itlwm | 2.3.0 | Wi-Fi on Sequoia, kernel 24.x only, requires HeliPort |
| IntelBluetoothFirmware | 2.4.0 | Bluetooth firmware |
| BlueToolFixup | 2.7.2 | Bluetooth on macOS 12 and later |
| IntelBTPatcher | 2.4.0 | **Disabled**, causes a panic on Sequoia |
| IntelMausi | 1.0.8 | Ethernet |
| VoodooPS2Controller | 2.3.7 | Keyboard and trackpad |
| ACPIBatteryManager | 1.90.1 | Battery |
| YogaSMC | 1.5.3 | ThinkPad features |
| RestrictEvents | 1.1.6 | Used with `revpatch=sbvmm` |
| CpuTscSync, FeatureUnlock, HibernationFixup | 1.1.2 / 1.1.8 / 1.5.4 | Supporting kexts |
| USBMap | 1.1 | 12 ports, model MacBookPro16,3 |

### 3.2 Boot arguments

| Argument | Purpose |
|---|---|
| `-v keepsyms=1 debug=0x100` | Shows boot text and holds the screen on a panic. Can be removed once stable |
| `revpatch=sbvmm` | Read by RestrictEvents, helps the installer and updates |
| `-no_compat_check` | Skips the model check. Added while still on MacBookPro14,1 |
| `amfi=0x80` | Relaxes AMFI for the root patch. AMFIPass now also loads, so removing this is worth trying |
| `ipc_control_port_options=0` | Prevents some apps from crashing when AMFI is relaxed |
| `-lilubetaall` | Allows older Lilu kexts to run. Be careful: this is what kept the old IntelBTPatcher running |
| `-btlfxallowanyaddr` | Skips the Bluetooth address check |

### 3.3 Other settings

| Setting | Value |
|---|---|
| `csr-active-config` | `FF0F0000` (SIP disabled, required by OCLP) |
| `SecureBootModel` | `Disabled` (required by OCLP) |
| `XhciPortLimit` | `false` |
| NVRAM `bluetoothExternalDongleFailed` | `00` |
| NVRAM `bluetoothInternalControllerInfo` | 14 zero bytes |
| iGPU `AAPL,ig-platform-id` / `device-id` | `0600260A` / `12040000` |

### 3.4 USBMap

The X240's ACPI only creates 6 ports. The USBMap in this repo defines all ports on the Lynx Point-LP controller (`0x9c31`):

| Port | Function |
|---|---|
| 1, 2 | External ports (USB 2.0 lanes) |
| 7 | Intel Bluetooth (`8087:07dc`) |
| 8 | Webcam (`5986:0268`) |
| 10, 11 | External ports (USB 3.0 lanes) |
| 3-6, 12, 13 | Empty on this unit, marked internal |

The `model` value in USBMap must match your SMBIOS.

### 3.5 SMBIOS serials

The serials in this repo are sample values. Generate your own for `MacBookPro16,3` with GenSMBIOS or `macserial`, then fill in `SystemSerialNumber`, `MLB`, `SystemUUID`, and `ROM`. Do not share your personal serials.

## 4. Preparing the USB drive

16 GB USB drive, GPT, two partitions:

| Partition | Format | Label | Contents |
|---|---|---|---|
| 1 | FAT32, 1 GB | `MACOS_X240` | `EFI/` and `com.apple.recovery.boot/` |
| 2 | exFAT, remaining space | `INSTALLER` | Scripts, HeliPort, OCLP |

Download Ventura recovery with `macrecovery.py` from the OpenCore package:

```
python macrecovery.py -b Mac-4B682C642B45593E -m 00000000000000000 download
```

## 5. Upgrading from Ventura to Sequoia

1. Back up your data. Time Machine saves your data, while `InstallAssistant` only saves the installer.
2. Make sure the EFI on the SSD is the Sequoia version:

   ```
   sudo sh /Volumes/INSTALLER/sync-efi.sh
   ```

3. Get `Install macOS Sequoia.app` from the App Store, or use this script, which also checks the EFI and the installer contents:

   ```
   sh /Volumes/INSTALLER/upgrade-sequoia.sh
   ```

4. Run the installer and select **Macintosh HD**.
5. On every restart, choose **macOS Installer** until that entry disappears, then choose **Macintosh HD**.

**Do not unplug the USB drive or power off the laptop during the macOS Installer stage.** The screen can look frozen for a long time. On this unit the first upgrade was cut short by an interruption, so the installer had to be run again from Recovery:

```
"/Volumes/Macintosh HD - Data/Applications/Install macOS Sequoia.app/Contents/MacOS/InstallAssistant_springboard"
```

For an offline install from Recovery, `InstallAssistant.pkg` must be copied whole to `Contents/SharedSupport/SharedSupport.dmg` inside the installer app. `scripts/install-ventura.sh` shows how for Ventura.

## 6. After Sequoia boots

1. A slow interface is normal before the root patch.
2. Connect to the internet. A LAN cable is easiest. For Wi-Fi, install HeliPort.
3. Open OpenCore-Patcher, choose **Post-Install Root Patch > Start Root Patching**, then restart. **Do not choose "Build and Install OpenCore".**
4. Check the result:

   ```
   system_profiler SPDisplaysDataType | grep -iE "chipset|vram|metal"
   ```

   On this unit the result is 1536 MB VRAM and Metal 2.

macOS updates remove the root patch, so run it again after updating.

## 7. Audio

| Layout | Intended for (per AppleALC) | Result on this unit |
|---|---|---|
| 12 | Custom ALC292 | Loud speakers. Humming on the jack not investigated |
| 15 | X240 / T450 (ManualMode) | Quiet speakers. Jack has sound, output selected manually |
| 28 | T440 | No sound |

Change the layout with:

```
sudo sh /Volumes/INSTALLER/audio-layout.sh 12
```

On layout 15, select **Headphones** yourself in **System Settings > Sound > Output**.

## 8. Bluetooth

`IntelBTPatcher` 2.4.0 causes a panic on Sequoia. The backtrace:

```
bluetoothd
IOUSBHostDevice::deviceRequest
CIntelBTPatcher::newHostDeviceRequest
IOMemoryDescriptor::readBytes -> panic
```

Sequoia support reached the official source code in June and September 2024, after the latest release (v2.4.0, February 2024). A similar problem is reported in issue #486 of the IntelBluetoothFirmware repo. Bluetooth has not been tested with a newer build.

If you hit this panic, disable `IntelBTPatcher` in the EFI that is actually being booted. On the ThinkPad, the OpenCore menu looks the same from the USB drive and from the SSD. `scripts/fix-ssd-efi.sh` copies the USB EFI to the SSD from Recovery.

## 9. Heat and CPU

`scripts/cpu-pm3.sh` results on this unit:

| Condition | Temperature | Power | Speed |
|---|---|---|---|
| Idle | 66 C | 3.3 W | 1.4 GHz |
| Load, 5 seconds | 96 C | 12.3 W | 2.0 GHz |
| Load, 40 seconds | 96 C | 9.6 W | 1.7 GHz |

The speed limits in macOS are correct (0.8-2.9 GHz). The most likely cause is old thermal paste and dust, but this has not been confirmed by cleaning the laptop. The CPU also only reaches package C2, and the cause is unknown.

After an upgrade, Spotlight re-indexes the disk for several hours, so a noisy fan is expected at first.

## 10. Scripts

| Script | Purpose | Run from |
|---|---|---|
| `upgrade-sequoia.sh` | Checks requirements, downloads, and opens the installer | macOS |
| `install-ventura.sh` | Installs Ventura offline | Recovery |
| `sync-efi.sh` | Copies the USB EFI to the SSD | macOS |
| `fix-ssd-efi.sh` | Copies the USB EFI to the SSD | Recovery |
| `audio-layout.sh` | Changes the audio layout | macOS |
| `amfi-fix.sh` | Checks AMFIPass and adds `amfi=0x80` | macOS |
| `remove-igfxvesa.sh` | Removes `-igfxvesa` after the root patch | macOS |
| `usb-diag.sh` | USB port and Bluetooth diagnostics | macOS |
| `cpu-diag.sh`, `cpu-pm.sh`, `cpu-pm2.sh`, `cpu-pm3.sh` | CPU, power, and temperature diagnostics | macOS |
| `recovery-logs.sh`, `recovery-data.sh`, `recovery-prev.sh` | Collect logs from the SSD | Recovery |

The scripts expect USB partitions labeled `MACOS_X240` and `INSTALLER`, and their messages are in Indonesian. Some were only tested with mock data, so read them before running.

## 11. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Panic mentions `IntelBTPatcher`, process `bluetoothd` | Old kext on Sequoia | Disable `IntelBTPatcher` in the EFI being booted |
| Stops on boot text after the upgrade | On this unit it went away after disabling IntelBTPatcher and changing SMBIOS | Collect logs with `recovery-logs.sh`, do not format right away |
| OCLP: *AMFI is enabled* | AMFIPass not loaded because Lilu is below 1.6.8 | Update Lilu, or add `amfi=0x80` |
| Webcam and Bluetooth not detected | ACPI only creates 6 ports | USBMap with a matching `model` |
| No sound | Wrong layout | `audio-layout.sh 12` |
| No sound from the jack on layout 15 | ManualMode | Select Headphones in Sound > Output |
| *installer is damaged* | `SharedSupport.dmg` is not the whole pkg | Copy the whole pkg |
| `fcopyfile failed` in Recovery | `cp` copying to FAT or exFAT | Use `tar`, as `fix-ssd-efi.sh` does |
| CPU quickly hits 100% and the fan is loud | CPU overheating, or Spotlight indexing | Run `cpu-pm3.sh`, then clean the cooling system |

On this unit Sequoia booted after three simultaneous changes: `IntelBTPatcher` disabled, SMBIOS changed to MacBookPro16,3, and `-igfxvesa` added temporarily. Only IntelBTPatcher is proven to have caused the panic.

## 12. Credits

- Acidanthera: OpenCore, Lilu, VirtualSMC, WhateverGreen, AppleALC, RestrictEvents.
- Dortania: OpenCore Install Guide and OpenCore Legacy Patcher.
- OpenIntelWireless: itlwm, HeliPort, IntelBluetoothFirmware.
- dhinakg: AMFIPass.
- The authors of the *Thinkpad-x240-Ventura* and *Thinkpad-X240-Sequoia-Sonoma-EFI* repos.
