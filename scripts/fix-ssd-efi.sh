#!/bin/sh
# Salin EFI flashdisk (IntelBTPatcher mati) ke partisi EFI SSD. Khusus Terminal Recovery.
# Pakai:  sh /Volumes/INSTALLER/fix-ssd-efi.sh
# EFI SSD lama dibackup ke flashdisk sebelum diganti. Volume macOS tidak disentuh.
# Semua hasil juga tersimpan di /Volumes/INSTALLER/fix-ssd-efi.log

SRC='/Volumes/MACOS_X240/EFI'
BK_ROOT='/Volumes/INSTALLER'
LOG="$BK_ROOT/fix-ssd-efi.log"

fail() { echo "!! $1"; exit 1; }

# Bandingkan dua file memakai alat yang tersedia di Recovery.
if command -v cmp >/dev/null 2>&1; then
  TOOL=cmp
  same_file() { cmp -s "$1" "$2"; }
elif command -v md5 >/dev/null 2>&1; then
  TOOL=md5
  same_file() { [ -f "$2" ] && [ "$(md5 -q "$1")" = "$(md5 -q "$2")" ]; }
elif command -v cksum >/dev/null 2>&1; then
  TOOL=cksum
  same_file() { [ -f "$2" ] && [ "$(cksum < "$1")" = "$(cksum < "$2")" ]; }
else
  TOOL=ukuran
  same_file() { [ -f "$2" ] && [ "$(wc -c < "$1")" = "$(wc -c < "$2")" ]; }
fi

# Pastikan semua file di folder $1 ada dan isinya sama di folder $2.
same_tree() {
  LIST=$(cd "$1" && find . -type f ! -name '._*' ! -name '.DS_Store' ! -name '*.bak-*') || return 1
  [ -n "$LIST" ] || return 1
  BAD=0
  OLDIFS=$IFS
  IFS='
'
  for f in $LIST; do
    if ! same_file "$1/$f" "$2/$f"; then
      BAD=$((BAD + 1))
      [ "$BAD" -le 8 ] && echo "   beda: $f  (asal $(wc -c < "$1/$f" | tr -d ' ') byte, salinan $(wc -c < "$2/$f" 2>/dev/null | tr -d ' ') byte)"
    fi
  done
  IFS=$OLDIFS
  echo "   Diperiksa, file beda: $BAD"
  [ "$BAD" = "0" ]
}

# Salin isi folder lewat tar: hanya data file, tanpa atribut yang tidak didukung FAT.
copy_tree() {
  mkdir -p "$2" || return 1
  (cd "$1" && tar -cf - --exclude='._*' --exclude='.DS_Store' --exclude='*.bak-*' .) 2>/dev/null \
    | (cd "$2" && tar -xf -) 2>/dev/null
}

main() {
  echo "== Waktu: $(date) | alat banding: $TOOL"
  echo "== 1. Cek EFI flashdisk"
  { [ -f "$SRC/OC/Config.plist" ] && [ -f "$SRC/BOOT/BOOTx64.efi" ] && [ -f "$SRC/OC/OpenCore.efi" ]; } || fail "EFI flashdisk tidak lengkap: $SRC"
  STATE=$(awk '
    /<string>IntelBTPatcher\.kext<\/string>/ { seen = 1; next }
    seen && /<key>Enabled<\/key>/ { getline; print; exit }
  ' "$SRC/OC/Config.plist" | tr -d ' \t')
  [ "$STATE" = "<false/>" ] || fail "IntelBTPatcher di flashdisk belum mati ($STATE). Jangan lanjut, kabari dulu."
  echo "   IntelBTPatcher di flashdisk: mati"

  echo "== 2. Cari partisi EFI di SSD"
  ESP=$(diskutil list internal physical | awk '/ EFI EFI /{print $NF; exit}')
  [ -z "$ESP" ] && ESP=$(diskutil list physical | awk '/ EFI EFI /{print $NF; exit}')
  [ -n "$ESP" ] || fail "Partisi EFI SSD tidak ditemukan."
  diskutil mount "$ESP" >/dev/null 2>&1
  MP=$(diskutil info "$ESP" | awk -F': *' '/Mount Point/{print $2}')
  { [ -n "$MP" ] && [ -d "$MP" ]; } || fail "Gagal memasang $ESP."
  DST="$MP/EFI"
  mkdir -p "$DST" || fail "Tidak bisa menulis ke $DST."
  echo "   $ESP terpasang di $MP"
  rm -rf "$DST/OC.new" "$DST/BOOT.new"
  df -k "$MP" | tail -1
  ls -la "$DST"

  echo "== 3. Backup EFI SSD lama"
  BK="$BK_ROOT/backup-EFI-SSD-$(date +%Y%m%d-%H%M%S).tar"
  ITEMS=""
  [ -d "$DST/OC" ] && ITEMS="OC"
  [ -d "$DST/BOOT" ] && ITEMS="$ITEMS BOOT"
  if [ -n "$ITEMS" ]; then
    (cd "$DST" && tar -cf "$BK" $ITEMS) 2>/dev/null
    COUNT=$(tar -tf "$BK" 2>/dev/null | grep -c 'Config.plist$')
    [ "${COUNT:-0}" -ge 1 ] || fail "Backup gagal, EFI SSD tidak diubah."
    echo "   Backup: $BK"
  else
    echo "   (EFI SSD kosong, tidak perlu backup)"
  fi

  echo "== 4. Salin EFI flashdisk ke SSD"
  for dir in OC BOOT; do
    copy_tree "$SRC/$dir" "$DST/$dir.new"
    if ! same_tree "$SRC/$dir" "$DST/$dir.new"; then
      df -k "$MP" | tail -1
      rm -rf "$DST/$dir.new"
      fail "Salinan $dir tidak sama. EFI SSD lama tidak diubah."
    fi
  done
  for dir in OC BOOT; do
    rm -rf "$DST/$dir"
    mv "$DST/$dir.new" "$DST/$dir" || fail "Gagal memasang $dir. Kembalikan dari backup: $BK"
  done

  echo "== 5. Verifikasi akhir"
  same_tree "$SRC/OC" "$DST/OC" || fail "OC berbeda setelah dipasang. Jangan restart, kabari dulu."
  same_tree "$SRC/BOOT" "$DST/BOOT" || fail "BOOT berbeda setelah dipasang. Jangan restart, kabari dulu."
  echo
  echo "Selesai. Jalankan: reboot"
  echo "Lalu pilih Macintosh HD dan biarkan 30 menit. Tidak perlu F12."
}

[ -d "$BK_ROOT" ] || fail "Flashdisk INSTALLER tidak terbaca. Cek: ls /Volumes"
main 2>&1 | tee "$LOG"
