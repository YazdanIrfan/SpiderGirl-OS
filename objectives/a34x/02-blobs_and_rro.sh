#!/usr/bin/env bash
# MOD_NAME="A34 5G Stock Blobs, RRO & SSRM Fixes"
# MOD_AUTHOR="Salvo Giangreco"

LOG_BEGIN "- Replacing RRO base with stock A34 RRO"
if compgen -G "$STOCK_FW/product/overlay/framework-res*.apk" > /dev/null; then
    cp -f "$STOCK_FW/product/overlay"/framework-res*.apk "$WORKSPACE/product/overlay/product_overlay.apk"
fi
LOG_END

LOG_BEGIN "- Applying A34 Debloat & RISC-V Hotword Blobs"
REMOVE "system" "app/WifiRROverlayAppLls"
REMOVE "product" "priv-app/HotwordEnrollmentOKGoogleEx4CORTEXM55"
REMOVE "product" "priv-app/HotwordEnrollmentXGoogleEx4CORTEXM55"
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

LOG_BEGIN "- Registering MT6877 SSRM & DVFS policy names"
# Overrides astro/misc/ssrm which hardcodes siop_m51_sm7150
mkdir -p "$WORKSPACE/patches/SamsungDeviceHealthManagerService.apk"
cat > "$WORKSPACE/patches/SamsungDeviceHealthManagerService.apk/SET_A34X_SSRM.sh" << 'EOF'
find . -type f -name "*.smali" -exec sed -i 's/siop_m51_sm7150/siop_a34x_mt6877v/g' {} +
find . -type f -name "*.smali" -exec sed -i 's/dvfs_policy_sm7150_xx/dvfs_policy_mt6877_xx/g' {} +
EOF

mkdir -p "$WORKSPACE/patches/ssrm.jar"
cp -f "$WORKSPACE/patches/SamsungDeviceHealthManagerService.apk/SET_A34X_SSRM.sh" \
      "$WORKSPACE/patches/ssrm.jar/SET_A34X_SSRM.sh"
LOG_END