#!/bin/bash
# Configure the Cake Wallet fork for Tixs (iOS).
# Usage: ./configure_tixs.sh ios
#
# Runs flutter pub get and configure.dart with --solana only.
# Does NOT require Monero native libraries.
set -e

cd "$(dirname "$0")"

PLATFORM=${1:-ios}

if [[ "$PLATFORM" != "ios" && "$PLATFORM" != "android" ]]; then
  echo "Usage: $0 ios|android"
  exit 1
fi

cd scripts/$PLATFORM
source ./app_env.sh tixs
./app_config.sh
