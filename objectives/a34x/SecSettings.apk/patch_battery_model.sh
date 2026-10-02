#!/usr/bin/env bash
BATT_CTRL="smali_classes4/com/samsung/android/settings/deviceinfo/batteryinfo/BatteryRegulatoryPreferenceController.smali"
BATT_FRAG="smali_classes4/com/samsung/android/settings/deviceinfo/batteryinfo/SecBatteryInfoFragment.smali"

if [[ -f "$BATT_CTRL" ]]; then
    sed -i 's/SM-A236B/SM-A346B/g' "$BATT_CTRL"
    sed -i 's/ro\.product\.model/ro.boot.em.model/g' "$BATT_CTRL"
fi

if [[ -f "$BATT_FRAG" ]]; then
    sed -i 's/SM-A236B/SM-A346B/g' "$BATT_FRAG"
    sed -i 's/ro\.product\.model/ro.boot.em.model/g' "$BATT_FRAG"
fi