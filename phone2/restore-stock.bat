@echo off
rem Back to the 5.10 PenguinOS-celerity-20260929 kernel. Phone in bootloader.
cd /d "%~dp0stock"
fastboot flash boot boot.img || goto :err
fastboot flash vendor_boot vendor_boot.img || goto :err
fastboot flash dtbo dtbo.img || goto :err
fastboot flash vbmeta vbmeta.img || goto :err
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
