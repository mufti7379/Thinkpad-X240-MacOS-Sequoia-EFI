#!/bin/sh
# Perbaiki "AMFI is enabled" (OCLP root patch) di ThinkPad X240 Ventura.
# Jalankan di Terminal Ventura:  sudo sh /Volumes/INSTALLER/amfi-fix.sh
# Hasil cek disimpan ke /Volumes/INSTALLER/amfi-fix.log

KEY='NVRAM.Add.7C436110-AB2A-4BBB-A880-FE41995C9F82.boot-args'
NEW_ARGS='keepsyms=1 revpatch=sbvmm amfi=0x80'
USB_CFG='/Volumes/MACOS_X240/EFI/OC/Config.plist'
LOG='/Volumes/INSTALLER/amfi-fix.log'
[ -d /Volumes/INSTALLER ] || LOG='/tmp/amfi-fix.log'

if [ "$(id -u)" != "0" ]; then
  echo "!! Jalankan dengan sudo:  sudo sh $0"
  exit 1
fi

check_cfg() {
  cfg="$1"
  echo "   Config : $cfg"
  echo "   boot-args di config: $(plutil -extract "$KEY" raw "$cfg" 2>/dev/null)"
  i=0
  found=no
  while b=$(plutil -extract "Kernel.Add.$i.BundlePath" raw "$cfg" 2>/dev/null); do
    if [ "$b" = "AMFIPass.kext" ]; then
      found=yes
      echo "   AMFIPass di config: urutan $i, Enabled=$(plutil -extract "Kernel.Add.$i.Enabled" raw "$cfg"), MinKernel=$(plutil -extract "Kernel.Add.$i.MinKernel" raw "$cfg")"
    fi
    i=$((i + 1))
  done
  [ "$found" = "yes" ] || echo "   !! AMFIPass TIDAK ADA di Kernel > Add config ini"
  kext="$(dirname "$cfg")/Kexts/AMFIPass.kext/Contents/MacOS/AMFIPass"
  if [ -f "$kext" ]; then
    echo "   File kext: $(wc -c < "$kext" | tr -d ' ') byte (harusnya 832960)"
  else
    echo "   !! File kext tidak ada: $kext"
  fi
}

set_args() {
  cfg="$1"
  cp "$cfg" "$cfg.bak-amfi" || { echo "   !! Gagal backup $cfg"; return 1; }
  plutil -replace "$KEY" -string "$NEW_ARGS" "$cfg" || { echo "   !! Gagal mengubah $cfg"; return 1; }
  plutil -lint "$cfg" >/dev/null || { echo "   !! Config rusak, dikembalikan dari backup"; cp "$cfg.bak-amfi" "$cfg"; return 1; }
  echo "   OK: $(plutil -extract "$KEY" raw "$cfg")  (backup: $cfg.bak-amfi)"
}

main() {
  echo "== 1. Status sekarang ($(date))"
  echo "   boot-args aktif: $(nvram boot-args 2>/dev/null | cut -f2-)"
  echo "   OpenCore: $(nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null | cut -f2-)"
  LOADED="$(kmutil showloaded --list-only 2>/dev/null | grep -v com.apple)"
  echo "   Kext non-Apple yang termuat:"
  echo "$LOADED" | sed 's/^/     /'

  echo "== 2. Cari partisi EFI di SSD"
  ESP=$(diskutil list internal physical | awk '/ EFI EFI /{print $NF; exit}')
  [ -z "$ESP" ] && ESP=$(diskutil list physical | awk '/ EFI EFI /{print $NF; exit}')
  ESP_CFG=""
  if [ -n "$ESP" ]; then
    diskutil mount "$ESP" >/dev/null 2>&1
    MP=$(diskutil info "$ESP" | awk -F': *' '/Mount Point/{print $2}')
    echo "   $ESP terpasang di: ${MP:-(gagal dipasang)}"
    [ -n "$MP" ] && [ -f "$MP/EFI/OC/Config.plist" ] && ESP_CFG="$MP/EFI/OC/Config.plist"
    [ -z "$ESP_CFG" ] && echo "   (EFI OpenCore belum ada di SSD)"
  else
    echo "   (partisi EFI SSD tidak ditemukan)"
  fi

  echo "== 3. Cek AMFIPass di setiap EFI"
  for cfg in "$USB_CFG" "$ESP_CFG"; do
    [ -n "$cfg" ] && [ -f "$cfg" ] && check_cfg "$cfg"
  done

  if echo "$LOADED" | grep -q 'com.dhinakg.AMFIPass'; then
    echo "== 4. AMFIPass SUDAH termuat. Tidak ada yang diubah."
    echo "   Tutup lalu buka lagi OpenCore-Patcher dan coba Root Patch."
    return 0
  fi

  echo "== 4. AMFIPass tidak termuat -> tambahkan amfi=0x80 ke config"
  for cfg in "$USB_CFG" "$ESP_CFG"; do
    [ -n "$cfg" ] && [ -f "$cfg" ] && set_args "$cfg"
  done

  echo "== 5. Selesai"
  echo "   1) Restart (boot lewat EFI yang sama seperti tadi)"
  echo "   2) Cek: nvram boot-args   -> harus ada amfi=0x80"
  echo "   3) Buka OpenCore-Patcher > Post-Install Root Patch > Start Root Patching"
  echo "   Log tersimpan di: $LOG"
}

main 2>&1 | tee "$LOG"
