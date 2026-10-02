#!/usr/bin/env bash
mkdir -p assets
cp -f "$OBJECTIVE/SamsungDeviceHealthManagerService.apk/assets/siop_a34x_mt6877v.xml" assets/siop_a34x_mt6877v.xml
find . -type f -name "*.smali" -exec sed -i \
    -e 's/siop_m51_sm7150/siop_a34x_mt6877v/g' \
    -e 's/siop_r11q_sm8450/siop_a34x_mt6877v/g' \
    -e 's/dvfs_policy_sm7150_xx/dvfs_policy_mt6877_xx/g' \
    -e 's/dvfs_policy_sm8450_xx/dvfs_policy_mt6877_xx/g' {} +