#!/bin/bash
# Build the work dir pack.sh needs from the ROM's OTA zip (the 5.10 build currently on the phone).
# usage: prepare.sh <PenguinOS-...-phone2.zip>
set -e
HERE=$(dirname "$(readlink -f "$0")")
W=${PHONE2_WORK:-$HERE/work}; B=${HOST_BIN:-~/pengi/out/host/linux-x86/bin}
OTA=$(readlink -f "$1")
rm -rf $W && mkdir -p $W/stock $W/out && cd $W
unzip -q -o "$OTA" payload.bin
$B/ota_extractor --payload payload.bin --output_dir stock \
  --partitions boot,vendor_boot,dtbo,vendor_dlkm,vbmeta,vbmeta_vendor,recovery
rm payload.bin
mkdir ub uvb vr vdlkm_stock ref
$B/unpack_bootimg --boot_img stock/boot.img --out ub --format=mkbootimg > ub/args.txt
$B/unpack_bootimg --boot_img stock/vendor_boot.img --out uvb --format=mkbootimg > uvb/args.txt
(cd vr && lz4 -dc ../uvb/vendor_ramdisk00 | cpio -idm 2>/dev/null)
$B/fsck.erofs --extract=vdlkm_stock stock/vendor_dlkm.img
# 5.10 load lists are the reference compose.py maps onto 6.6 module names
cp vr/lib/modules/modules.load ref/fs.load
cp vr/lib/modules/modules.load.recovery ref/rec.load
cp vr/lib/modules/modules.blocklist stock_blocklist_vr
cp vdlkm_stock/lib/modules/modules.blocklist stock_blocklist_vd
python3 - <<'PY'
d=bytearray(open('stock/vbmeta.img','rb').read())
assert d[:4]==b'AVB0'
d[0x78:0x7c]=(3).to_bytes(4,'big')  # HASHTREE_DISABLED | VERIFICATION_DISABLED
open('out/vbmeta-disabled.img','wb').write(d)
PY
echo "work dir ready: $W"
