#!/bin/sh
# Siapkan upgrade Ventura -> Sequoia 15.8.2 dari dalam macOS (ThinkPad X240).
# Pakai di Terminal Ventura (tanpa sudo):  sh /Volumes/INSTALLER/upgrade-sequoia.sh
# Script berhenti sebelum instalasi dimulai: Anda yang menekan Continue di installer.

URL='https://swcdn.apple.com/content/downloads/31/10/142-50013-A_0GMSQ8FVZX/kpmee5466o6dmojjdqw34x6ckj6b332of6/InstallAssistant.pkg'
PKG_SIZE=15664531445
PKG="$HOME/Downloads/InstallAssistant-15.8.2.pkg"
APP='/Applications/Install macOS Sequoia.app'
SS_DIR="$APP/Contents/SharedSupport"
SS_DMG="$SS_DIR/SharedSupport.dmg"
MIN_FULL_BYTES=10000000000
MIN_FREE_GB=50
MIN_FREE_GB_WITH_APP=30

fail() { echo "!! $1"; exit 1; }
size_of() { wc -c < "$1" | tr -d ' '; }

[ "$(id -u)" != "0" ] || fail "Jalankan tanpa sudo:  sh $0"

echo "== 1. Cek EFI yang sedang dipakai"
ARGS=$(nvram boot-args 2>/dev/null | cut -f2-)
echo "   boot-args: $ARGS"
case "$ARGS" in
  *revpatch=sbvmm*) ;;
  *) fail "revpatch=sbvmm tidak aktif. Installer akan menolak MacBookPro14,1." ;;
esac
case "$ARGS" in
  *-no_compat_check*) ;;
  *) fail "Laptop tidak boot dengan EFI Sequoia (-no_compat_check tidak ada)." ;;
esac
kmutil showloaded --list-only 2>/dev/null | grep -q 'as.vit9696.RestrictEvents' || fail "RestrictEvents tidak termuat."

echo "== 2. Cek EFI di SSD (dipakai saat restart selama upgrade)"
ESP=$(diskutil list internal physical | awk '/ EFI EFI /{print $NF; exit}')
[ -z "$ESP" ] && ESP=$(diskutil list physical | awk '/ EFI EFI /{print $NF; exit}')
[ -n "$ESP" ] || fail "Partisi EFI SSD tidak ditemukan."
sudo diskutil mount "$ESP" >/dev/null 2>&1
MP=$(diskutil info "$ESP" | awk -F': *' '/Mount Point/{print $2}')
[ -n "$MP" ] || fail "Gagal memasang $ESP."
CFG="$MP/EFI/OC/Config.plist"
if ! grep -q 'no_compat_check' "$CFG" 2>/dev/null || [ ! -d "$MP/EFI/OC/Kexts/itlwm.kext" ]; then
  fail "EFI di SSD belum versi Sequoia. Jalankan dulu:  sudo sh /Volumes/INSTALLER/sync-efi.sh"
fi
echo "   EFI SSD sudah versi Sequoia"

echo "== 3. Cek ruang SSD"
FREE_KB=$(df -k "$HOME" | awk 'NR==2{print $4}')
FREE_GB=$((FREE_KB / 1048576))
echo "   Kosong: $FREE_GB GB"
# Installer lengkap (mis. dari App Store) tidak perlu diunduh lagi, versi 15.x apa pun.
EXISTING=0
if [ -f "$SS_DMG" ] && [ "$(size_of "$SS_DMG")" -gt "$MIN_FULL_BYTES" ]; then
  EXISTING=1
fi
if [ "$EXISTING" = "1" ]; then
  [ "$FREE_GB" -ge "$MIN_FREE_GB_WITH_APP" ] || echo "   Peringatan: ruang di bawah $MIN_FREE_GB_WITH_APP GB, installer bisa menolak."
elif [ "$FREE_GB" -lt "$MIN_FREE_GB" ] && [ ! -f "$PKG" ]; then
  fail "Ruang kurang (minimal $MIN_FREE_GB GB untuk unduh + instal). Kosongkan SSD dulu."
fi

echo "== 4. Backup"
printf '   Sudah backup Time Machine? ketik ya untuk lanjut: '
read -r ANSWER
[ "$ANSWER" = "ya" ] || fail "Dibatalkan. Backup dulu."

if [ "$EXISTING" = "1" ]; then
  echo "== 5. Installer lengkap sudah ada di Applications, lewati unduhan"
  echo "   Versi aplikasi: $(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)"
  echo "   SharedSupport.dmg: $(( $(size_of "$SS_DMG") / 1000000 )) MB"
else
  [ -d "$APP" ] && echo "   Aplikasi di Applications hanya stub (tanpa data OS lengkap), unduh versi lengkap"
  echo "== 5. Unduh Sequoia 15.8.2 dari Apple (15,7 GB, bisa dilanjutkan kalau putus)"
  if [ -f "$PKG" ] && [ "$(size_of "$PKG")" -gt "$PKG_SIZE" ]; then
    rm -f "$PKG"
  fi
  if [ ! -f "$PKG" ] || [ "$(size_of "$PKG")" != "$PKG_SIZE" ]; then
    curl -L -f -C - --retry 20 --retry-delay 10 --retry-all-errors -o "$PKG" "$URL" \
      || fail "Unduhan terputus. Jalankan ulang script ini untuk melanjutkan."
  fi
  [ "$(size_of "$PKG")" = "$PKG_SIZE" ] || fail "Ukuran file salah. Jalankan ulang script ini."

  echo "== 6. Verifikasi tanda tangan Apple"
  pkgutil --check-signature "$PKG" | grep -q 'signed Apple Software' \
    || fail "Tanda tangan Apple tidak valid. Hapus $PKG lalu ulangi."
  echo "   Tanda tangan valid"

  echo "== 7. Pasang aplikasi installer"
  sudo installer -pkg "$PKG" -target / || fail "installer gagal."

  # Installer membutuhkan pkg utuh sebagai SharedSupport.dmg (tanpa ini ia mengunduh ulang dari Apple).
  if [ ! -f "$SS_DMG" ] || [ "$(size_of "$SS_DMG")" != "$PKG_SIZE" ]; then
    echo "   SharedSupport.dmg belum ada, menyalin pkg utuh"
    sudo mkdir -p "$SS_DIR" || fail "Gagal membuat $SS_DIR."
    sudo cp "$PKG" "$SS_DMG" || fail "Gagal menyalin SharedSupport.dmg."
  fi
fi

echo "== 8. Verifikasi installer"
[ -d "$APP" ] || fail "$APP tidak ada."
if [ "$EXISTING" != "1" ]; then
  [ "$(size_of "$SS_DMG")" = "$PKG_SIZE" ] || fail "Ukuran SharedSupport.dmg salah."
  [ "$(head -c 4 "$SS_DMG")" = "xar!" ] || fail "SharedSupport.dmg bukan pkg utuh."
fi
echo "   OK: installer lengkap"

echo "== 9. Membuka installer"
open "$APP" || fail "Gagal membuka installer."
echo
echo "Pilih Macintosh HD lalu Continue. Saat restart, pilih macOS Installer di menu OpenCore."
echo "Setelah Sequoia masuk: instal HeliPort untuk Wi-Fi, lalu jalankan root patch OCLP."
