#!/bin/sh
# Phone in bootloader (adb reboot bootloader). Flashes the current slot only.
set -e
fastboot flash boot boot.img
fastboot flash vendor_boot vendor_boot.img
fastboot flash dtbo dtbo.img
fastboot flash vbmeta vbmeta-disabled.img
fastboot reboot fastboot
fastboot flash vendor_dlkm vendor_dlkm.img
fastboot reboot
