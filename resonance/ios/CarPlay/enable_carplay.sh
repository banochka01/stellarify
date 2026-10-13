#!/usr/bin/env bash
# Enables the CarPlay audio scene for a build. Disabled by default.
#
# CarPlay audio apps require the `com.apple.developer.carplay-audio`
# entitlement, granted by Apple per team on request. Unsigned builds
# (ios-unsigned.yml) can never use it, so this script is only run by
# ios-testflight.yml when the repository variable RESONANCE_CARPLAY == "1"
# and the provisioning profile includes the entitlement.
#
# Usage (macOS, from resonance/): bash ios/CarPlay/enable_carplay.sh
set -euo pipefail

PLIST="ios/Runner/Info.plist"
ENTITLEMENTS="ios/Runner/Runner.entitlements"
BUDDY=/usr/libexec/PlistBuddy

ROLE=":UIApplicationSceneManifest:UISceneConfigurations:CPTemplateApplicationSceneSessionRoleApplication"
if ! "$BUDDY" -c "Print $ROLE" "$PLIST" >/dev/null 2>&1; then
  "$BUDDY" -c "Add $ROLE array" "$PLIST"
  "$BUDDY" -c "Add $ROLE:0 dict" "$PLIST"
  "$BUDDY" -c "Add $ROLE:0:UISceneConfigurationName string CarPlay" "$PLIST"
  "$BUDDY" -c "Add $ROLE:0:UISceneClassName string CPTemplateApplicationScene" "$PLIST"
  "$BUDDY" -c "Add $ROLE:0:UISceneDelegateClassName string \$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate" "$PLIST"
fi
"$BUDDY" -c "Set :UIApplicationSceneManifest:UIApplicationSupportsMultipleScenes true" "$PLIST"

if [ ! -f "$ENTITLEMENTS" ]; then
  cat > "$ENTITLEMENTS" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
EOF
fi
"$BUDDY" -c "Add :com.apple.developer.carplay-audio bool true" "$ENTITLEMENTS" 2>/dev/null \
  || "$BUDDY" -c "Set :com.apple.developer.carplay-audio true" "$ENTITLEMENTS"

echo "CarPlay scene enabled. Build with CODE_SIGN_ENTITLEMENTS=Runner/Runner.entitlements."
