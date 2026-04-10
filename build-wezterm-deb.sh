#!/bin/bash
# This script updates the WezTerm source, compiles it, and generates a .deb package.
# It can be run from the root of the WezTerm git repository or from a directory
# where it will clone the repository into a 'wezterm' subdirectory.

set -x # Enable debug output
set -e # Exit on error

START_DIR=$(pwd)

# Check if we are in a git repo or need to clone
if [ ! -d ".git" ]; then
  echo "Not in a git repository."
  if [ -d "wezterm/.git" ]; then
    echo "Found wezterm directory with git repo. Entering..."
    cd wezterm
  else
    echo "Cloning WezTerm repository..."
    git clone https://github.com/wez/wezterm.git
    cd wezterm
  fi
fi

REPO_ROOT=$(pwd)

# 1. Update source
echo "Updating source..."
git pull

# 2. Compile
echo "Compiling WezTerm..."
cargo build --release -p wezterm-gui -p wezterm -p wezterm-mux-server -p strip-ansi-escapes --features distro-defaults

# 3. Get Version
TAG_NAME=$(git -c "core.abbrev=8" show -s "--format=%cd-%h" "--date=format:%Y%m%d-%H%M%S")
DEB_NAME="wezterm-${TAG_NAME}.deb"

# 4. Setup Packaging Directory
echo "Setting up packaging directory..."
PKG_DIR=$(mktemp -d)
mkdir -p "$PKG_DIR/DEBIAN" "$PKG_DIR/usr/bin" "$PKG_DIR/usr/share/applications" \
         "$PKG_DIR/usr/share/icons/hicolor/128x128/apps" "$PKG_DIR/usr/share/metainfo" \
         "$PKG_DIR/usr/share/nautilus-python/extensions" "$PKG_DIR/usr/share/bash-completion/completions" \
         "$PKG_DIR/usr/share/zsh/functions/Completion/Unix" "$PKG_DIR/etc/profile.d"

# 5. Copy Files
echo "Copying files..."
RELEASE_DIR="$REPO_ROOT/target/release"

cp "$RELEASE_DIR/wezterm" "$PKG_DIR/usr/bin/"
cp "$RELEASE_DIR/wezterm-gui" "$PKG_DIR/usr/bin/"
cp "$RELEASE_DIR/wezterm-mux-server" "$PKG_DIR/usr/bin/"
cp "$RELEASE_DIR/strip-ansi-escapes" "$PKG_DIR/usr/bin/"
cp "$REPO_ROOT/assets/open-wezterm-here" "$PKG_DIR/usr/bin/"

cp "$REPO_ROOT/assets/icon/terminal.png" "$PKG_DIR/usr/share/icons/hicolor/128x128/apps/org.wezfurlong.wezterm.png"
cp "$REPO_ROOT/assets/wezterm.desktop" "$PKG_DIR/usr/share/applications/org.wezfurlong.wezterm.desktop"
cp "$REPO_ROOT/assets/wezterm.appdata.xml" "$PKG_DIR/usr/share/metainfo/org.wezfurlong.wezterm.appdata.xml"
cp "$REPO_ROOT/assets/wezterm-nautilus.py" "$PKG_DIR/usr/share/nautilus-python/extensions/wezterm-nautilus.py"
cp "$REPO_ROOT/assets/shell-completion/bash" "$PKG_DIR/usr/share/bash-completion/completions/wezterm"
cp "$REPO_ROOT/assets/shell-completion/zsh" "$PKG_DIR/usr/share/zsh/functions/Completion/Unix/_wezterm"
cp "$REPO_ROOT/assets/shell-integration/"* "$PKG_DIR/etc/profile.d/"

# 6. Create Control Files
echo "Creating control files..."
cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: wezterm
Version: ${TAG_NAME}
Conflicts: wezterm-nightly
Architecture: $(dpkg-architecture -q DEB_BUILD_ARCH_CPU)
Maintainer: Wez Furlong <wez@wezfurlong.org>
Section: utils
Priority: optional
Homepage: https://wezterm.org/
Description: Wez's Terminal Emulator.
 wezterm is a terminal emulator with support for modern features
 such as fonts with ligatures, hyperlinks, tabs and multiple
 windows.
Provides: x-terminal-emulator
EOF

cat > "$PKG_DIR/DEBIAN/postinst" <<EOF
#!/bin/sh
set -e
if [ "\$1" = "configure" ] ; then
        update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/open-wezterm-here 20
fi
EOF

cat > "$PKG_DIR/DEBIAN/prerm" <<EOF
#!/bin/sh
set -e
if [ "\$1" = "remove" ]; then
	update-alternatives --remove x-terminal-emulator /usr/bin/open-wezterm-here
fi
EOF

chmod 0755 "$PKG_DIR/DEBIAN"
chmod 0755 "$PKG_DIR/DEBIAN/postinst"
chmod 0755 "$PKG_DIR/DEBIAN/prerm"

# 7. Calculate Dependencies
echo "Calculating dependencies..."
cp "$PKG_DIR/DEBIAN/control" "$PKG_DIR/control"
echo "Source: https://wezterm.org/" >> "$PKG_DIR/control"

TEMP_SHLIB_DIR=$(mktemp -d)
ln -s "$PKG_DIR" "$TEMP_SHLIB_DIR/debian"
pushd "$TEMP_SHLIB_DIR"
# Capture dependencies, ignoring warnings about scripts
deps=$(dpkg-shlibdeps -O -e debian/usr/bin/* | grep "shlibs:Depends=" || true)
popd
rm -rf "$TEMP_SHLIB_DIR"
rm "$PKG_DIR/control"

if [ -n "$deps" ]; then
  echo "$deps" | sed -e 's/shlibs:Depends=/Depends: /' >> "$PKG_DIR/DEBIAN/control"
else
  echo "Warning: Could not calculate dependencies automatically."
fi

# 8. Build Package
echo "Building package..."
fakeroot dpkg-deb --build "$PKG_DIR" "$START_DIR/$DEB_NAME"

# 9. Clean up
rm -rf "$PKG_DIR"

echo "Done! Package created at $START_DIR/$DEB_NAME"
