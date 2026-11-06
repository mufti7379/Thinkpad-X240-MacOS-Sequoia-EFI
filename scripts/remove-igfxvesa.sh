#!/bin/sh
# Lepas -igfxvesa dari boot-args EFI SSD setelah root patch OCLP selesai. EFI flashdisk tidak diubah.
# Pakai di Terminal Sequoia:  sudo sh /Volumes/INSTALLER/remove-igfxvesa.sh

KEY='NVRAM.Add.7C436110-AB2A-4BBB-A880-FE41995C9F82.boot-args'
PATCH_PLIST='/System/Library/CoreServices/OpenCore-Legacy-Patcher.plist'
BK_DIR='/Users/Shared'

fail() { echo "!! $1"; exit 1; }

[ "$(id -u)" = "0" ] || fail "Jalankan dengan sudo:  sudo sh $0"

echo "== 1. Cek root patch OCLP"
[ -f "$PATCH_PLIST" ] || fail "Root patch belum terpasang. Jalankan dulu OpenCore-Patcher > Post-Install Root Patch, lalu restart."
echo "   Root patch terpasang"

echo "== 2. Cari partisi EFI di SSD"
ESP=$(diskutil list internal physical | awk '/ EFI EFI /{print $NF; exit}')
[ -z "$ESP" ] && ESP=$(diskutil list physical | awk '/ EFI EFI /{print $NF; exit}')
[ -n "$ESP" ] || fail "Partisi EFI SSD tidak ditemukan."
diskutil mount "$ESP" >/dev/null 2>&1
MP=$(diskutil info "$ESP" | awk -F': *' '/Mount Point/{print $2}')
CFG="$MP/EFI/OC/Config.plist"
[ -n "$MP" ] && [ -f "$CFG" ] || fail "Config.plist di SSD tidak ditemukan."
echo "   $CFG"

echo "== 3. Baca boot-args"
OLD=$(plutil -extract "$KEY" raw "$CFG") || fail "Gagal membaca boot-args."
echo "   Sekarang: $OLD"
NEW=""
FOUND=0
for arg in $OLD; do
  if [ "$arg" = "-igfxvesa" ]; then
    FOUND=1
  else
    NEW="${NEW:+$NEW }$arg"
  fi
done
if [ "$FOUND" = "0" ]; then
  echo "   -igfxvesa sudah tidak ada. Tidak ada yang diubah."
  exit 0
fi

echo "== 4. Ubah config"
BK="$BK_DIR/Config-sebelum-lepas-igfxvesa-$(date +%Y%m%d-%H%M%S).plist"
cp "$CFG" "$BK" || fail "Backup gagal, config tidak diubah."
echo "   Backup: $BK"
plutil -replace "$KEY" -string "$NEW" "$CFG" || fail "Gagal mengubah config."
if ! plutil -lint "$CFG" >/dev/null; then
  cp "$BK" "$CFG"
  fail "Config rusak, dikembalikan dari backup."
fi

echo "== 5. Verifikasi"
NOW=$(plutil -extract "$KEY" raw "$CFG") || fail "Gagal membaca hasil."
if [ "$NOW" != "$NEW" ]; then
  cp "$BK" "$CFG"
  fail "Hasil tidak sesuai, dikembalikan dari backup."
fi
echo "   Baru: $NOW"
echo
echo "Selesai. Restart tanpa F12, lalu pilih Macintosh HD."
echo "Sesudah masuk desktop, cek:"
echo "  system_profiler SPDisplaysDataType | grep -iE \"chipset|vram|metal\""
echo "Kalau layar bermasalah: F12 > flashdisk > Macintosh HD."
