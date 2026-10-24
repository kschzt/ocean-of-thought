// Rebuild Vizor Patches' player.min.js without the 2017 gulp toolchain.
// Mirrors gulpfile.js `js:player`: concat(engine + player globs), each file prefixed with ';\n'.
//
//   node tools/build-player.mjs <patches checkout> <out.js>
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'

const [src, out] = process.argv.slice(2)
if (!src || !out) {
	console.error('usage: build-player.mjs <patches checkout> <out.js>')
	process.exit(1)
}

// pull `var paths = {...}` out of the gulpfile and evaluate just that literal
const gulpfile = fs.readFileSync(path.join(src, 'gulpfile.js'), 'utf8')
const m = gulpfile.match(/var paths = (\{[\s\S]*?\n\})\n/)
if (!m)
	throw new Error('could not find `var paths` in gulpfile.js')
const paths = vm.runInNewContext('(' + m[1] + ')')

const patterns = paths.js.engine.concat(paths.js.player)
const files = []
for (const p of patterns) {
	const matches = p.includes('*')
		? fs.globSync(p, { cwd: src }).sort()
		: [p]
	for (const f of matches) {
		const rel = path.normalize(f)
		// gulp 3's src() silently skipped listed files that didn't exist
		if (!fs.existsSync(path.join(src, rel))) {
			console.warn('skipping missing', rel)
			continue
		}
		if (!files.includes(rel))
			files.push(rel)
	}
}

let bundle = ''
for (const f of files)
	bundle += ';\n' + fs.readFileSync(path.join(src, f), 'utf8') + '\n'

fs.mkdirSync(path.dirname(out), { recursive: true })
fs.writeFileSync(out, bundle)
console.log(`${files.length} files, ${(bundle.length / 1e6).toFixed(2)} MB -> ${out}`)
