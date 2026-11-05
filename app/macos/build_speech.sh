#!/bin/sh
set -eu
# Xcode's own build does not see the shell's PATH.
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
cmake -S "$PROJECT_DIR/../native" -B "$PROJECT_TEMP_DIR/speech" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="$(echo "$ARCHS" | tr ' ' ';')" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET"
cmake --build "$PROJECT_TEMP_DIR/speech" --config Release --parallel
mkdir -p "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
cp "$PROJECT_TEMP_DIR/speech/libeasydict_speech.dylib" "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/"
if [ "$CODE_SIGNING_ALLOWED" = YES ]; then
  codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/libeasydict_speech.dylib"
fi
