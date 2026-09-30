@echo off
rem Restore 5.10 boot images from the bootloader only (vendor_dlkm untouched). Phone in bootloader.
cd /d "%~dp0stock"
fastboot flash boot boot.img || goto :err
fastboot flash vendor_boot vendor_boot.img || goto :err
fastboot flash dtbo dtbo.img || goto :err
fastboot flash vbmeta vbmeta.img || goto :err
fastboot reboot
echo Done.
pause
exit /b 0
:err
echo Flash failed, stopping.
pause
exit /b 1
