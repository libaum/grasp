#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -f dart_defines.json ]]; then
  echo "dart_defines.json fehlt – kopier dart_defines.example.json und trag die Keys ein." >&2
  exit 1
fi

# Baut mit den Keys, installiert auf dem angeschlossenen Gerät und startet.
flutter run --release --dart-define-from-file=dart_defines.json "$@"
