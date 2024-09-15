#!/bin/bash

# Set the project directory
PROJECT_DIR=~/Projects/mingle

# Build the application
meson "$PROJECT_DIR/build" --prefix=/usr --libdir=lib
ninja -C "$PROJECT_DIR/build"

# Install the application files into the AppDir directory
DESTDIR="$PROJECT_DIR/build/AppDir" ninja install -C "$PROJECT_DIR/build"

# Change to the build directory
cd "$PROJECT_DIR/build"

glib-compile-schemas "$PROJECT_DIR/build/AppDir/usr/share/glib-2.0/schemas"
gtk4-update-icon-cache -q -t -f "$PROJECT_DIR/build/AppDir/usr/share/icons/hicolor"
update-desktop-database -q "$PROJECT_DIR/build/AppDir/usr/share/applications"

# Run appimage-builder to create the AppImage
appimage-builder --recipe ../mingle.yml 

# Move the generated AppImage to the project directory
mv Mingle-*-x86_64.AppImage "$PROJECT_DIR"
