#!/bin/sh
# Periksa isi volume data SSD. Hanya membaca, tidak mengubah apa pun.
# Pakai di Terminal Recovery:  sh /Volumes/INSTALLER/recovery-data.sh
# Hasil: /Volumes/INSTALLER/recovery-logs/data.txt (butuh beberapa menit)

OUT='/Volumes/INSTALLER/recovery-logs'
SYS='/Volumes/Macintosh HD'
DATA='/Volumes/Macintosh HD - Data'
FILE="$OUT/data.txt"

[ -d /Volumes/INSTALLER ] || { echo "!! Flashdisk INSTALLER tidak terbaca. Cek: ls /Volumes"; exit 1; }
mkdir -p "$OUT" || { echo "!! Tidak bisa menulis ke flashdisk"; exit 1; }
[ -d "$SYS" ] || diskutil mount readOnly "Macintosh HD" >/dev/null 2>&1
[ -d "$DATA" ] || diskutil mount readOnly "Macintosh HD - Data" >/dev/null 2>&1
[ -d "$DATA" ] || { echo "!! Volume data tidak terpasang"; exit 1; }

echo "Memeriksa, tunggu beberapa menit..."
{
  echo "== Waktu: $(date)"
  echo "== Volume APFS"; diskutil apfs list 2>&1 | grep -E 'Container disk|Volume disk|Name:|Role|Capacity Consumed|FileVault|Snapshot Name|Sealed' | cut -c1-100
  echo "== Isi akar volume data"; ls -la "$DATA" 2>&1
  echo "== Library"; ls -la "$DATA/Library" 2>&1 | head -60
  echo "== Library/Logs"; ls -la "$DATA/Library/Logs" 2>&1 | head -30
  echo "== private"; ls -la "$DATA/private" 2>&1
  echo "== private/var"; ls -la "$DATA/private/var" 2>&1 | head -50
  echo "== private/var/log"; ls -lat "$DATA/private/var/log" 2>&1 | head -25
  echo "== private/var/db (penanda)"; ls -la "$DATA/private/var/db" 2>&1 | grep -E '^total|Apple|Setup|Upgrade|diagnostics|uuidtext' | head -20
  echo "== Users"; ls -la "$DATA/Users" 2>&1
  for u in "$DATA"/Users/*; do
    case "$(basename "$u")" in Shared|'*') continue ;; esac
    echo "== Isi $(basename "$u")"; ls -la "$u" 2>&1 | head -30
    echo "-- Ukuran folder"
    for d in Desktop Documents Downloads Pictures Movies Music; do
      [ -d "$u/$d" ] && du -sh "$u/$d" 2>/dev/null
    done
  done
  echo "== Applications"; ls "$DATA/Applications" 2>&1 | head -40
  echo "== Lokasi penanda (kedalaman 6)"
  find -x "$DATA" -maxdepth 6 \( -name 'DiagnosticReports' -o -name '.AppleSetupDone' -o -name '.AppleUpgrade' -o -name 'Relocated Items' -o -name 'install.log' -o -name 'system.log' -o -name 'Previous*' \) 2>/dev/null | head -30
  echo "== File yang berubah 12 jam terakhir (bukan folder user, maks 80)"
  find -x "$DATA" -type f -mmin -720 -not -path "$DATA/Users/*" 2>/dev/null | head -80
  echo "== Selesai"
} > "$FILE" 2>&1

cut -c1-110 "$FILE" | sed -n '/== Isi akar/,/== Library$/p;/== Users/,/== Applications/p' | head -60
echo
echo "Tersimpan di $FILE"
echo "Matikan laptop, colok flashdisk ke PC, lalu kabari."
