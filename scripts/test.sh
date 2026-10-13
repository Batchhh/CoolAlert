#!/usr/bin/env bash
# Runs everything CI runs: the package's unit tests, then the demo app's end-to-end self-test
# (real alerts on a simulator: taps, timeouts, async actions, layout, memory).
#
#   scripts/test.sh                 # picks or creates an iPhone simulator
#   SIMULATOR_UDID=… scripts/test.sh
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED="${DERIVED_DATA:-${TMPDIR:-/tmp}/CoolAlert-DerivedData}"
BUNDLE_ID="com.coolalert.demo"
SIM_NAME="CoolAlert Tests"

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

pick_simulator() {
  if [[ -n "${SIMULATOR_UDID:-}" ]]; then echo "$SIMULATOR_UDID"; return; fi
  local devices udid
  devices=$(xcrun simctl list devices available -j)
  # Prefer our own simulator, then any iPhone on the newest iOS runtime.
  udid=$(jq -r --arg name "$SIM_NAME" '[.devices[][] | select(.name == $name)] | first | .udid // empty' <<<"$devices")
  if [[ -z "$udid" ]]; then
    udid=$(jq -r '[.devices | to_entries[] | select(.key | test("iOS")) | .value[] | select(.name | test("^iPhone"))] | last | .udid // empty' <<<"$devices")
  fi
  if [[ -z "$udid" ]]; then
    local runtime type
    runtime=$(xcrun simctl list runtimes available -j | jq -r '[.runtimes[] | select(.platform == "iOS")] | last | .identifier')
    type=$(xcrun simctl list devicetypes -j | jq -r '[.devicetypes[] | select(.name | test("^iPhone [0-9]+ Pro$"))] | last | .identifier')
    udid=$(xcrun simctl create "$SIM_NAME" "$type" "$runtime")
  fi
  echo "$udid"
}

UDID=$(pick_simulator)
DESTINATION="platform=iOS Simulator,id=$UDID"
step "Simulator: $(xcrun simctl list devices -j | jq -r --arg id "$UDID" '.devices[][] | select(.udid == $id) | .name') ($UDID)"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

step "Unit tests"
xcodebuild test -scheme CoolAlert -destination "$DESTINATION" -derivedDataPath "$DERIVED" -quiet

step "Building the demo app"
xcodebuild build -project Example/CoolAlertDemo.xcodeproj -scheme CoolAlertDemo \
  -destination "$DESTINATION" -derivedDataPath "$DERIVED" -quiet
xcrun simctl install "$UDID" "$DERIVED/Build/Products/Debug-iphonesimulator/CoolAlertDemo.app"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

step "End-to-end self-test"
LOG=$(mktemp)
# --console-pty streams the app's output and returns when it exits; perl's alarm is a portable timeout.
perl -e 'alarm shift; exec @ARGV' 300 \
  xcrun simctl launch --console-pty "$UDID" "$BUNDLE_ID" -selftest YES >"$LOG" 2>&1 || true
grep -E '^(FAIL|SELFTEST)' "$LOG" || true
passed=$(grep -c '^PASS' "$LOG" || true)
if grep -q 'SELFTEST DONE failures=0' "$LOG"; then
  printf '\n\033[32m✓ All checks passed (%s self-test checks).\033[0m\n' "$passed"
else
  printf '\n\033[31m✗ Self-test failed or did not finish. Last output:\033[0m\n'
  tail -n 40 "$LOG"
  exit 1
fi
