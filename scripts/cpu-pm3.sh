#!/bin/sh
# Catat kecepatan, daya, dan suhu CPU selama 40 detik beban penuh. Tidak mengubah pengaturan apa pun.
# Pakai di Terminal:  sudo sh /Volumes/INSTALLER/cpu-pm3.sh sebelum
#                     sudo sh /Volumes/INSTALLER/cpu-pm3.sh sesudah
# Hasil ditambahkan ke /Volumes/INSTALLER/cpu-pm3.log

LABEL="${1:-uji}"
OUT_DIR='/Volumes/INSTALLER'
[ -d "$OUT_DIR" ] && [ -w "$OUT_DIR" ] || OUT_DIR='/Users/Shared'
LOG="$OUT_DIR/cpu-pm3.log"
[ "$(id -u)" = "0" ] || { echo "!! Jalankan dengan sudo:  sudo sh $0 $LABEL"; exit 1; }

WORKERS=""
stop_workers() {
  for p in $WORKERS; do kill "$p" 2>/dev/null; done
  WORKERS=""
}
trap stop_workers EXIT INT TERM

reading() {
  powermetrics --samplers cpu_power,smc -i 2000 -n 1 2>/dev/null \
    | grep -E 'System Average frequency|Intel energy|CPU die temperature|CPU Thermal level|Fan:' \
    | sed -E 's/System Average frequency as fraction of nominal: [0-9.]+% \(/frek /; s/\)$//; s/Intel energy model derived package power \(CPUs\+GT\+SA\): /daya /; s/CPU die temperature: /suhu /' \
    | tr '\n' '|'
  echo
}

echo "Menguji sekitar 1 menit. Kipas akan naik, itu normal."
{
  echo "=================== $LABEL ($(date))"
  echo "Daya: $(pmset -g batt 2>/dev/null | head -2 | tr '\n' ' ' | cut -c1-110)"
  echo "-- diam"
  reading
  echo "-- beban 4 thread"
  for i in 1 2 3 4; do
    yes > /dev/null &
    WORKERS="$WORKERS $!"
  done
  n=1
  while [ "$n" -le 8 ]; do
    echo "t=$((n * 5))s $(reading)"
    sleep 3
    n=$((n + 1))
  done
  stop_workers
  echo "-- 15 detik setelah beban"
  sleep 15
  reading
} >> "$LOG" 2>&1

sed -n "/=================== $LABEL/,\$p" "$LOG" | tail -14 | cut -c1-100
echo
echo "Tersimpan: $LOG"
