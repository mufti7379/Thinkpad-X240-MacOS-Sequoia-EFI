#!/bin/sh
# Cari asal batas kecepatan CPU. Tidak mengubah pengaturan apa pun.
# Pakai di Terminal:  sudo sh /Volumes/INSTALLER/cpu-pm2.sh
# Sambungkan charger dan tutup aplikasi lain. Butuh sekitar 1 menit.
# Hasil: /Volumes/INSTALLER/cpu-pm2.log dan folder cpu-pm2-plist

OUT_DIR='/Volumes/INSTALLER'
[ -d "$OUT_DIR" ] && [ -w "$OUT_DIR" ] || OUT_DIR='/Users/Shared'
LOG="$OUT_DIR/cpu-pm2.log"
PDIR="$OUT_DIR/cpu-pm2-plist"
RES='/System/Library/Extensions/IOPlatformPluginFamily.kext/Contents/PlugIns/X86PlatformPlugin.kext/Contents/Resources'
[ "$(id -u)" = "0" ] || { echo "!! Jalankan dengan sudo:  sudo sh $0"; exit 1; }
mkdir -p "$PDIR"

freq() {
  powermetrics --samplers cpu_power -i 2000 -n 2 2>/dev/null \
    | grep -E 'System Average frequency|Intel energy' | head -4
}

WORKERS=""
stop_workers() {
  for p in $WORKERS; do kill "$p" 2>/dev/null; done
  WORKERS=""
}
trap stop_workers EXIT INT TERM

load_test() {
  echo "== Beban $1 thread"
  i=0
  while [ "$i" -lt "$1" ]; do
    yes > /dev/null &
    WORKERS="$WORKERS $!"
    i=$((i + 1))
  done
  sleep 2
  freq
  sysctl machdep.xcpm 2>/dev/null | grep -E 'plimit|thermal_level|bootplim|tuib'
  stop_workers
  sleep 3
}

echo "Mengambil data, tunggu sekitar 1 menit..."
{
  echo "== Sistem ($(date))"
  echo "   Model: $(sysctl -n hw.model) | board-id: $(ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | awk -F'[<>"]+' '/board-id/{print $4; exit}')"
  echo "== Frekuensi menurut sistem"
  sysctl hw.cpufrequency hw.cpufrequency_min hw.cpufrequency_max hw.busfrequency machdep.tsc.frequency 2>&1 | sed 's/^/   /'
  echo "== machdep.xcpm"
  sysctl machdep.xcpm 2>&1 | sed 's/^/   /'
  echo "== Fitur CPU (turbo dan pembatas)"
  sysctl machdep.cpu.thermal machdep.cpu.features 2>/dev/null | cut -c1-300 | sed 's/^/   /'
  echo "== Daya"
  pmset -g batt 2>/dev/null | sed 's/^/   /'
  pmset -g ac 2>/dev/null | sed 's/^/   /'
  system_profiler SPPowerDataType 2>/dev/null | grep -iE 'cycle count|condition|maximum capacity|connected|wattage|charging' | sed 's/^/   /'
  echo "== Data plugin CPU (cf-frequency-data, plugin-type)"
  ioreg -lw0 2>/dev/null | grep -E '"(plugin-type|cf-frequency-data)"' | cut -c1-90 | sort -u | head -6
  echo "== Daftar plist X86PlatformPlugin"
  ls "$RES" 2>&1 | head -60
  BOARD=$(ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | awk -F'[<>"]+' '/board-id/{print $4; exit}')
  for b in "$BOARD" Mac-B4831CEBD52A0C4C; do
    [ -f "$RES/$b.plist" ] && cp "$RES/$b.plist" "$PDIR/" 2>/dev/null && echo "   disalin: $b.plist"
  done
  echo "== Beban diam"
  freq
  load_test 1
  load_test 2
  load_test 4
  echo "== Selesai"
} > "$LOG" 2>&1

grep -E '^== Beban|System Average' "$LOG" | cut -c1-80
echo
echo "Tersimpan: $LOG"
