#!/usr/bin/env bash
# Wählt das Ziel für flutter run: angeschlossenes Android-Gerät, sonst Chrome.
# Wird von install_debug.sh und install_release.sh gesourcet.

pick_device() {
  DEVICE_ARGS=()

  # Wenn der Aufrufer selbst -d/--device-id mitgibt, nicht reinreden.
  for arg in "$@"; do
    case "$arg" in
      -d|--device-id|--device-id=*) return 0 ;;
    esac
  done

  local adb=adb
  if ! command -v adb >/dev/null 2>&1; then
    adb=""
    for candidate in "${ANDROID_HOME:-}/platform-tools/adb" \
                     "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
                     "$HOME/Android/Sdk/platform-tools/adb"; do
      if [[ -x "$candidate" ]]; then adb="$candidate"; break; fi
    done
  fi

  local devices=""
  if [[ -n "$adb" ]]; then
    devices=$("$adb" devices | awk '$2 == "device" { print $1 }')
  fi

  if [[ -z "$devices" ]]; then
    echo "Kein Android-Gerät angeschlossen – starte im Browser." >&2
    DEVICE_ARGS=(-d chrome)
    return 0
  fi

  if (( $(wc -l <<<"$devices") > 1 )); then
    echo "Mehrere Android-Geräte angeschlossen:" >&2
    sed 's/^/  /' <<<"$devices" >&2
    echo "Bitte mit -d <id> auswählen." >&2
    exit 1
  fi

  echo "Gerät: $devices" >&2
  DEVICE_ARGS=(-d "$devices")
}
