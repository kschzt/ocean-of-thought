"""Write the playable graph variants into site/graph/.

final.json  - the March 2017 graph (ocean-of-thought.json.gz from the Time Machine
              backup), with the 8 assets that didn't survive swapped for the closest
              surviving equivalents.
jan31.json  - the 2017-01-31 iteration saved in the local GridFS, unchanged; every
              asset it references survived.

Usage: python3 tools/prepare-graphs.py
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), '..')

SUBSTITUTIONS = {
	# the soundtrack: same track (Machinedrum - Ocean of Thought), as uploaded in January
	'/fthr/assets/audio/ocean.ogg':
		'/data/audio/d871cd7559c4a0531cf20b274078894a80e8b40d.ogg',
	# Machinedrum's flower model is gone; January used lintu's flower1 in the same two nodes
	'/data/machinedrum/assets/scene/ocean-flower1-new/ocean-flower1-new.obj':
		'/data/lintu/assets/scene/flower1/flower1.obj',
	# start screen panels, recreated by tools/make-textures.sh
	'/data/image/4d9480a32e9a25d125ac582a38ec1d5ff36fbf57.png': '/data/recreated/title.png',
	'/data/image/626ffa3f5d2dba00f79c39ecf120ee3eb8bf8b24.png': '/data/recreated/click-to-start.png',
	'/data/image/98f4b29c6ee2a1e4e408ea869c70a47a5c49824f.png': '/data/recreated/webvr-info.png',
	'/data/image/585acb09d211d1dd7a2ed188d914cc32fa64377b.png': '/data/recreated/machinedrum.png',
	'/data/image/a096685dccf723923d96c5c8cbdb157ffaffc856.png': '/data/recreated/logos.png',
	'/data/image/1fcc72ddeef5fd276fbb3f2cd43a24b5fcba61cb.png': '/data/recreated/360-info.png',
}


def rewrite(graph, counts):
	for node in graph.get('nodes', []):
		if 'graph' in node:
			rewrite(node['graph'], counts)
		state = node.get('state')
		if isinstance(state, dict) and state.get('url') in SUBSTITUTIONS:
			old = state['url']
			state['url'] = SUBSTITUTIONS[old]
			counts[old] = counts.get(old, 0) + 1


def asset_urls(graph, urls):
	for node in graph.get('nodes', []):
		if 'graph' in node:
			asset_urls(node['graph'], urls)
		state = node.get('state')
		if isinstance(state, dict) and isinstance(state.get('url'), str):
			urls.add(state['url'])
	return urls


def check_assets(name, graph):
	missing = []
	for url in sorted(asset_urls(graph['root'], set())):
		if not url.startswith('/data/'):
			missing.append(url)
		elif not os.path.exists(os.path.join(ROOT, 'site', url.lstrip('/'))):
			missing.append(url)
	print(f'{name}: {"all assets present" if not missing else "MISSING " + ", ".join(missing)}')


def main():
	out = os.path.join(ROOT, 'site', 'graph')
	os.makedirs(out, exist_ok=True)

	with open(os.path.join(ROOT, 'graph', 'ocean-of-thought.backup.json')) as f:
		final = json.load(f)
	counts = {}
	rewrite(final['root'], counts)
	for old, n in counts.items():
		print(f'  {n}x {old} -> {SUBSTITUTIONS[old]}')
	unused = set(SUBSTITUTIONS) - set(counts)
	if unused:
		raise SystemExit(f'substitutions never applied: {unused}')
	with open(os.path.join(out, 'final.json'), 'w') as f:
		json.dump(final, f)
	check_assets('final.json', final)

	with open(os.path.join(ROOT, 'graph', 'ocean-of-thought.gridfs.json')) as f:
		jan = json.load(f)
	with open(os.path.join(out, 'jan31.json'), 'w') as f:
		json.dump(jan, f)
	check_assets('jan31.json', jan)


main()
