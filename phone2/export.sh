#!/bin/bash
# Export the composed 6.6 build as a prebuilt kernel dir for the ROM (KERNEL_PREBUILT_DIR layout of
# device/qcom/common/dlkm/kernel-platform.mk). Run pack.sh first so vr/ and vdlkm/ are staged.
set -e
HERE=$(dirname "$(readlink -f "$0")")
W=${PHONE2_WORK:-$HERE/work}; D=${K66_DIST:-~/k66/out/nothing_pong/dist}
O=${OUT:?set OUT to the prebuilt dir, e.g. ~/pengi/device/nothing/phone2-kernel}
BIONIC_UAPI=${BIONIC_UAPI:-~/pengi/bionic/libc/kernel/uapi}

rm -rf $O/Image $O/System.map $O/Module.symvers $O/dtbs $O/vendor_ramdisk $O/vendor_dlkm $O/kernel-headers
mkdir -p $O/dtbs $O/vendor_ramdisk $O/vendor_dlkm
cp $D/Image $D/System.map $D/Module.symvers $O/
cp $D/capep.dtb $D/cape.dtb $D/cape-v2.dtb $O/dtbs/
python3 ${LIBUFDT:-~/pengi/system/libufdt}/utils/src/mkdtboimg.py create $O/dtbs/dtbo.img --page_size=4096 \
  $D/cape-qrd-pm8010-overlay.dtbo

cp $W/vr/lib/modules/*.ko $W/vr/lib/modules/modules.load $W/vr/lib/modules/modules.load.recovery $O/vendor_ramdisk/
cp $W/vdlkm/lib/modules/*.ko $W/vdlkm/lib/modules/modules.load $W/vdlkm/lib/modules/modules.blocklist $O/vendor_dlkm/

# Board UAPI headers, processed the way kernel_platform's prepare_vendor.sh does
T=$(mktemp -d); tar xf $D/kernel-uapi-headers.tar.gz -C $T
python3 $HERE/export_headers.py $T/usr/include $BIONIC_UAPI $O/kernel-headers arm64
rm -rf $T
# Header tools the techpack UAPI header modules use, normally from the kernel source tree
K=${K66_KERNEL:-~/k66/vendor/nothing/pong-kernel}
mkdir -p $O/scripts
cp $K/Android.bp $O/Android.bp
cp $K/scripts/unifdef.c $K/scripts/headers_install.sh $O/scripts/
# Tells Build_external_kernelmodule.mk to copy these KOs instead of building techpacks
touch $O/techpack.built

echo "vendor_ramdisk $(wc -l < $O/vendor_ramdisk/modules.load)/$(wc -l < $O/vendor_ramdisk/modules.load.recovery), vendor_dlkm $(wc -l < $O/vendor_dlkm/modules.load)"
