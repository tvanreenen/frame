#!/bin/bash

# Shared identity constants used by scripts and release tooling.
export FRAME_PRODUCT_NAME="Frame"
export FRAME_PRODUCT_NAME_DEBUG="Frame-Debug"
export FRAME_CLI_NAME="frame"
export FRAME_DEBUG_APP_BINARY="FrameApp"
export FRAME_XCODE_SCHEME="Frame"
export FRAME_BUNDLE_ID_STABLE="com.frame.app"
export FRAME_BUNDLE_ID_DEBUG="com.frame.app.debug"
export FRAME_CODESIGN_IDENTITY_DEFAULT="frame-codesign-certificate"
export FRAME_REPO_SLUG="tvanreenen/frame"
export FRAME_REPO_URL="https://github.com/${FRAME_REPO_SLUG}"
export FRAME_HOMEBREW_TAP="tvanreenen/homebrew-tap"
export FRAME_CASK_STABLE="frame"
export FRAME_RELEASE_PREFIX="${FRAME_PRODUCT_NAME}-v"
export FRAME_DIST_DIR="dist"
export FRAME_RELEASE_WORK_PREFIX="frame-release-work"
