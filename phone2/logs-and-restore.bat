@echo off
rem Phone in bootloader after a 6.6 crash. Restores 5.10 boot images, grabs the 6.6 crash log
rem from 5.10 recovery, then restores the stock vendor_dlkm through fastbootd.
cd /d "%~dp0"
fastboot flash boot stock\boot.img || goto :err
fastboot flash vendor_boot stock\vendor_boot.img || goto :err
fastboot flash dtbo stock\dtbo.img || goto :err
fastboot flash vbmeta vbmeta-disabled.img || goto :err
fastboot reboot recovery || goto :err
echo Waiting for recovery adb (if nothing happens after ~1 minute, see README / tell Claude)...
adb wait-for-recovery
adb shell ls -l /sys/fs/pstore
adb pull /sys/fs/pstore/console-ramoops-0 console-ramoops-0.txt
adb pull /sys/fs/pstore/dmesg-ramoops-0 dmesg-ramoops-0.txt
adb pull /sys/fs/pstore/pmsg-ramoops-0 pmsg-ramoops-0.txt
adb reboot fastboot
fastboot flash vendor_dlkm stock\vendor_dlkm.img || goto :err
fastboot flash vbmeta stock\vbmeta.img || goto :err
fastboot reboot
echo Done. Send console-ramoops-0.txt (and dmesg-ramoops-0.txt if it exists).
pause
exit /b 0
:err
echo Step failed, stopping.
pause
exit /b 1
