#!/bin/sh
# Recreate the six start-screen textures that are missing from the GridFS backup.
# The originals were white-on-transparent text panels; these are stand-ins styled
# after the surviving January title card (Lato Light, white on transparent).
#
# Panel aspect ratios come from the mesh scales in the final graph:
#   3.70:1 for the info/banner panels, 7.91:1 for CLICK TO START.
set -e
cd "$(dirname "$0")/.."
OUT=site/data/recreated
LIGHT=tools/fonts/Lato-Light.ttf
REG=tools/fonts/Lato-Regular.ttf
# ImageMagick 7 is `magick`; distros that still ship 6 only have `convert`
MAGICK=$(command -v magick || command -v convert)
[ -f $LIGHT ] && [ -f $REG ] || { echo "Lato fonts missing - run ./install.sh"; exit 1; }
mkdir -p $OUT

# panel <file> <width> <height> then triples of <font> <pointsize> <text>
panel() {
	file=$1 w=$2 h=$3
	shift 3
	n=0
	while [ $# -gt 0 ]; do
		font=$1 size=$2 text=$3
		shift 3
		$MAGICK -background none -fill white -font "$font" -pointsize "$size" label:"$text" "$OUT/.line$n.png"
		n=$((n+1))
	done
	lines=""
	i=0
	while [ $i -lt $n ]; do lines="$lines $OUT/.line$i.png"; i=$((i+1)); done
	# stack lines with a small gap above each, shrink to fit if needed, then centre on the panel canvas
	$MAGICK $lines -background none -gravity north -splice 0x18 -gravity center -append -trim +repage \
		-resize "$((w * 92 / 100))x$((h * 90 / 100))>" \
		-gravity center -background none -extent ${w}x${h} \
		-define png:exclude-chunks=date,time -strip "PNG32:$OUT/$file"
	rm -f $OUT/.line*.png
	echo "$OUT/$file"
}

panel title.png          1480 400  $LIGHT 150 "OCEAN OF THOUGHT"
panel click-to-start.png 1264 160  $REG    96 "CLICK TO START"
panel webvr-info.png     1480 400  $LIGHT 104 "Best viewed in VR"  $LIGHT 72 "get a WebVR browser at webvr.rocks"
panel machinedrum.png    1480 400  $REG   140 "MACHINEDRUM"  $LIGHT 72 "Human Energy - out now on Ninja Tune"
panel logos.png          1480 400  $LIGHT 120 "machinedrum.net"
panel 360-info.png       1480 400  $LIGHT 120 "LOOK AROUND"  $LIGHT 72 "drag or turn your head - 360°"
