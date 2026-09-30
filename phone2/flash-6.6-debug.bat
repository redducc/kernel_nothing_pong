@echo off
rem Debug flash: 6.6 boot/vendor_boot/dtbo only, then a normal boot (no fastbootd, vendor_dlkm untouched).
rem If it crashes: force into bootloader, run restore-bootloader.bat, then get-logs.bat.
cd /d "%~dp0"
fastboot flash boot boot.img || goto :err
fastboot flash vendor_boot vendor_boot.img || goto :err
fastboot flash dtbo dtbo.img || goto :err
fastboot flash vbmeta vbmeta-disabled.img || goto :err
fastboot reboot
pause
exit /b 0
:err
echo Flash failed, stopping.
pause
exit /b 1
