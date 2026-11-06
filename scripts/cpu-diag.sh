#!/bin/sh
# Cek penyebab CPU tinggi di macOS. Hanya membaca, tidak mengubah apa pun.
# Pakai di Terminal (tanpa sudo):  sh /Volumes/INSTALLER/cpu-diag.sh
# Hasil: /Volumes/INSTALLER/cpu-diag.log (atau Desktop kalau flashdisk tidak ada). Butuh sekitar 1 menit.

OUT_DIR='/Volumes/INSTALLER'
[ -d "$OUT_DIR" ] && [ -w "$OUT_DIR" ] || OUT_DIR="$HOME/Desktop"
LOG="$OUT_DIR/cpu-diag.log"

echo "Mengambil data, tunggu sekitar 1 menit..."
{
  echo "== Sistem ($(date))"
  echo "   macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion)) | model: $(sysctl -n hw.model)"
  echo "   CPU  : $(sysctl -n machdep.cpu.brand_string) | inti: $(sysctl -n hw.logicalcpu)"
  echo "   Uptime:$(uptime)"
  echo "   boot-args: $(nvram boot-args 2>/dev/null | cut -f2-)"

  echo "== Grafis"
  system_profiler SPDisplaysDataType 2>/dev/null | grep -iE 'chipset|vram|metal' | sed 's/^ */   /'

  echo "== Proses paling boros CPU (3 sampel, jeda 15 detik)"
  for i in 1 2 3; do
    echo "-- sampel $i: $(date '+%H:%M:%S')"
    top -l 2 -s 3 -o cpu -n 12 -stats pid,command,cpu,time,state 2>/dev/null | awk '/^PID/{n++} n==2' | head -13
    [ "$i" = "3" ] || sleep 15
  done

  echo "== Beban CPU keseluruhan"
  top -l 2 -s 3 -n 0 2>/dev/null | grep -E '^CPU usage|^Load Avg|^Processes' | tail -3

  echo "== Spotlight (indexing normal setelah upgrade)"
  mdutil -s / 2>&1 | sed 's/^/   /'
  ps -Ao %cpu,etime,comm 2>/dev/null | grep -E 'mds|mdworker|mdbulkimport|photoanalysisd|mediaanalysisd|suggestd|cloudd|bird' | sort -nr | head -10

  echo "== Suhu dan pembatasan CPU"
  pmset -g therm 2>&1 | sed 's/^/   /'

  echo "== Crash report 24 jam terakhir"
  find /Library/Logs/DiagnosticReports "$HOME/Library/Logs/DiagnosticReports" -type f -mmin -1440 2>/dev/null | sed 's#.*/##' | sed -E 's/[-_][0-9]{4}-[0-9]{2}-[0-9]{2}.*//' | sort | uniq -c | sort -nr | head -15

  echo "== Layanan yang keluar berulang (10 menit terakhir)"
  log show --last 10m --style compact --predicate 'process == "launchd" AND eventMessage CONTAINS "exited"' 2>/dev/null \
    | grep -oE '[a-zA-Z0-9.]+\.[a-zA-Z0-9.-]+ \[[0-9]+\]' | sed -E 's/ \[[0-9]+\]//' | sort | uniq -c | sort -nr | head -15

  echo "== Kext non-Apple"
  kmutil showloaded --list-only 2>/dev/null | grep -v com.apple | awk '{print "   " $6, $7}'
  echo "== Selesai"
} > "$LOG" 2>&1

sed -n '/== Proses paling boros/,/== Spotlight/p' "$LOG" | cut -c1-70 | tail -18
echo
echo "Tersimpan: $LOG"
