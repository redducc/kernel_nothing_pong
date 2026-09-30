#!/bin/bash
# Compose module sets from the current 6.6 dist and pack vendor_boot + vendor_dlkm into out/ and the web folder.
set -e
HERE=$(dirname "$(readlink -f "$0")")
W=${PHONE2_WORK:-$HERE/work}; cd $W
B=${HOST_BIN:-~/pengi/out/host/linux-x86/bin}; D=${K66_DIST:-~/k66/out/nothing_pong/dist}; K=${PUBLISH_DIR:-$W/publish}; mkdir -p $K $W/out
T=${TARGET_FILES:?set TARGET_FILES to the unpacked target_files dir}; export TARGET_FILES
rm -rf sysdlkm && mkdir sysdlkm && tar xzf $D/system_dlkm_staging_archive.tar.gz -C sysdlkm
rm -rf vdlkm && cp -a vdlkm_stock vdlkm
python3 $HERE/compose.py ramdisk 2>&1 | tail -1
python3 $HERE/compose.py vendor_dlkm 2>&1 | tail -1
cp uvb/bootconfig out/bootconfig
printf 'androidboot.init_fatal_panic=true\nandroidboot.selinux=permissive\n' >> out/bootconfig
cat $D/capep.dtb $D/cape.dtb $D/cape-v2.dtb > out/dtb
(cd vr && find . | LC_ALL=C sort | cpio -o -H newc -R 0:0 2>/dev/null) | lz4 -l -12 --favor-decSpeed > out/vendor_ramdisk00
rm -f out/vendor_boot.img out/vendor_dlkm.img
$B/mkbootimg --header_version 4 --pagesize 0x00001000 --base 0x00000000 --kernel_offset 0x00008000 \
  --ramdisk_offset 0x01000000 --tags_offset 0x00000100 --dtb_offset 0x0000000001f00000 \
  --vendor_cmdline 'msm_geni_serial.con_enabled=0 ignore_loglevel printk.devkmsg=on bootconfig' --board '' \
  --dtb out/dtb --vendor_bootconfig out/bootconfig --ramdisk_type 1 --ramdisk_name '' \
  --vendor_ramdisk_fragment out/vendor_ramdisk00 --vendor_boot out/vendor_boot.img
$B/avbtool add_hash_footer --image out/vendor_boot.img --partition_size 100663296 --partition_name vendor_boot
rm out/dtb out/vendor_ramdisk00 out/bootconfig
python3 - <<'PY'
import os
lines=[l for l in open(os.environ['TARGET_FILES']+'/META/vendor_dlkm_filesystem_config.txt') if '/lib/modules/' not in l]
for f in sorted(os.listdir('vdlkm/lib/modules')): lines.append(f'vendor_dlkm/lib/modules/{f} 0 0 644 capabilities=0x0\n')
open('out/fsc.txt','w').writelines(lines)
PY
$B/mkfs.erofs -zlz4hc,9 -T 1230768000 --mount-point=vendor_dlkm --fs-config-file=out/fsc.txt \
  --file-contexts=$T/META/file_contexts.bin out/vendor_dlkm.img vdlkm >/dev/null
PATH=$B:$PATH avbtool add_hashtree_footer --image out/vendor_dlkm.img --partition_name vendor_dlkm \
  --hash_algorithm sha256 --prop com.android.build.vendor_dlkm.os_version:17
rm out/fsc.txt
rm -f out/boot.img out/dtbo.img
$B/mkbootimg --header_version 4 --os_version 17.0.0 --os_patch_level 2026-08 --kernel $D/Image \
  --ramdisk ub/ramdisk --cmdline '' -o out/boot.img
$B/avbtool add_hash_footer --image out/boot.img --partition_size 100663296 --partition_name boot \
  --prop com.android.build.boot.os_version:17
python3 ${LIBUFDT:-~/pengi/system/libufdt}/utils/src/mkdtboimg.py create out/dtbo.img --page_size=4096 \
  $D/cape-qrd-pm8010-overlay.dtbo
$B/avbtool add_hash_footer --image out/dtbo.img --partition_size 25165824 --partition_name dtbo
cp out/boot.img out/vendor_boot.img out/dtbo.img out/vendor_dlkm.img out/vbmeta-disabled.img $K/
cd $K && sha256sum *.img > SHA256SUMS && cat SHA256SUMS
