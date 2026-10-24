#!/bin/sh
# Rebuild everything in site/ that is derived from sources in this repo.
# The original assets in site/data/ (from the GridFS backup) are committed as-is;
# tools/extract-assets.sh is how they were pulled out of the database.
set -e
cd "$(dirname "$0")/.."

P=patches
[ -f $P/gulpfile.js ] || { echo "patches/ submodule missing - run ./install.sh first"; exit 1; }

echo "== player bundle (Vizor Patches $(git -C $P describe --always 2>/dev/null))"
node tools/build-player.mjs $P site/js/player.js

echo "== page scripts, in the order views/layouts/player.handlebars loaded them"
mkdir -p site/scripts site/vendor site/data/textures
cp $P/browser/scripts/event-emitter.js $P/browser/scripts/util.js \
	$P/browser/scripts/hardware.js $P/browser/scripts/webVRAdapter.js site/scripts/
cp $P/browser/vendor/borismus/webvr-polyfill.js $P/browser/vendor/borismus/webvr-manager.js site/vendor/
cp $P/browser/data/textures/defaulttex.png $P/browser/data/textures/loadingtex.png site/data/textures/
[ -f site/vendor/jquery-2.1.0.min.js ] ||
	curl -sSfL https://code.jquery.com/jquery-2.1.0.min.js -o site/vendor/jquery-2.1.0.min.js

echo "== recreated start screen textures"
sh tools/make-textures.sh

echo "== graphs"
python3 tools/prepare-graphs.py

# Safari can't decode Ogg Vorbis; url_audio_buffer_generator asks for .m4a there instead
for ogg in site/data/audio/*.ogg; do
	m4a="${ogg%.ogg}.m4a"
	[ -f "$m4a" ] || { echo "== $m4a"; ffmpeg -loglevel error -y -i "$ogg" -c:a aac -b:a 192k -movflags +faststart "$m4a"; }
done

echo "done - preview with: python3 -m http.server 8642 --bind 127.0.0.1 --directory site"
