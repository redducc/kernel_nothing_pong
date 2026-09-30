#!/bin/sh
# Back to the 5.10 PenguinOS-celerity-20260929 kernel. Phone in bootloader.
set -e
cd stock
fastboot flash boot boot.img
fastboot flash vendor_boot vendor_boot.img
fastboot flash dtbo dtbo.img
fastboot flash vbmeta vbmeta.img
fastboot reboot fastboot
fastboot flash vendor_dlkm vendor_dlkm.img
fastboot reboot
