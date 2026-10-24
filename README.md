# Ocean of Thought — restored

fthr's (Antti Jädertpolm) 2017 WebVR demo for Machinedrum's *Ocean of Thought* (Human Energy, Ninja Tune 2016),
made in Vizor Patches. Restored from Time Machine backups in October 2026.

Live at **https://oceanofthought.com** (also oot.kschzt.com). `?v=jan31` plays the earlier, complete January iteration.

```sh
./install.sh                     # dependencies (Homebrew or apt), engine submodule, fonts, deploy tooling
sh tools/build.sh                # rebuild everything derived in site/
python3 -m http.server 8642 --bind 127.0.0.1 --directory site
```

## Layout

| path | what |
|---|---|
| `site/` | the deployable static site: player page, engine bundle, graphs, assets |
| `graph/` | the two source graphs as recovered (untouched) |
| `patches/` | submodule: github.com/vizorvr/patches at 0e38d507, **0.15.23**, released 2017-03-28, the day the final graph was saved |
| `tools/` | build / extract / test scripts |
| `deploy/` | `cf deploy` config: a static-assets Worker on oceanofthought.com, www., and oot.kschzt.com |
| `reference/` | the 0.15 `player.min.js` vizor.io actually served (from GridFS, 2017-01-18), for comparison |

## Where it came from

- **Final graph (Mar 2017):** `ocean-of-thought.json.gz` in the 2021-08-12 Time Machine snapshot
  → `graph/ocean-of-thought.backup.json`.
- **Assets:** GridFS (`vizor-assets`) in the local Vizor dev DB under `/data/db` in the same
  snapshot (mmapv1, last written Feb 2017, 52 GB). `tools/extract-assets.sh <dbpath>` pulls out
  everything the graphs reference. It needs `./install.sh --with-mongo`, because only MongoDB 3.4
  will open those files; 4.0 refuses the pre-3.6 collections. Copy the DB out of the backup first
  (`sudo cp`, since the files belong to an old uid), because mongod needs write access.
- **January graph (2017-01-31):** `/graph/kschzt/ocean-of-thought.json` in the same GridFS
  → `graph/ocean-of-thought.gridfs.json`. Every asset it references survived.

## What isn't original

The final graph references 8 assets that aren't in the backup. `tools/prepare-graphs.py` swaps them:

| missing | replacement |
|---|---|
| `/fthr/assets/audio/ocean.ogg` | the January upload of the same track (`data/audio/d871…ogg`, tagged Machinedrum – Ocean of Thought) |
| `machinedrum/…/ocean-flower1-new.obj` | `lintu/…/flower1.obj`, which the January version used in the same two `Flower` nodes |
| 6 start-screen panels (`data/image/…png`) | text panels from `tools/make-textures.sh` in `data/recreated/`. The wording is a guess from the node names (`CLICK TO START`, `MACHINEDRUM-BANNER`, `WEBVR.INFO`, …), styled after the surviving January title card |

If the originals turn up, drop them into `site/data/` under their original paths and remove the
matching lines from `SUBSTITUTIONS`.

`site/index.html` stands in for vizor.io's `views/layouts/player.handlebars`. It loads the scripts
in the same order and adds four shims:

- `E2.track` and `VizorUI` stubs.
- A `/stat/` handler answered with a HEAD request against `data/`. The OBJ loader asked the server
  whether a `.mtl` existed and hangs forever on a plain 404.
- A click-to-enter veil that resumes the AudioContext, which today's autoplay rules require.
- A small variant switch (final / jan31).

## Tools

```sh
node tools/build-player.mjs patches site/js/player.js   # engine bundle, same as gulp js:player
python3 tools/prepare-graphs.py                          # site/graph/{final,jan31}.json
sh tools/make-textures.sh                                # site/data/recreated/*.png
node tools/drive.mjs http://127.0.0.1:8642/ /tmp/shots wait:10000 click:640,360 wait:1500 click:595,372 wait:20000 shot:a
                                                         # headless Chrome check: console log + screenshots (CHROME=… to override)
cd deploy && npx cf deploy                               # needs `npx cf auth login` on the Cloudflare account
```
