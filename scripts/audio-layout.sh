#!/bin/sh
# Ganti layout-id audio (AppleALC, codec ALC292) di config OpenCore USB dan SSD.
# Pakai di Terminal Ventura:  sudo sh /Volumes/INSTALLER/audio-layout.sh 15
# Layout ALC292 untuk ThinkPad: 15 (X240/T450), 32 (T450s), 28 (T440)
# Hasil disimpan ke /Volumes/INSTALLER/audio-layout.log

LAYOUT="${1:-15}"
KEY='DeviceProperties.Add.PciRoot(0x0)/Pci(0x1b,0x0).layout-id'
USB_CFG='/Volumes/MACOS_X240/EFI/OC/Config.plist'
LOG='/Volumes/INSTALLER/audio-layout.log'
[ -d /Volumes/INSTALLER ] || LOG='/tmp/audio-layout.log'

case "$LAYOUT" in
  ''|*[!0-9]*) echo "!! Layout harus angka, contoh:  sudo sh $0 15"; exit 1 ;;
esac
if [ "$LAYOUT" -lt 1 ] || [ "$LAYOUT" -gt 255 ]; then
  echo "!! Layout harus antara 1 dan 255"
  exit 1
fi
if [ "$(id -u)" != "0" ]; then
  echo "!! Jalankan dengan sudo:  sudo sh $0 $LAYOUT"
  exit 1
fi

# layout-id = 4 byte little-endian [n,0,0,0]; plutil -data butuh base64.
# Dihitung langsung (tanpa NUL byte di shell): 2 karakter dari n, lalu "AAAA==".
ALPH='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
C1=$(echo "$ALPH" | cut -c $(( (LAYOUT >> 2) + 1 )))
C2=$(echo "$ALPH" | cut -c $(( ((LAYOUT & 3) << 4) + 1 )))
B64="${C1}${C2}AAAA=="
HEX=$(printf '%02x000000' "$LAYOUT")

get_layout() {
  b=$(plutil -extract "$KEY" xml1 -o - "$1" 2>/dev/null | tr -d ' \t\n' | sed -n 's:.*<data>\(.*\)</data>.*:\1:p')
  if [ -n "$b" ]; then
    echo "$b" | base64 -D 2>/dev/null | od -An -tu4 | tr -d ' '
  else
    echo "(tidak ada)"
  fi
}

set_layout() {
  cfg="$1"
  old=$(get_layout "$cfg")
  cp "$cfg" "$cfg.bak-audio" || { echo "   !! Gagal backup $cfg"; return 1; }
  plutil -replace "$KEY" -data "$B64" "$cfg" || { echo "   !! Gagal mengubah $cfg"; return 1; }
  if ! plutil -lint "$cfg" >/dev/null; then
    cp "$cfg.bak-audio" "$cfg"
    echo "   !! Config rusak, dikembalikan dari backup"
    return 1
  fi
  echo "   OK: $cfg"
  echo "       layout $old -> $(get_layout "$cfg")  (backup: $cfg.bak-audio)"
}

main() {
  echo "== 1. Status audio sekarang ($(date))"
  if kmutil showloaded --list-only 2>/dev/null | grep -q 'as.vit9696.AppleALC'; then
    echo "   AppleALC: termuat"
  else
    echo "   !! AppleALC TIDAK termuat (layout-id tidak akan berpengaruh)"
  fi
  CUR=$(ioreg -l | grep -m1 '"alc-layout-id"' | sed 's/.*<\(.*\)>.*/\1/')
  echo "   alc-layout-id aktif: ${CUR:-(tidak ada)}"
  echo "   Perangkat audio:"
  system_profiler SPAudioDataType 2>/dev/null | grep -E '^ {8}[^ ].*:$' | sed 's/^ */     /'

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

  echo "== 3. Ganti layout-id ke $LAYOUT (data $B64)"
  CHANGED=0
  for cfg in "$USB_CFG" "$ESP_CFG"; do
    [ -n "$cfg" ] && [ -f "$cfg" ] && set_layout "$cfg" && CHANGED=$((CHANGED + 1))
  done
  if [ "$CHANGED" = "0" ]; then
    echo "   !! Tidak ada config yang diubah. Pastikan flashdisk MACOS_X240 tercolok."
    return 1
  fi

  echo "== 4. Selanjutnya"
  echo "   1) Restart"
  echo "   2) Cek: ioreg -l | grep -i alc-layout-id   -> harus <$HEX>"
  echo "   3) System Settings > Sound > Output: pilih Internal Speakers, tes suara"
  echo "   Kalau belum ada suara, coba layout lain:  sudo sh $0 32"
  echo "   Log tersimpan di: $LOG"
}

main 2>&1 | tee "$LOG"
