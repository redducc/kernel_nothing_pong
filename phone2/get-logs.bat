@echo off
rem Run right after 5.10 boots back up following a 6.6 crash.
cd /d "%~dp0"
adb root
adb wait-for-device
adb shell ls -l /sys/fs/pstore
adb pull /sys/fs/pstore/console-ramoops-0 console-ramoops-0.txt
adb pull /sys/fs/pstore/dmesg-ramoops-0 dmesg-ramoops-0.txt
adb pull /sys/fs/pstore/pmsg-ramoops-0 pmsg-ramoops-0.txt
adb shell cat /proc/bootloader_log > bootloader_log.txt
pause
