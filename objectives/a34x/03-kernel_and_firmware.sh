#!/usr/bin/env bash
# MOD_NAME="A34 5G GKI Kernel, Modules & MTK Firmware"
# MOD_AUTHOR="Fede2782, ExtremeXT"

LOG_BEGIN "- Building A34 5G GKI Kernel, Vendor Boot & MTK Firmware"
mkdir -p "$DIROUT"

# 1. Patch boot.img with UN1CA GKI Kernel
if [[ -f "$STOCK_FW/kernel/boot.img" ]]; then
    TMP_DIR=$(mktemp -d)
    cp -a "$STOCK_FW/kernel/boot.img" "$TMP_DIR/boot.img"
    MKBOOTIMG_ARGS=$("$PREBUILTS/android-tools/unpack_bootimg" --boot_img "$TMP_DIR/boot.img" --out "$TMP_DIR/out" --format mkbootimg 2>&1)
    rm -f "$TMP_DIR/boot.img" "$TMP_DIR/out/kernel"

    KERNEL_URL="https://github.com/UN1CA/kernel_samsung_a34x/releases/latest/download/Image"
    KERNEL_BUILDINFO_URL="https://github.com/UN1CA/kernel_samsung_a34x/releases/latest/download/build_info.txt"

    curl -fLs "$KERNEL_URL" -o "$TMP_DIR/out/kernel" || ERROR_EXIT "Failed to download A34x GKI kernel"
    curl -fLs "$KERNEL_BUILDINFO_URL" -o "$TMP_DIR/kernel_info.txt" || ERROR_EXIT "Failed to download kernel_info.txt"

    CURRENT_SPL=$(echo "$MKBOOTIMG_ARGS" | grep -o "\-\-os_patch_level [0-9][0-9][0-9][0-9]-[0-9][0-9]" | sed 's/^--os_patch_level //')
    KERNEL_SPL=$(grep 'asb_level' "$TMP_DIR/kernel_info.txt" | sed 's/^asb_level=//' | grep -o "[0-9][0-9][0-9][0-9]-[0-9][0-9]")
    if [[ -n "$CURRENT_SPL" && -n "$KERNEL_SPL" ]]; then
        MKBOOTIMG_ARGS=$(echo "$MKBOOTIMG_ARGS" | sed "s/\-\-os_patch_level $CURRENT_SPL/\-\-os_patch_level $KERNEL_SPL/")
    fi

    gzip -n -f -9 "$TMP_DIR/out/kernel" > "$TMP_DIR/out/tmp" && mv -f "$TMP_DIR/out/tmp" "$TMP_DIR/out/kernel"
    eval "$PREBUILTS/android-tools/mkbootimg $MKBOOTIMG_ARGS -o \"$TMP_DIR/new-boot.img\""
    echo -n "SEANDROIDENFORCE" >> "$TMP_DIR/new-boot.img"
    mv -f "$TMP_DIR/new-boot.img" "$DIROUT/boot.img"
    rm -rf "$TMP_DIR"
    LOG_INFO "Repacked boot.img with UN1CA GKI kernel."
else
    ERROR_EXIT "Missing $STOCK_FW/kernel/boot.img"
fi

# 2. Patch vendor_boot.img with log_store.ko & smcdsd_panel.ko
if [[ -f "$STOCK_FW/kernel/vendor_boot.img" ]]; then
    TMP_DIR=$(mktemp -d)
    cp -a "$STOCK_FW/kernel/vendor_boot.img" "$TMP_DIR/vendor_boot.img"
    MKBOOTIMG_ARGS=$("$PREBUILTS/android-tools/unpack_bootimg" --boot_img "$TMP_DIR/vendor_boot.img" --out "$TMP_DIR/out" --format mkbootimg 2>&1)
    rm -f "$TMP_DIR/vendor_boot.img"

    mkdir -p "$TMP_DIR/out/ramdisk_out"
    lz4 -d < "$TMP_DIR/out/vendor_ramdisk00" | cpio --quiet -i -D "$TMP_DIR/out/ramdisk_out"
    rm -f "$TMP_DIR/out/vendor_ramdisk00"

    cp -f "$SCRPATH/modules/log_store.ko" "$TMP_DIR/out/ramdisk_out/lib/modules/log_store.ko"
    cp -f "$SCRPATH/modules/smcdsd_panel.ko" "$TMP_DIR/out/ramdisk_out/lib/modules/smcdsd_panel.ko"

    "$PREBUILTS/android-tools/mkbootfs" "$TMP_DIR/out/ramdisk_out" | lz4 -l -12 --favor-decSpeed > "$TMP_DIR/out/vendor_ramdisk00"
    eval "$PREBUILTS/android-tools/mkbootimg $MKBOOTIMG_ARGS --vendor_boot \"$TMP_DIR/vendor_boot.img\""
    mv -f "$TMP_DIR/vendor_boot.img" "$DIROUT/vendor_boot.img"
    rm -rf "$TMP_DIR"
    LOG_INFO "Repacked vendor_boot.img with patched kernel modules."
else
    ERROR_EXIT "Missing $STOCK_FW/kernel/vendor_boot.img"
fi

# 3. Download Signed MTK Firmware & Patched VBMeta (SM-A346B)
TMP_FW=$(mktemp -d)
FW_URL="https://github.com/UN1CA/proprietary_vendor_samsung_a34x/releases/download/EYI7-firmware/A346BXXUBEYI7_mtk_fw.tar.md5"
VB_URL="https://github.com/UN1CA/proprietary_vendor_samsung_a34x/releases/download/patched-vbmeta/A346BXXUBEYI7_patched_vbmeta.tar.md5"

curl -fLs "$FW_URL" -o "$TMP_FW/firmware.tar" && tar xf "$TMP_FW/firmware.tar" -C "$TMP_FW"
curl -fLs "$VB_URL" -o "$TMP_FW/vbmeta.tar" && tar xf "$TMP_FW/vbmeta.tar" -C "$TMP_FW"

for PART in cam_vpu1-verified.img cam_vpu2-verified.img cam_vpu3-verified.img dtbo.img vbmeta.img; do
    if [[ -f "$TMP_FW/$PART.lz4" ]]; then
        lz4 -d -f "$TMP_FW/$PART.lz4" "$DIROUT/$PART" >/dev/null 2>&1
    fi
done
rm -rf "$TMP_FW"
LOG_END