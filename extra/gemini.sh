#!/usr/bin/env bash
#
# gemini.sh — build & install gemini-cli-git
# Run as a normal user (NOT root).
#
set -euo pipefail

PKGNAME="gemini-cli-git"
UPSTREAM_URL="https://github.com/google-gemini/gemini-cli"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "Do not run as root."

log "Ensuring dependencies..."
sudo pacman -S --needed --noconfirm base-devel git nodejs npm jq curl

for c in makepkg git curl; do
  command -v "$c" >/dev/null || die "Missing: $c"
done

BUILDDIR="$(mktemp -d "${TMPDIR:-/tmp}/${PKGNAME}.XXXXXX")"
trap 'rm -rf "$BUILDDIR" 2>/dev/null || warn "Could not remove $BUILDDIR; run: sudo rm -rf $BUILDDIR"' EXIT

log "Build dir: $BUILDDIR"

# ---------------------------------------------------------------------------
# PKGBUILD — no system-defaults.json source; directory created in package()
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
depends=('glib2' 'glibc' 'libgcc' 'libsecret' 'libstdc++' 'nodejs')
makedepends=('git' 'node-gyp' 'npm' 'python')
optdepends=(
  'ripgrep: file content search'
  'wl-clipboard: clipboard image pasting on Wayland'
  'xclip: clipboard image pasting on X11'
  'xdg-utils: opening URLs in default browser'
)
provides=("google-gemini-cli" "gemini-cli")
conflicts=("google-gemini-cli" "gemini-cli" "google-gemini-cli-git")
replaces=("google-gemini-cli-git")
source=("\$_pkgname::git+\$url.git")
sha256sums=('SKIP')

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
  # The directory is still useful for admins who want to drop a
  # system-defaults.json in place later; create it empty.
  install -dm755 "\$pkgdir/etc/gemini-cli"
}
EOF

log "Building with makepkg -si..."
cd "$BUILDDIR"
makepkg -si --noconfirm

log "Done."
