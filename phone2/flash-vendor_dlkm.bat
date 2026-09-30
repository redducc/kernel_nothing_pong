@echo off
rem Flash only the 6.6 vendor_dlkm. Phone in bootloader (boot/vendor_boot/dtbo/vbmeta already 6.6).
cd /d "%~dp0"
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
