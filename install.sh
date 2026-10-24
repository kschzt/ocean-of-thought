#!/bin/sh
# Install everything needed to build, preview and deploy Ocean of Thought.
#
#   ./install.sh               build + preview + deploy tooling
#   ./install.sh --with-mongo  also MongoDB 3.4, for re-extracting assets from a Vizor DB backup
#
# Safe to re-run; only installs what's missing. macOS (Homebrew) or Debian/Ubuntu (apt).
set -e
cd "$(dirname "$0")"

WITH_MONGO=
for arg in "$@"; do
	case $arg in
		--with-mongo) WITH_MONGO=1 ;;
		*) echo "unknown option $arg"; exit 1 ;;
	esac
done

OS=$(uname -s)
have() { command -v "$1" >/dev/null 2>&1; }
step() { printf '\n== %s\n' "$1"; }

pkg_install() {
	if [ "$OS" = Darwin ]; then
		have brew || { echo "Homebrew is required: https://brew.sh"; exit 1; }
		brew install "$@"
	elif have apt-get; then
		sudo apt-get update -qq && sudo apt-get install -y "$@"
	else
		echo "please install: $*"; exit 1
	fi
}

step "system packages"
missing=
have git || missing="$missing git"
have python3 || missing="$missing python3"
have ffmpeg || missing="$missing ffmpeg"
have magick || have convert || missing="$missing imagemagick"
if [ -n "$missing" ]; then
	pkg_install $missing
else
	echo "git, python3, ffmpeg, imagemagick: ok"
fi

step "node (22+)"
node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
if [ "$node_major" -lt 22 ]; then
	if [ "$OS" = Darwin ]; then
		pkg_install node
	else
		echo "Node.js 22 or newer is required (found: ${node_major}). Install it with nvm:"
		echo "  https://github.com/nvm-sh/nvm  then  nvm install 22"
		exit 1
	fi
fi
node --version

step "Vizor Patches engine (submodule, pinned to 0.15.23)"
git submodule update --init patches
git -C patches log -1 --format='%h %ad %s' --date=short

step "fonts for the recreated start screen (Lato, SIL OFL)"
mkdir -p tools/fonts
for w in Light Regular; do
	f=tools/fonts/Lato-$w.ttf
	[ -s $f ] || curl -sSfL "https://github.com/google/fonts/raw/main/ofl/lato/Lato-$w.ttf" -o $f
done
ls tools/fonts

step "deploy tooling (cf + wrangler)"
(cd deploy && npm ci --no-audit --no-fund)

if [ -n "$WITH_MONGO" ]; then
	step "MongoDB 3.4 (reads Vizor's mmapv1 data files)"
	if ls -d tools/mongodb-*-3.4.*/bin >/dev/null 2>&1; then
		echo "already installed"
	else
		if [ "$OS" = Darwin ]; then
			# x86_64 only; runs under Rosetta on Apple Silicon
			if [ "$(uname -m)" = arm64 ] && ! arch -x86_64 /usr/bin/true 2>/dev/null; then
				softwareupdate --install-rosetta --agree-to-license
			fi
			url=https://fastdl.mongodb.org/osx/mongodb-osx-ssl-x86_64-3.4.24.tgz
		else
			url=https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-3.4.24.tgz
		fi
		curl -sSfL "$url" | tar xz -C tools
	fi
	"$(ls -d tools/mongodb-*-3.4.*/bin | head -1)/mongod" --version | head -1
fi

step "optional"
chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if [ -x "$chrome" ] || have google-chrome || have chromium; then
	echo "Chrome found - tools/drive.mjs can run headless checks"
else
	echo "Chrome not found - tools/drive.mjs (headless checks) won't run; set CHROME=/path/to/chrome"
fi
have cf && echo "cf CLI on PATH" || echo "cf CLI: using deploy/node_modules (npx cf ...); run 'npx cf auth login' in deploy/ before deploying"

printf '\nall set. next:\n  sh tools/build.sh\n  python3 -m http.server 8642 --bind 127.0.0.1 --directory site\n'
