#!/bin/sh
# Kumpulkan status instalasi dan crash report dari SSD ke flashdisk. Hanya membaca SSD, tidak mengubah apa pun.
# Pakai di Terminal Recovery:  sh /Volumes/INSTALLER/recovery-logs.sh
# Hasil: /Volumes/INSTALLER/recovery-logs/

OUT='/Volumes/INSTALLER/recovery-logs'
SYS='/Volumes/Macintosh HD'
DATA='/Volumes/Macintosh HD - Data'

[ -d /Volumes/INSTALLER ] || { echo "!! Flashdisk INSTALLER tidak terbaca. Cek: ls /Volumes"; exit 1; }
mkdir -p "$OUT/crash" || { echo "!! Tidak bisa menulis ke flashdisk"; exit 1; }
LOG="$OUT/ringkasan.log"

[ -d "$SYS" ] || diskutil mount readOnly "Macintosh HD" >/dev/null 2>&1
[ -d "$DATA" ] || diskutil mount readOnly "Macintosh HD - Data" >/dev/null 2>&1

{
  echo "== Waktu: $(date)"
  echo "== Volume"; ls /Volumes
  echo "== Versi macOS di SSD"
  grep -A1 -E 'ProductVersion|ProductBuildVersion' "$SYS/System/Library/CoreServices/SystemVersion.plist" 2>&1 | grep -E 'string|No such'
  echo "== Sisa data instalasi (kalau ada, instalasi belum selesai)"
  ls -ld "$SYS/macOS Install Data" "$DATA/macOS Install Data" 2>&1
  echo "== Root patch OCLP"
  ls -l "$SYS/System/Library/CoreServices/OpenCore-Legacy-Patcher.plist" 2>&1
  echo "== Crash report terbaru"
  ls -lt "$DATA/Library/Logs/DiagnosticReports" 2>&1 | head -40
  echo "== Ruang disk"; df -h "$DATA" 2>&1
  echo "== Penanda upgrade dan setup"
  ls -la "$DATA/private/var/db/.AppleUpgrade" "$DATA/private/var/db/.AppleSetupDone" 2>&1
  echo "== Snapshot sistem"
  diskutil apfs listSnapshots "$SYS" 2>&1 | head -20
  echo "== Log yang berubah 12 jam terakhir (terbaru dulu)"
  find "$DATA/private/var/log" "$DATA/private/var/db/diagnostics" -type f -mmin -720 -exec ls -lt {} + 2>/dev/null | head -25
} > "$LOG" 2>&1

N=0
for f in "$DATA"/Library/Logs/DiagnosticReports/*; do
  case "$(basename "$f")" in
    *WindowServer*|*loginwindow*|*panic*|*Panic*|*Kernel*|*launchservicesd*|*UpdateBrainService*|*shutdown_stall*)
      if [ -f "$f" ] && [ "$N" -lt 30 ]; then
        cp -X "$f" "$OUT/crash/" 2>/dev/null
        [ -s "$OUT/crash/$(basename "$f")" ] && N=$((N + 1))
      fi
      ;;
  esac
done
echo "== Crash report tersalin: $N" >> "$LOG"

for f in install.log system.log; do
  [ -f "$DATA/private/var/log/$f" ] && tail -n 3000 "$DATA/private/var/log/$f" > "$OUT/$f" 2>/dev/null
done

cat "$LOG"
echo
echo "Selesai. Matikan laptop, colok flashdisk ke PC, lalu kabari."
