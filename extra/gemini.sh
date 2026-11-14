#!/usr/bin/env bash
#
# gemini.sh — build & install gemini-cli-git from AUR-style PKGBUILD
# Run as a normal user (NOT root). Script will sudo only for pacman.
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
PKGNAME="gemini-cli-git"
UPSTREAM_URL="https://github.com/google-gemini/gemini-cli"
DEFAULTS_URL="${UPSTREAM_URL}/raw/main/system-defaults.json"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

require_user() {
  if [[ $EUID -eq 0 ]]; then
    die "Do not run this script as root. makepkg refuses to run as root, and pacman is called with sudo."
  fi
}

require_cmds() {
  local c
  for c in sudo pacman makepkg git curl; do
    command -v "$c" >/dev/null 2>&1 || die "Required command not found: $c"
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
require_user

log "Ensuring required system dependencies are installed..."
sudo pacman -S --needed --noconfirm \
  base-devel git nodejs npm jq curl

require_cmds

# Build in a clean, user-owned scratch dir — never the CWD
BUILDDIR="$(mktemp -d "${TMPDIR:-/tmp}/${PKGNAME}.XXXXXX")"
cleanup() {
  # makepkg leaves behind a src/ dir that may contain root-owned files if
  # a previous run failed; try to remove but don't fail the script on it.
  rm -rf "$BUILDDIR" 2>/dev/null || {
    warn "Could not fully remove $BUILDDIR (probably root-owned)."
    warn "Run: sudo rm -rf '$BUILDDIR'"
  }
}
trap cleanup EXIT

log "Build directory: $BUILDDIR"

# ---------------------------------------------------------------------------
# Fetch the real system-defaults.json (the PKGBUILD references it as a
# source file, so it must exist in the build dir before makepkg runs).
# ---------------------------------------------------------------------------
log "Fetching system-defaults.json from upstream..."
curl -fsSL "$DEFAULTS_URL" -o "$BUILDDIR/system-defaults.json" \
  || die "Failed to download $DEFAULTS_URL"

DEFAULTS_SHA="$(sha256sum "$BUILDDIR/system-defaults.json" | awk '{print $1}')"

# ---------------------------------------------------------------------------
# Write PKGBUILD
# ---------------------------------------------------------------------------
log "Writing PKGBUILD..."
cat > "$BUILDDIR/PKGBUILD" <<EOF
# Maintainer: Coraline Shuryn <coraline.shuryn@gmail.com>
pkgname=${PKGNAME}
_pkgname=gemini-cli
epoch=1
pkgver=r5876.g3061555d28
pkgrel=1
pkgdesc="An open-source AI agent that brings the power of Gemini directly into your terminal (git version)"
arch=('x86_64' 'aarch64')
url="${UPSTREAM_URL}"
license=('Apache-2.0')
depends=(
  'glib2'
  'glibc'
  'libgcc'
  'libsecret'
  'libstdc++'
  'nodejs'
)
makedepends=(
  'git'
  'node-gyp'
  'npm'
  'python'
)
optdepends=(
  'ripgrep: file content search'
  'wl-clipboard: clipboard image pasting on Wayland'
  'xclip: clipboard image pasting on X11'
  'xdg-utils: opening URLs in default browser'
)
provides=("google-gemini-cli" "gemini-cli")
conflicts=("google-gemini-cli" "gemini-cli" "google-gemini-cli-git")
replaces=("google-gemini-cli-git")
source=("\$_pkgname::git+\$url.git"
        "system-defaults.json")
sha256sums=('SKIP'
            '${DEFAULTS_SHA}')

pkgver() {
  cd "\$_pkgname"
  printf "r%s.g%s" "\$(git rev-list --count HEAD)" "\$(git rev-parse --short HEAD)"
}

prepare() {
  cd "\$srcdir/\$_pkgname"
  git clean -fdx
}

build() {
  cd "\$srcdir/\$_pkgname"
  export npm_config_cache="\$srcdir/.npm"
  export npm_config_allow_remote=all
  npm install
  npm run bundle
  npm run docs:settings
}

package() {
  cd "\$srcdir/\$_pkgname"
  export npm_config_cache="\$srcdir/.npm"
  npm pack --silent
  local tarball
  tarball="\$(find . -maxdepth 1 -name '*.tgz' -print -quit)"
  [[ -n "\$tarball" ]] || { echo "npm pack produced no tarball" >&2; return 1; }
  npm install -g "\$tarball" --prefix "\$pkgdir/usr" --omit=dev
  install -Dm644 LICENSE "\$pkgdir/usr/share/licenses/\$pkgname/LICENSE"
  install -Dm644 "\$srcdir/system-defaults.json" "\$pkgdir/etc/gemini-cli/system-defaults.json"
}
EOF

# Sanity check: makepkg will not let a PKGBUILD reference a missing local source
[[ -f "$BUILDDIR/system-defaults.json" ]] || die "system-defaults.json missing from build dir"

# ---------------------------------------------------------------------------
# Build & install
# ---------------------------------------------------------------------------
log "Running makepkg -si (this will build the package and prompt for your sudo password to install)..."
cd "$BUILDDIR"
makepkg -si --noconfirm

log "Done. $PKGNAME installed."
