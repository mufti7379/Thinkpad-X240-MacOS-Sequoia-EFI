#!/bin/sh
# Install macOS Ventura OFFLINE dari InstallAssistant.pkg di flashdisk INSTALLER.
# Jalankan di Terminal Recovery:  sh /Volumes/INSTALLER/install-ventura.sh

PKG="/Volumes/INSTALLER/InstallAssistant.pkg"
TARGET="/Volumes/Macintosh HD"
APP="$TARGET/Applications/Install macOS Ventura.app"
SS_DIR="$APP/Contents/SharedSupport"
SS_DMG="$SS_DIR/SharedSupport.dmg"

# Sama seperti postinstall Apple (link_shared_support.bash): SharedSupport.dmg
# adalah salinan UTUH InstallAssistant.pkg (installer memvalidasinya sebagai "pkgdmg").
PKG_SIZE=12205110942

fail() { echo "!! $1"; exit 1; }
size_of() { wc -c < "$1" | tr -d ' '; }

echo "== 1. Sinkron tanggal ke server waktu"
sntp -sS time.apple.com || sntp -sS id.pool.ntp.org || echo "!! Sync gagal (cek internet)"
date
[ "$(date +%Y)" -ge 2025 ] || fail "Tanggal masih salah. Atur manual, contoh: date 1031073026  (bulan tgl jam menit tahun)"

echo "== 2. Cek file dan disk"
[ -f "$PKG" ] || fail "$PKG tidak ditemukan. Cek: ls /Volumes"
[ "$(size_of "$PKG")" = "$PKG_SIZE" ] || fail "Ukuran InstallAssistant.pkg beda dari yang diharapkan ($PKG_SIZE byte). Jangan lanjut."
[ -d "$TARGET" ] || fail "Volume 'Macintosh HD' belum ada. Format SSD dulu di Disk Utility: APFS + GUID Partition Map"

if [ -d "$APP" ]; then
  echo "== 3. Aplikasi installer sudah ada di SSD, lewati"
else
  echo "== 3. Pasang aplikasi installer ke SSD"
  installer -pkg "$PKG" -target "$TARGET" || fail "installer gagal"
fi

if [ -f "$SS_DMG" ] && [ "$(size_of "$SS_DMG")" = "$PKG_SIZE" ]; then
  echo "== 4. SharedSupport.dmg sudah lengkap, lewati"
else
  echo "== 4. Salin InstallAssistant.pkg utuh jadi SharedSupport.dmg (12 GB), 10-30 menit"
  mkdir -p "$SS_DIR" || fail "Tidak bisa membuat folder SharedSupport"
  chmod 0755 "$SS_DIR"
  rm -f "$SS_DMG"
  cp "$PKG" "$SS_DMG" &
  PID=$!
  while kill -0 "$PID" 2>/dev/null; do
    sleep 20
    echo "   $(( $(size_of "$SS_DMG") / 1048576 )) / $(( PKG_SIZE / 1048576 )) MB"
  done
  wait "$PID" || fail "Gagal menyalin. Jalankan ulang script ini."
  chmod 0644 "$SS_DMG"
  chown root:wheel "$SS_DMG" 2>/dev/null
  chflags -h norestricted "$SS_DMG" 2>/dev/null
fi

echo "== 5. Verifikasi SharedSupport.dmg"
[ "$(size_of "$SS_DMG")" = "$PKG_SIZE" ] || fail "Ukuran SharedSupport.dmg salah. Jalankan ulang script ini."
[ "$(head -c 4 "$SS_DMG")" = "xar!" ] || fail "SharedSupport.dmg bukan pkg utuh. Jalankan ulang script ini."
echo "   OK: $PKG_SIZE byte, pkg utuh"

echo "== 6. Putus jaringan supaya installer tidak download lagi"
for i in $(ifconfig -l); do
  [ "$i" = "lo0" ] || ifconfig "$i" down 2>/dev/null
done

echo "== 7. Membuka Install Assistant (jangan tutup Terminal)"
if [ -x "$APP/Contents/MacOS/InstallAssistant_springboard" ]; then
  "$APP/Contents/MacOS/InstallAssistant_springboard"
else
  "$APP/Contents/MacOS/InstallAssistant"
fi
