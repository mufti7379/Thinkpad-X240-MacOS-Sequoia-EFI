#!/bin/sh
# Samakan EFI OpenCore di SSD dengan EFI di flashdisk (USB -> SSD), dengan backup.
# Hanya folder EFI/OC dan EFI/BOOT yang diganti; folder lain di partisi EFI SSD tidak disentuh.
# Pakai di Terminal Ventura:  sudo sh /Volumes/INSTALLER/sync-efi.sh

SRC='/Volumes/MACOS_X240/EFI'

if [ "$(id -u)" != "0" ]; then
  echo "!! Jalankan dengan sudo:  sudo sh $0"
  exit 1
fi
[ -f "$SRC/OC/Config.plist" ] && [ -f "$SRC/BOOT/BOOTx64.efi" ] || { echo "!! EFI di flashdisk tidak lengkap: $SRC"; exit 1; }
plutil -lint "$SRC/OC/Config.plist" >/dev/null || { echo "!! Config.plist di flashdisk rusak, batal"; exit 1; }

echo "== 1. Cari partisi EFI di SSD"
ESP=$(diskutil list internal physical | awk '/ EFI EFI /{print $NF; exit}')
[ -z "$ESP" ] && ESP=$(diskutil list physical | awk '/ EFI EFI /{print $NF; exit}')
[ -n "$ESP" ] || { echo "!! Partisi EFI SSD tidak ditemukan"; exit 1; }
diskutil mount "$ESP" >/dev/null 2>&1
MP=$(diskutil info "$ESP" | awk -F': *' '/Mount Point/{print $2}')
[ -n "$MP" ] || { echo "!! Gagal memasang $ESP"; exit 1; }
DST="$MP/EFI"
echo "   $ESP terpasang di $MP"

echo "== 2. Backup EFI SSD"
if [ -d "$DST" ]; then
  BK="/Users/Shared/EFI-SSD-backup-$(date +%Y%m%d-%H%M%S)"
  cp -RX "$DST" "$BK" || { echo "!! Backup gagal, batal"; exit 1; }
  echo "   Backup -> $BK"
else
  mkdir -p "$DST"
  echo "   (EFI SSD belum ada, tidak perlu backup)"
fi

echo "== 3. Salin OC dan BOOT dari flashdisk ke SSD"
for dir in OC BOOT; do
  rm -rf "${DST:?}/$dir"
  cp -RX "$SRC/$dir" "$DST/$dir" || { echo "!! Gagal menyalin $dir. Kembalikan dari backup: $BK"; exit 1; }
done
rm -f "$DST/OC/"*.bak-* 2>/dev/null

echo "== 4. Verifikasi"
if cmp -s "$SRC/OC/Config.plist" "$DST/OC/Config.plist"; then
  echo "   Config.plist SSD = flashdisk"
else
  echo "!! Config.plist berbeda, cek manual"
  exit 1
fi
N_SRC=$(ls "$SRC/OC/Kexts" | grep -c '\.kext$')
N_DST=$(ls "$DST/OC/Kexts" | grep -c '\.kext$')
echo "   Kext: flashdisk $N_SRC, SSD $N_DST"
echo "   Selesai. Restart, lalu boot dari SSD (tanpa flashdisk) untuk mengetes."
