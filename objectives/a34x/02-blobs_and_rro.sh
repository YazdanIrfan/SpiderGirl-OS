#!/usr/bin/env bash
# MOD_NAME="A34 5G Stock Blobs, DLKM, RRO & Astro Fixes"
# MOD_AUTHOR="Salvo Giangreco, Yazdan Irfan"

LOG_BEGIN "- Replacing RRO overlay with stock A34 RRO"
if compgen -G "$STOCK_FW/product/overlay/framework-res*.apk" > /dev/null; then
    cp -af --remove-destination "$STOCK_FW/product/overlay"/framework-res*.apk "$WORKSPACE/product/overlay/"
fi
LOG_END

LOG_BEGIN "- Applying A34 Debloat & RISC-V Hotword Blobs"
REMOVE "system" "app/WifiRROverlayAppLls"
ADD_FROM_FW "stock" "product" "priv-app/HotwordEnrollmentOKGoogleEx4RISCV"
ADD_FROM_FW "stock" "product" "priv-app/HotwordEnrollmentXGoogleEx4RISCV"
LOG_END

LOG_BEGIN "- Fixing Photo Remaster (libmidas_core.camera.samsung.so)"
PLAT_PROP_CTX="$WORKSPACE/system/system/etc/selinux/plat_property_contexts"
if [[ -f "$PLAT_PROP_CTX" ]] && ! grep -q "^ro.midas.device " "$PLAT_PROP_CTX"; then
    echo "ro.midas.device u:object_r:build_prop:s0 exact string" >> "$PLAT_PROP_CTX"
fi
BPROP "system" "ro.midas.device" "a34x"
if EXISTS "system" "lib64/libmidas_core.camera.samsung.so"; then
    HEX_EDIT "system/system/lib64/libmidas_core.camera.samsung.so" \
        "726f2e70726f647563742e646576696365" \
        "726f2e6d696461732e6465766963650000"
fi
LOG_END

LOG_BEGIN "- Copying custom A34x camera features (into stock & workspace)"
if [[ -d "$SCRPATH/system.img/cameradata" ]]; then
    cp -rf --remove-destination "$SCRPATH/system.img/cameradata/"* "$STOCK_FW/system/system/cameradata/"
    cp -rf --remove-destination "$SCRPATH/system.img/cameradata/"* "$WORKSPACE/system/system/cameradata/"
fi
LOG_END

LOG_BEGIN "- Adjusting astro/ patches for Galaxy A34 5G (120Hz, Optical FP, MT6877 SSRM, Audio)"
# 1. Prevent hardlink 'same file' copy errors in module_utils.sh
sed -i 's/cp -rf /cp -rf --remove-destination /g' "$SCRIPTS/utils/module_utils.sh" 2>/dev/null || true

# 2. Keep 120Hz High Refresh Rate enabled in SecSettings.apk
find "$PROJECT_DIR" -type f -name "Disable-High-Refresh-Rate-Settings.smalipatch" -delete

# 3. Do not apply capacitive side-fingerprint patches on optical in-display FP A34
find "$PROJECT_DIR" -type f -name "Add-Side-Fingerprint-Support.sh" -delete

# 4. Remove HybridRadio.apk patch folder since A34 5G does not have FM Radio
find "$PROJECT_DIR" -type d -name "HybridRadio.apk" -exec rm -rf {} + 2>/dev/null || true

# 5. Update astro's SSRM warning script to use A34x's siop_a34x_mt6877v policy
find "$PROJECT_DIR" -type f -name "REMOVE_SSRM_WARNING.sh" -exec sed -i \
    -e 's/siop_m51_sm7150/siop_a34x_mt6877v/g' \
    -e 's/dvfs_policy_sm7150_xx/dvfs_policy_mt6877_xx/g' {} +

# 6. Replace hardcoded SM-M515F references in astro CSC scripts with SM-A346B
find "$PROJECT_DIR" -type f -name "*.sh" -exec sed -i 's/SM-M515F/SM-A346B/g' {} +

# 7. Prevent paradigm speaker script (and ONLY non-Viper scripts) from overwriting Viper4Android's audio_effects_common.conf
find "$PROJECT_DIR" -type f -name "*.sh" ! -name "*Viper*" -exec sed -i '/audio_effects_common\.conf/ s/^ADD_FROM_FW/#ADD_FROM_FW/' {} +
LOG_END