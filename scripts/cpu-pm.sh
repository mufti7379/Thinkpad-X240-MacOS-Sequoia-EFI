#!/bin/sh
# Uji manajemen daya CPU: kecepatan saat diam dan saat dibebani. Tidak mengubah pengaturan apa pun.
# Pakai di Terminal:  sudo sh /Volumes/INSTALLER/cpu-pm.sh
# Tutup aplikasi lain dulu. Sambungkan charger. Butuh sekitar 1 menit, kipas bisa naik sebentar.
# Hasil: /Volumes/INSTALLER/cpu-pm.log

OUT_DIR='/Volumes/INSTALLER'
[ -d "$OUT_DIR" ] && [ -w "$OUT_DIR" ] || OUT_DIR='/Users/Shared'
LOG="$OUT_DIR/cpu-pm.log"
[ "$(id -u)" = "0" ] || { echo "!! Jalankan dengan sudo:  sudo sh $0"; exit 1; }

sample() {
  powermetrics --samplers cpu_power -i 2000 -n 3 2>/dev/null \
    | grep -E 'System Average frequency|^CPU [0-9] (average )?frequency|Package|Intel energy|CPU Average frequency|C-state|Pack' \
    | head -45
}

WORKERS=""
cleanup() {
  for p in $WORKERS; do kill "$p" 2>/dev/null; done
}
trap cleanup EXIT INT TERM

echo "Menguji, tunggu sekitar 1 menit..."
{
  echo "== Sistem ($(date))"
  echo "   $(sysctl -n machdep.cpu.brand_string) | model: $(sysctl -n hw.model) | RAM: $(( $(sysctl -n hw.memsize) / 1073741824 )) GB"
  echo "   Daya: $(pmset -g batt 2>/dev/null | head -1)"
  echo "   Uptime:$(uptime)"

  echo "== XCPM dan plugin CPU"
  echo "   machdep.xcpm.mode: $(sysctl -n machdep.xcpm.mode 2>&1)"
  echo "   X86PlatformPlugin: $(kmutil showloaded --list-only 2>/dev/null | grep -c 'com.apple.driver.X86PlatformPlugin')"
  echo "   X86PlatformShim  : $(kmutil showloaded --list-only 2>/dev/null | grep -c 'X86PlatformShim')"
  echo "   ACPI_SMC_PlatformPlugin: $(kmutil showloaded --list-only 2>/dev/null | grep -c 'ACPI_SMC_PlatformPlugin')"
  echo "   plugin-type: $(ioreg -rw0 -d1 -c AppleACPICPU 2>/dev/null | grep -m1 'plugin-type')"
  echo "   Kext CPUFriend: $(kmutil showloaded --list-only 2>/dev/null | grep -c -i 'cpufriend')"

  echo "== Pengaturan daya"
  pmset -g 2>/dev/null | sed 's/^/   /' | head -30
  pmset -g therm 2>/dev/null | sed 's/^/   /'

  echo "== Proses teratas sebelum uji"
  top -l 2 -s 2 -o cpu -n 6 -stats command,cpu 2>/dev/null | awk '/^COMMAND/{n++} n==2' | head -7

  echo "== Kecepatan saat diam"
  sample

  echo "== Kecepatan saat dibebani 4 thread"
  for i in 1 2 3 4; do
    yes > /dev/null &
    WORKERS="$WORKERS $!"
  done
  sleep 3
  sample
  cleanup
  WORKERS=""

  echo "== Kecepatan 10 detik setelah beban"
  sleep 10
  sample
  pmset -g therm 2>/dev/null | sed 's/^/   /'
  echo "== Selesai"
} > "$LOG" 2>&1

cut -c1-90 "$LOG" | sed -n '/== XCPM/,/== Pengaturan/p;/== Kecepatan/,$p' | grep -vE '^== Pengaturan' | head -60
echo
echo "Tersimpan: $LOG"
