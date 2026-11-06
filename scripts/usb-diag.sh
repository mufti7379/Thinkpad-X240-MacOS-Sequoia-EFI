#!/bin/sh
# Kumpulkan info port USB (untuk membuat USBMap) ke flashdisk.
# Pakai di Terminal Ventura:  sh /Volumes/INSTALLER/usb-diag.sh
# Hasil: /Volumes/INSTALLER/usb-diag.log (ringkasan) dan usb-diag-full.txt (lengkap)

OUT_DIR='/Volumes/INSTALLER'
[ -d "$OUT_DIR" ] && [ -w "$OUT_DIR" ] || OUT_DIR="$HOME/Desktop"
LOG="$OUT_DIR/usb-diag.log"
FULL="$OUT_DIR/usb-diag-full.txt"

{
  echo "== Sistem ($(date))"
  echo "   Model SMBIOS : $(sysctl -n hw.model)"
  echo "   macOS        : $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
  echo "   boot-args    : $(nvram boot-args 2>/dev/null | cut -f2-)"
  echo "   Boot dari    : $(nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:boot-path 2>/dev/null | cut -f2-)"
  echo "   USBMap aktif : $(ioreg -lw0 -r -c AppleUSBXHCIPCI -d 1 | grep -c '"port-count"') (1 = ada port-count dari USBMap)"

  echo "== Controller USB (jalur IOService)"
  ioreg -p IOService -w0 -t -r -c AppleUSBXHCIPCI -d 1 | sed 's/ <class/  <class/'
  ioreg -p IOService -w0 -r -c AppleUSBEHCIPCI -d 1 2>/dev/null | grep -q . && echo "   (EHCI masih aktif)" || echo "   (EHCI tidak aktif)"

  echo "== Port USB dan perangkat yang tercolok"
  ioreg -lw0 -r -c AppleUSBHostPort | grep -E '\+-o |"port" = |"UsbConnector" = |"USBPortType" = |"comment" = |"locationID" = '

  echo "== Perangkat USB (bidang IOUSB)"
  ioreg -p IOUSB -w0 | sed 's/<class.*//'

  echo "== Bluetooth menurut macOS"
  system_profiler SPBluetoothDataType 2>/dev/null | grep -iE 'state|chipset|vendor|firmware|transport|address|product' | sed 's/^ */   /' | head -12

  echo "== Kext USB/Bluetooth yang termuat"
  kmutil showloaded --list-only 2>/dev/null | grep -iE 'usb|zxystd|bluetool|BTPatcher' | awk '{print "   " $6, $7}'
} > "$LOG" 2>&1

{
  echo "##### ioreg -lw0 -r -c AppleUSBHostPort"
  ioreg -lw0 -r -c AppleUSBHostPort
  echo "##### ioreg -lw0 -p IOService -t -r -c AppleUSBXHCIPCI -d 1"
  ioreg -lw0 -p IOService -t -r -c AppleUSBXHCIPCI -d 1
  echo "##### system_profiler SPUSBDataType"
  system_profiler SPUSBDataType
} > "$FULL" 2>&1

cat "$LOG"
echo
echo "Tersimpan: $LOG"
echo "           $FULL"
echo "Colok flashdisk ke PC supaya bisa dibaca."
