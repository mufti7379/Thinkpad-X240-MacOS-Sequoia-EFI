#!/bin/sh
# Ambil log boot lama dari folder "Previous System" di SSD. Hanya membaca SSD.
# Pakai di Terminal Recovery:  sh /Volumes/INSTALLER/recovery-prev.sh
# Hasil: /Volumes/INSTALLER/recovery-logs/prev/

OUT='/Volumes/INSTALLER/recovery-logs/prev'
DATA='/Volumes/Macintosh HD - Data'
PREV="$DATA/Previous System"

[ -d /Volumes/INSTALLER ] || { echo "!! Flashdisk INSTALLER tidak terbaca. Cek: ls /Volumes"; exit 1; }
[ -d "$DATA" ] || diskutil mount readOnly "Macintosh HD - Data" >/dev/null 2>&1
[ -d "$DATA" ] || { echo "!! Volume data tidak terpasang"; exit 1; }
mkdir -p "$OUT/crash" || { echo "!! Tidak bisa menulis ke flashdisk"; exit 1; }
LOG="$OUT/daftar.txt"

{
  echo "== Waktu: $(date)"
  echo "== Previous System"; ls -la "$PREV" 2>&1
  echo "== Previous System/private/var/log"; ls -lat "$PREV/private/var/log" 2>&1 | head -20
  echo "== Crash report di Previous System"; ls -lat "$PREV/Library/Logs/DiagnosticReports" 2>&1 | head -30
  echo "== com.apple.installer (terbaru dulu)"; ls -lat "$DATA/com.apple.installer" 2>&1 | head -60
  echo "== MobileSoftwareUpdate"; ls -la "$DATA/MobileSoftwareUpdate" 2>&1 | head -20
  echo "== private/var/db"; ls -la "$DATA/private/var/db" 2>&1 | head -20
  echo "== Preboot"
  DEV=$(diskutil info "$DATA" 2>/dev/null | awk '/Device Identifier/{print $3}')
  BASE=${DEV%s*}
  if [ -n "$BASE" ]; then
    diskutil mount readOnly "${BASE}s2" >/dev/null 2>&1
    ls -ld /Volumes/Preboot/*/com.apple.installer 2>&1
    ls -la /Volumes/Preboot/*/ 2>&1 | head -20
  fi
} > "$LOG" 2>&1

for f in system.log install.log; do
  [ -f "$PREV/private/var/log/$f" ] && tail -n 4000 "$PREV/private/var/log/$f" > "$OUT/$f" 2>/dev/null
done

N=0
for f in "$PREV"/Library/Logs/DiagnosticReports/*; do
  case "$(basename "$f")" in
    *WindowServer*|*loginwindow*|*panic*|*Panic*|*Kernel*|*launchd*|*logd*|*shutdown_stall*)
      if [ -f "$f" ] && [ "$N" -lt 25 ]; then
        cp -X "$f" "$OUT/crash/" 2>/dev/null
        [ -s "$OUT/crash/$(basename "$f")" ] && N=$((N + 1))
      fi
      ;;
  esac
done
echo "== Crash report tersalin: $N" >> "$LOG"

C="$DATA/private/var/db/PreviousSystemLogs.cpgz"
if [ -f "$C" ]; then
  SZ=$(wc -c < "$C" | tr -d ' ')
  echo "== PreviousSystemLogs.cpgz: $SZ byte" >> "$LOG"
  [ "$SZ" -lt 400000000 ] && cp -X "$C" "$OUT/" 2>/dev/null
fi

cut -c1-100 "$LOG" | tail -12
echo
echo "Selesai. Tersimpan di $OUT"
