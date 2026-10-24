#!/bin/sh
# Pull the assets referenced by graph/*.json out of a Vizor dev database's GridFS.
#
#   sh tools/extract-assets.sh <mongo dbpath>
#
# The dbpath is a copy of a Vizor /data/db (mmapv1 files: vizor-assets.*, vizor.*).
# It must be writable - copy it out of Time Machine first. Needs MongoDB 3.4
# (./install.sh --with-mongo); 4.0 refuses these pre-3.6 collections.
set -e
cd "$(dirname "$0")/.."

DBPATH=$1
[ -n "$DBPATH" ] || { echo "usage: $0 <mongo dbpath>"; exit 1; }
BIN=$(ls -d tools/mongodb-*-3.4.*/bin 2>/dev/null | head -1)
[ -n "$BIN" ] || { echo "MongoDB 3.4 not found in tools/ - run ./install.sh --with-mongo"; exit 1; }
PORT=27999

$BIN/mongod --dbpath "$DBPATH" --storageEngine mmapv1 --port $PORT --bind_ip 127.0.0.1 \
	--logpath "$DBPATH/../mongod-extract.log" --fork
trap '$BIN/mongo --quiet --port $PORT admin --eval "db.shutdownServer()" >/dev/null 2>&1 || true' EXIT

get() {
	$BIN/mongofiles --quiet --port $PORT -d vizor-assets get "$1" -l "$2" >/dev/null 2>&1 && [ -s "$2" ]
}

# the Jan 31 graph lives in GridFS too
get /graph/kschzt/ocean-of-thought.json graph/ocean-of-thought.gridfs.json &&
	echo "OK   /graph/kschzt/ocean-of-thought.json"

ok=0 miss=0
for url in $(cat graph/ocean-of-thought.backup.json graph/ocean-of-thought.gridfs.json |
		grep -oE '"url":"/data/[^"]*"' | sed 's/"url":"\/data//; s/"$//' | sort -u); do
	out="site/data$url"
	mkdir -p "$(dirname "$out")"
	if get "$url" "$out"; then
		ok=$((ok + 1))
	else
		rm -f "$out"
		miss=$((miss + 1))
		echo "MISS $url"
	fi
done
echo "extracted $ok, missing $miss (missing ones are substituted by tools/prepare-graphs.py)"
