#!/usr/bin/env bash
EDGE_SMALI=$(find . -type f -name "DrawEdgeLayout.smali" | head -n 1)
if [[ -n "$EDGE_SMALI" ]]; then
    sed -i 's/SM-M127/SM-A346/g' "$EDGE_SMALI"
fi

if [[ -f "res/values/dimens.xml" ]]; then
    sed -i 's/<dimen name="sm_m127">36.0dp<\/dimen>/<dimen name="sm_a346">40.0dp<\/dimen>/g' "res/values/dimens.xml"
fi

if [[ -f "res/values/public.xml" ]]; then
    sed -i 's/<public type="dimen" name="sm_m127"/<public type="dimen" name="sm_a346"/g' "res/values/public.xml"
fi