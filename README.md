<img width="1280" height="720" alt="mac-os-sequioa" src="https://github.com/user-attachments/assets/cdc3476a-9799-477f-8daa-e8e60ececf7e" />

# ThinkPad X240 Hackintosh - macOS Sequoia (OpenCore)

EFI OpenCore, script, dan catatan memasang **macOS Sequoia 15.8.2** di **Lenovo ThinkPad X240** (Core i5-4300U, Intel HD 4400), lewat upgrade dari Ventura, lalu root patch grafis dengan OpenCore Legacy Patcher (OCLP).

> Hasil ini dari satu unit X240 (November 2026). Hasil di unit lain bisa berbeda, dan pemasangan bersih Sequoia belum diuji. Selalu backup data sebelum mulai.

## Isi repo

```
EFI/       Folder EFI OpenCore (serial SMBIOS diganti nilai contoh)
scripts/   Script instalasi, perbaikan EFI, dan diagnosa
```

Sebelum dipakai, isi serial sendiri (bagian 3.5). Layout audio di repo ini 15, dan `boot-args` masih memuat `-v debug=0x100` untuk melihat pesan panic.

## Masalah yang masih ada

- **Bluetooth dimatikan:** rilis terakhir `IntelBTPatcher` (v2.4.0, Februari 2024) membuat panic di Sequoia (bagian 8).
- **Panas:** pada unit ini CPU mencapai 94-98 C dalam 5 detik saat dibebani (bagian 9).
- **Mode hemat daya CPU** hanya sampai C2, penyebabnya belum diketahui.

## Peringatan

- Di OCLP **jangan pilih "Build and Install OpenCore"**, cukup **Post-Install Root Patch**.
- Update macOS menghapus root patch. Jalankan ulang setelah update.
- Tahoe (macOS 26) belum diuji di EFI ini.
- Jangan unggah serial SMBIOS pribadi ke GitHub.

## 1. Ringkasan

| Bagian | Isi |
|---|---|
| Laptop | Lenovo ThinkPad X240, Core i5-4300U, Intel HD Graphics 4400, RAM 8 GB |
| macOS | Sequoia 15.8.2 (24H232) |
| Bootloader | OpenCore 1.0.8 (build DEBUG) |
| SMBIOS | MacBookPro16,3 |
| Root patch | OCLP 2.5.1 |

## 2. Status

| Fitur | Status |
|---|---|
| Sequoia 15.8.2 | Berjalan |
| Grafis HD 4400 | Berjalan: VRAM 1536 MB, Metal 2 |
| Audio speaker | Layout 12: suara keras |
| Audio jack headset | Layout 15: bersuara, output dipilih manual. Dengung di layout 12 belum diteliti |
| Wi-Fi | `itlwm` dan HeliPort berjalan. Tidak ada ikon Wi-Fi bawaan |
| Webcam | Terdeteksi di port USB 8 |
| Bluetooth | Dimatikan, lihat bagian 8 |
| Keyboard dan trackpad | Kext VoodooPS2 termuat |
| Sleep/wake | Belum diuji |

## 3. Konfigurasi EFI

### 3.1 Kext

| Kext | Versi | Keterangan |
|---|---|---|
| Lilu | 1.7.2 | Wajib minimal 1.6.8 agar AMFIPass termuat |
| AMFIPass | 1.4.1 | Untuk root patch OCLP |
| VirtualSMC, SMCProcessor, SMCSuperIO | 1.3.8 | Emulasi SMC dan sensor |
| WhateverGreen | 1.7.1 | Grafis |
| AppleALC | 1.9.8 | Audio ALC292 |
| AirportItlwm | 2.3.0 (build Ventura) | Wi-Fi, hanya kernel 22.x |
| itlwm | 2.3.0 | Wi-Fi Sequoia, hanya kernel 24.x, perlu HeliPort |
| IntelBluetoothFirmware | 2.4.0 | Firmware Bluetooth |
| BlueToolFixup | 2.7.2 | Bluetooth macOS 12 ke atas |
| IntelBTPatcher | 2.4.0 | **Dimatikan**, membuat panic di Sequoia |
| IntelMausi | 1.0.8 | Ethernet |
| VoodooPS2Controller | 2.3.7 | Keyboard dan trackpad |
| ACPIBatteryManager | 1.90.1 | Baterai |
| YogaSMC | 1.5.3 | Fitur ThinkPad |
| RestrictEvents | 1.1.6 | Dipakai bersama `revpatch=sbvmm` |
| CpuTscSync, FeatureUnlock, HibernationFixup | 1.1.2 / 1.1.8 / 1.5.4 | Pendukung |
| USBMap | 1.1 | 12 port, model MacBookPro16,3 |

### 3.2 Boot-args

| Argumen | Fungsi |
|---|---|
| `-v keepsyms=1 debug=0x100` | Menampilkan teks boot dan menahan layar saat panic. Bisa dilepas kalau sudah stabil |
| `revpatch=sbvmm` | Dibaca RestrictEvents, membantu installer dan update |
| `-no_compat_check` | Melewati cek model. Dipasang saat masih MacBookPro14,1 |
| `amfi=0x80` | Melonggarkan AMFI untuk root patch. Sekarang AMFIPass juga termuat, jadi bisa dicoba dilepas |
| `ipc_control_port_options=0` | Mencegah sebagian aplikasi crash saat AMFI dilonggarkan |
| `-lilubetaall` | Mengizinkan kext Lilu lama berjalan. Hati-hati, ini yang membuat IntelBTPatcher lama tetap jalan |
| `-btlfxallowanyaddr` | Melewati cek alamat Bluetooth |

### 3.3 Pengaturan lain

| Pengaturan | Nilai |
|---|---|
| `csr-active-config` | `FF0F0000` (SIP mati, dibutuhkan OCLP) |
| `SecureBootModel` | `Disabled` (dibutuhkan OCLP) |
| `XhciPortLimit` | `false` |
| NVRAM `bluetoothExternalDongleFailed` | `00` |
| NVRAM `bluetoothInternalControllerInfo` | 14 byte nol |
| iGPU `AAPL,ig-platform-id` / `device-id` | `0600260A` / `12040000` |

### 3.4 USBMap

ACPI X240 hanya membuat 6 port. USBMap di repo ini mendefinisikan semua port controller Lynx Point-LP (`0x9c31`):

| Port | Fungsi |
|---|---|
| 1, 2 | Port luar (jalur USB 2.0) |
| 7 | Bluetooth Intel (`8087:07dc`) |
| 8 | Webcam (`5986:0268`) |
| 10, 11 | Port luar (jalur USB 3.0) |
| 3-6, 12, 13 | Kosong pada unit ini, ditandai internal |

Nilai `model` di USBMap harus sama dengan SMBIOS.

### 3.5 Serial SMBIOS

Serial di repo ini nilai contoh. Buat sendiri untuk `MacBookPro16,3` dengan GenSMBIOS atau `macserial`, lalu isi `SystemSerialNumber`, `MLB`, `SystemUUID`, dan `ROM`. Jangan membagikan serial pribadi.

## 4. Menyiapkan flashdisk

Flashdisk 16 GB, GPT, dua partisi:

| Partisi | Format | Label | Isi |
|---|---|---|---|
| 1 | FAT32, 1 GB | `MACOS_X240` | `EFI/` dan `com.apple.recovery.boot/` |
| 2 | exFAT, sisa | `INSTALLER` | Script, HeliPort, OCLP |

Recovery Ventura diunduh dengan `macrecovery.py` dari paket OpenCore:

```
python macrecovery.py -b Mac-4B682C642B45593E -m 00000000000000000 download
```

## 5. Upgrade dari Ventura ke Sequoia

1. Backup data. Time Machine menyimpan data, sedangkan `InstallAssistant` hanya menyimpan installer.
2. Pastikan EFI di SSD sudah versi Sequoia:

   ```
   sudo sh /Volumes/INSTALLER/sync-efi.sh
   ```

3. Dapatkan `Install macOS Sequoia.app` (lewat App Store, atau script berikut yang juga mengecek EFI dan isi installer):

   ```
   sh /Volumes/INSTALLER/upgrade-sequoia.sh
   ```

4. Jalankan installer, pilih **Macintosh HD**.
5. Setiap restart pilih **macOS Installer** sampai entri itu hilang, lalu pilih **Macintosh HD**.

**Jangan mencabut flashdisk atau mematikan laptop selama tahap macOS Installer.** Layar bisa tampak diam lama. Pada unit ini upgrade pertama terpotong karena disela, sehingga installer harus dijalankan ulang dari Recovery:

```
"/Volumes/Macintosh HD - Data/Applications/Install macOS Sequoia.app/Contents/MacOS/InstallAssistant_springboard"
```

Instal offline dari Recovery: `InstallAssistant.pkg` harus disalin utuh ke `Contents/SharedSupport/SharedSupport.dmg` di dalam aplikasi installer. `scripts/install-ventura.sh` adalah contohnya untuk Ventura.

## 6. Setelah Sequoia masuk

1. Tampilan lambat itu normal sebelum root patch.
2. Sambungkan internet. Kabel LAN paling mudah. Untuk Wi-Fi, pasang HeliPort.
3. Buka OpenCore-Patcher, pilih **Post-Install Root Patch > Start Root Patching**, lalu restart. **Jangan pilih "Build and Install OpenCore".**
4. Cek hasilnya:

   ```
   system_profiler SPDisplaysDataType | grep -iE "chipset|vram|metal"
   ```

   Pada unit ini hasilnya VRAM 1536 MB dan Metal 2.

Update macOS menghapus root patch, jadi jalankan ulang setelah update.

## 7. Audio

| Layout | Untuk (menurut AppleALC) | Hasil pada unit ini |
|---|---|---|
| 12 | Custom ALC292 | Speaker keras. Dengung di jack belum diteliti |
| 15 | X240 / T450 (ManualMode) | Speaker pelan. Jack bersuara, output dipilih manual |
| 28 | T440 | Tidak ada suara |

Ganti layout dengan:

```
sudo sh /Volumes/INSTALLER/audio-layout.sh 12
```

Di layout 15, pilih **Headphones** sendiri di **System Settings > Sound > Output**.

## 8. Bluetooth

`IntelBTPatcher` 2.4.0 membuat panic di Sequoia. Backtrace-nya:

```
bluetoothd
IOUSBHostDevice::deviceRequest
CIntelBTPatcher::newHostDeviceRequest
IOMemoryDescriptor::readBytes -> panic
```

Dukungan Sequoia baru masuk ke kode sumber resmi pada Juni dan September 2024, setelah rilis terakhir (v2.4.0, Februari 2024). Masalah serupa dilaporkan di issue #486 repo IntelBluetoothFirmware. Bluetooth belum diuji dengan build yang lebih baru.

Kalau panic ini terjadi, matikan `IntelBTPatcher` di EFI yang benar-benar dipakai boot. Di ThinkPad, menu OpenCore dari flashdisk dan SSD terlihat sama. `scripts/fix-ssd-efi.sh` menyalin EFI flashdisk ke SSD lewat Recovery.

## 9. Panas dan CPU

Hasil `scripts/cpu-pm3.sh` pada unit ini:

| Kondisi | Suhu | Daya | Kecepatan |
|---|---|---|---|
| Diam | 66 C | 3,3 W | 1,4 GHz |
| Beban, detik ke-5 | 96 C | 12,3 W | 2,0 GHz |
| Beban, detik ke-40 | 96 C | 9,6 W | 1,7 GHz |

Batas kecepatan di macOS sudah benar (0,8-2,9 GHz). Dugaan terbesarnya pasta termal dan debu pada laptop lama, tapi belum dibuktikan dengan pembersihan. CPU juga hanya masuk mode hemat daya sampai C2, penyebabnya belum diketahui.

Setelah upgrade, Spotlight mengindeks ulang disk selama beberapa jam, jadi wajar kalau kipas bising dulu.

## 10. Script

| Script | Fungsi | Dijalankan di |
|---|---|---|
| `upgrade-sequoia.sh` | Cek syarat, unduh, dan buka installer | macOS |
| `install-ventura.sh` | Instal Ventura offline | Recovery |
| `sync-efi.sh` | Salin EFI flashdisk ke SSD | macOS |
| `fix-ssd-efi.sh` | Salin EFI flashdisk ke SSD | Recovery |
| `audio-layout.sh` | Ganti layout audio | macOS |
| `amfi-fix.sh` | Cek AMFIPass dan tambah `amfi=0x80` | macOS |
| `remove-igfxvesa.sh` | Lepas `-igfxvesa` setelah root patch | macOS |
| `usb-diag.sh` | Diagnosa port USB dan Bluetooth | macOS |
| `cpu-diag.sh`, `cpu-pm.sh`, `cpu-pm2.sh`, `cpu-pm3.sh` | Diagnosa CPU, daya, dan suhu | macOS |
| `recovery-logs.sh`, `recovery-data.sh`, `recovery-prev.sh` | Ambil log dari SSD | Recovery |

Script memakai flashdisk berlabel `MACOS_X240` dan `INSTALLER`. Sebagian script hanya diuji dengan data tiruan, jadi baca isinya dulu sebelum dijalankan.

## 11. Pemecahan masalah

| Gejala | Penyebab | Solusi |
|---|---|---|
| Panic menyebut `IntelBTPatcher`, proses `bluetoothd` | Kext lama di Sequoia | Matikan `IntelBTPatcher` di EFI yang dipakai boot |
| Berhenti di teks setelah upgrade | Pada unit ini ikut hilang setelah IntelBTPatcher dimatikan dan SMBIOS diganti | Ambil log dengan `recovery-logs.sh`, jangan langsung format |
| OCLP: *AMFI is enabled* | AMFIPass tidak termuat karena Lilu di bawah 1.6.8 | Perbarui Lilu, atau tambah `amfi=0x80` |
| Webcam dan Bluetooth tidak terdeteksi | ACPI hanya membuat 6 port | USBMap dengan `model` yang cocok |
| Tidak ada suara | Layout tidak cocok | `audio-layout.sh 12` |
| Jack tidak bersuara di layout 15 | ManualMode | Pilih Headphones di Sound > Output |
| *installer is damaged* | `SharedSupport.dmg` bukan pkg utuh | Salin pkg utuh |
| `fcopyfile failed` di Recovery | `cp` menyalin ke FAT atau exFAT | Pakai `tar`, seperti `fix-ssd-efi.sh` |
| CPU cepat 100% dan kipas bising | CPU kepanasan, atau Spotlight sedang mengindeks | `cpu-pm3.sh`, lalu bersihkan pendingin |

Pada unit ini boot Sequoia berhasil setelah tiga perubahan sekaligus: `IntelBTPatcher` dimatikan, SMBIOS diganti ke MacBookPro16,3, dan `-igfxvesa` dipasang sementara. Hanya IntelBTPatcher yang terbukti sebagai penyebab panic.

## 12. Kredit

- Acidanthera: OpenCore, Lilu, VirtualSMC, WhateverGreen, AppleALC, RestrictEvents.
- Dortania: OpenCore Install Guide dan OpenCore Legacy Patcher.
- OpenIntelWireless: itlwm, HeliPort, IntelBluetoothFirmware.
- dhinakg: AMFIPass.
- Pembuat repo *Thinkpad-x240-Ventura* dan *Thinkpad-X240-Sequoia-Sonoma-EFI*.



