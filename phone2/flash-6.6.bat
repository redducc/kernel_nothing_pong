@echo off
rem Phone in bootloader (adb reboot bootloader). Flashes the current slot only.
cd /d "%~dp0"
fastboot flash boot boot.img || goto :err
fastboot flash vendor_boot vendor_boot.img || goto :err
fastboot flash dtbo dtbo.img || goto :err
fastboot flash vbmeta vbmeta-disabled.img || goto :err
fastboot reboot fastboot || goto :err
fastboot flash vendor_dlkm vendor_dlkm.img || goto :err
fastboot reboot
echo Done.
pause
exit /b 0
:err
echo Flash failed, stopping.
pause
exit /b 1
