#! /usr/bin/env sh

# Helper script to build the rust part of the iroh bindings and put them in the correct location.
# (under priv/)

set -e

LIBIROH_PROFILE="${LIBIROH_PROFILE:-release}"

LIB_NAME="libiroh_nif"
TARGET_DIR="native/iroh_nif/target/$LIBIROH_PROFILE"

(cd native/iroh_nif && cargo build --profile "$LIBIROH_PROFILE")
mkdir -p ./priv
if [ -f "$TARGET_DIR/$LIB_NAME.so" ]; then
	cp "$TARGET_DIR/$LIB_NAME.so" "priv/$LIB_NAME.so";
elif [ -f "$TARGET_DIR/$LIB_NAME.dylib" ]; then
	cp "$TARGET_DIR/$LIB_NAME.dylib" "priv/$LIB_NAME.so";
fi
