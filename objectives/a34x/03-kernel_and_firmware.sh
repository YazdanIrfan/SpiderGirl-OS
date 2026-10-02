#!/usr/bin/env bash
# MOD_NAME="A34 5G GKI Kernel, Modules & Multi-Variant MTK Firmware"
# MOD_AUTHOR="Fede2782, ExtremeXT, Yazdan Irfan"

LOG_BEGIN "- Building A34 5G GKI Kernel, Vendor Boot & Multi-Variant Firmware"
mkdir -p "$DIROUT"

# Fix missing 'gki' Python module required by prebuilts/android-tools/mkbootimg
mkdir -p "$PREBUILTS/android-tools/gki"
: > "$PREBUILTS/android-tools/gki/__init__.py"
cat > "$PREBUILTS/android-tools/gki/generate_gki_certificate.py" << 'EOF'
def generate_gki_certificate(*args, **kwargs):
    pass
EOF
export PYTHONPATH="$PREBUILTS/android-tools:${PYTHONPATH:-}"

# 1. Patch boot.img with UN1CA GKI Kernel (Works on all A34 variants)
if [[ ! -f "$STOCK_FW/kernel/boot.img" ]]; then
    ERROR_EXIT "Missing $STOCK_FW/kernel/boot.img (Check scripts/unpack_fw.sh)"
fi

TMP_DIR=$(mktemp -d)
cp -a "$STOCK_FW/kernel/boot.img" "$TMP_DIR/boot.img"
MKBOOTIMG_ARGS=$("$PREBUILTS/android-tools/unpack_bootimg" --boot_img "$TMP_DIR/boot.img" --out "$TMP_DIR/out" --format mkbootimg 2>&1)
rm -f "$TMP_DIR/boot.img" "$TMP_DIR/out/kernel"

KERNEL_URL="https://github.com/UN1CA/kernel_samsung_a34x/releases/latest/download/Image"
KERNEL_BUILDINFO_URL="https://github.com/UN1CA/kernel_samsung_a34x/releases/latest/download/build_info.txt"

LOG_INFO "Downloading UN1CA GKI kernel image..."
curl -fLs "$KERNEL_URL" -o "$TMP_DIR/out/kernel" || ERROR_EXIT "Failed to download A34x GKI kernel"
curl -fLs "$KERNEL_BUILDINFO_URL" -o "$TMP_DIR/kernel_info.txt" || ERROR_EXIT "Failed to download kernel_info.txt"

CURRENT_SPL=$(echo "$MKBOOTIMG_ARGS" | grep -o "\-\-os_patch_level [0-9][0-9][0-9][0-9]-[0-9][0-9]" | sed 's/^--os_patch_level //')
KERNEL_SPL=$(grep 'asb_level' "$TMP_DIR/kernel_info.txt" | sed 's/^asb_level=//' | grep -o "[0-9][0-9][0-9][0-9]-[0-9][0-9]")
if [[ -n "$CURRENT_SPL" && -n "$KERNEL_SPL" ]]; then
    MKBOOTIMG_ARGS=$(echo "$MKBOOTIMG_ARGS" | sed "s/\-\-os_patch_level $CURRENT_SPL/\-\-os_patch_level $KERNEL_SPL/")
fi

gzip -n -f -9 "$TMP_DIR/out/kernel" > "$TMP_DIR/out/tmp" && mv -f "$TMP_DIR/out/tmp" "$TMP_DIR/out/kernel"
eval "python3 \"$PREBUILTS/android-tools/mkbootimg\" $MKBOOTIMG_ARGS -o \"$TMP_DIR/new-boot.img\"" || ERROR_EXIT "mkbootimg failed for boot.img"
echo -n "SEANDROIDENFORCE" >> "$TMP_DIR/new-boot.img"
mv -f "$TMP_DIR/new-boot.img" "$DIROUT/boot.img"
rm -rf "$TMP_DIR"
LOG_INFO "Repacked boot.img with UN1CA GKI kernel."

# 2. Patch vendor_boot.img with log_store.ko, smcdsd_panel.ko & first-stage fstab fixes
if [[ ! -f "$STOCK_FW/kernel/vendor_boot.img" ]]; then
    ERROR_EXIT "Missing $STOCK_FW/kernel/vendor_boot.img (Check scripts/unpack_fw.sh)"
fi

TMP_DIR=$(mktemp -d)
cp -a "$STOCK_FW/kernel/vendor_boot.img" "$TMP_DIR/vendor_boot.img"
MKBOOTIMG_ARGS=$("$PREBUILTS/android-tools/unpack_bootimg" --boot_img "$TMP_DIR/vendor_boot.img" --out "$TMP_DIR/out" --format mkbootimg 2>&1)
rm -f "$TMP_DIR/vendor_boot.img"

mkdir -p "$TMP_DIR/out/ramdisk_out"
lz4 -d < "$TMP_DIR/out/vendor_ramdisk00" | cpio --quiet -i -D "$TMP_DIR/out/ramdisk_out"
rm -f "$TMP_DIR/out/vendor_ramdisk00"

LOG_STORE_KO=$(find "$SCRPATH" -type f -name "log_store.ko" | head -n 1)
SMCDSD_PANEL_KO=$(find "$SCRPATH" -type f -name "smcdsd_panel.ko" | head -n 1)

if [[ -z "$LOG_STORE_KO" || -z "$SMCDSD_PANEL_KO" ]]; then
    ERROR_EXIT "Missing log_store.ko or smcdsd_panel.ko in objectives/a34x/modules/"
fi

cp -f "$LOG_STORE_KO" "$TMP_DIR/out/ramdisk_out/lib/modules/log_store.ko"
cp -f "$SMCDSD_PANEL_KO" "$TMP_DIR/out/ramdisk_out/lib/modules/smcdsd_panel.ko"

# Patch first-stage ramdisk fstab.mt6877 so init mounts modified super.img without AVB/encryption bootloops
find "$TMP_DIR/out/ramdisk_out" -type f -name "fstab.*" -exec sed -i \
    -e 's/,avb=vbmeta_system//g' \
    -e 's/,avb=vbmeta_vendor//g' \
    -e 's/,avb=vbmeta//g' \
    -e 's/,avb//g' \
    -e 's/,avb_keys=[^,[:space:]]*//g' \
    -e 's/,fileencryption=[^,[:space:]]*//g' \
    -e 's/,metadata_encryption=[^,[:space:]]*//g' \
    -e 's/,keydirectory=[^,[:space:]]*//g' \
    -e 's/,encryptable=[^,[:space:]]*//g' {} +

(cd "$TMP_DIR/out/ramdisk_out" && find . | LC_ALL=C sort | cpio --quiet -o -H newc) | lz4 -l -12 --favor-decSpeed > "$TMP_DIR/out/vendor_ramdisk00"
eval "python3 \"$PREBUILTS/android-tools/mkbootimg\" $MKBOOTIMG_ARGS --vendor_boot \"$TMP_DIR/vendor_boot.img\"" || ERROR_EXIT "mkbootimg failed for vendor_boot.img"
mv -f "$TMP_DIR/vendor_boot.img" "$DIROUT/vendor_boot.img"
rm -rf "$TMP_DIR"
LOG_INFO "Repacked vendor_boot.img with patched kernel modules and fstab."

# 3. Download Signed MTK Firmware & Patched VBMeta for ALL 4 Variants (A346B, A346E, A346M, A3460)
A346B_FIRMWARE_URL="https://github.com/UN1CA/proprietary_vendor_samsung_a34x/releases/download/EYI7-firmware/A346BXXUBEYI7_mtk_fw.tar.md5"
A3460_FIRMWARE_URL="https://github.com/UN1CA/proprietary_vendor_samsung_a34x/releases/download/EYI7-firmware/A3460ZHUAEYI7_mtk_fw.tar.md5"
A346E_FIRMWARE_URL="https://github.com/UN1CA/proprietary_vendor_samsung_a34x/releases/download/EYI7-firmware/A346EXXUAEYI7_mtk_fw.tar.md5"
A346M_FIRMWARE_URL="https://github.com/UN1CA/proprietary_vendor_samsung_a34x/releases/download/EYI7-firmware/A346MUBUBEYI7_mtk_fw.tar.md5"

A346B_VBMETA_URL="https://github.com/UN1CA/proprietary_vendor_samsung_a34x/releases/download/patched-vbmeta/A346BXXUBEYI7_patched_vbmeta.tar.md5"
A3460_VBMETA_URL="https://github.com/UN1CA/proprietary_vendor_samsung_a34x/releases/download/patched-vbmeta/A3460ZHUAEYI7_patched_vbmeta.tar.md5"
A346E_VBMETA_URL="https://github.com/UN1CA/proprietary_vendor_samsung_a34x/releases/download/patched-vbmeta/A346EXXUAEYI7_patched_vbmeta.tar.md5"
A346M_VBMETA_URL="https://github.com/UN1CA/proprietary_vendor_samsung_a34x/releases/download/patched-vbmeta/A346MUBUBEYI7_patched_vbmeta.tar.md5"

PARTITIONS=(
    "audio_dsp-verified.img"
    "cam_vpu1-verified.img"
    "cam_vpu2-verified.img"
    "cam_vpu3-verified.img"
    "dtbo.img"
    "scp-verified.img"
    "vbmeta.img"
)

for VARIANT in A346B A346E A346M A3460; do
    LOG_INFO "Downloading & extracting firmware + vbmeta for $VARIANT..."
    TMP_FW=$(mktemp -d)
    FW_VAR="${VARIANT}_FIRMWARE_URL"
    VB_VAR="${VARIANT}_VBMETA_URL"

    curl -fLs "${!FW_VAR}" -o "$TMP_FW/firmware.tar" || ERROR_EXIT "Failed to download firmware for $VARIANT"
    curl -fLs "${!VB_VAR}" -o "$TMP_FW/vbmeta.tar" || ERROR_EXIT "Failed to download vbmeta for $VARIANT"

    tar xf "$TMP_FW/firmware.tar" -C "$TMP_FW"
    tar xf "$TMP_FW/vbmeta.tar" -C "$TMP_FW"

    for PART in "${PARTITIONS[@]}"; do
        if [[ ! -f "$TMP_FW/$PART.lz4" ]]; then
            ERROR_EXIT "Missing $PART.lz4 in $VARIANT package"
        fi
        lz4 -d -f "$TMP_FW/$PART.lz4" "$DIROUT/${VARIANT}_${PART}" >/dev/null 2>&1
    done

    rm -rf "$TMP_FW"
done

LOG_END "All 4 Galaxy A34 variants (A346B, A346E, A346M, A3460) packed successfully."