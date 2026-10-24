// Headless Chrome smoke test for the player: logs console output and exceptions,
// runs a small script of actions, and saves screenshots.
//
//   node tools/drive.mjs <url> <outdir> [action ...]
//
// actions:  wait:<ms>  shot:<name>  click:<x>,<y>  key:<char>  eval:<js>
import { spawn } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'

const [url, outdir, ...actions] = process.argv.slice(2)
const CHROME = process.env.CHROME || (process.platform === 'darwin'
	? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
	: 'google-chrome')
const W = 1280, H = 720

fs.mkdirSync(outdir, { recursive: true })
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'oot-chrome-'))
// port 0: Chrome picks a free port and writes it to <profile>/DevToolsActivePort,
// so we can never attach to some other app's debugger by accident
const chrome = spawn(CHROME, [
	'--headless=new',
	'--remote-debugging-port=0',
	`--user-data-dir=${profile}`,
	`--window-size=${W},${H}`,
	'--autoplay-policy=no-user-gesture-required',
	'--mute-audio',
	'--enable-webgl', '--ignore-gpu-blocklist',
	'about:blank'
], { stdio: 'ignore' })

const sleep = (ms) => new Promise(r => setTimeout(r, ms))

async function target() {
	const portFile = path.join(profile, 'DevToolsActivePort')
	for (let i = 0; i < 50; i++) {
		try {
			const port = fs.readFileSync(portFile, 'utf8').split('\n')[0]
			const list = await (await fetch(`http://127.0.0.1:${port}/json`)).json()
			const page = list.find(t => t.type === 'page' && t.url === 'about:blank')
			if (page) return page
		} catch (e) {}
		await sleep(200)
	}
	throw new Error('chrome did not come up')
}

const page = await target()
const ws = new WebSocket(page.webSocketDebuggerUrl)
await new Promise(r => ws.addEventListener('open', r, { once: true }))

let seq = 0
const pending = new Map()
const send = (method, params = {}) => new Promise((resolve, reject) => {
	const id = ++seq
	pending.set(id, { resolve, reject })
	ws.send(JSON.stringify({ id, method, params }))
})

const t0 = Date.now()
const stamp = () => ((Date.now() - t0) / 1000).toFixed(1).padStart(6)
ws.addEventListener('message', (ev) => {
	const msg = JSON.parse(ev.data)
	if (msg.id && pending.has(msg.id)) {
		const p = pending.get(msg.id)
		pending.delete(msg.id)
		msg.error ? p.reject(new Error(msg.error.message)) : p.resolve(msg.result)
		return
	}
	if (msg.method === 'Runtime.consoleAPICalled') {
		const text = msg.params.args.map(a => a.value !== undefined ? a.value : (a.description || a.type)).join(' ')
		console.log(`${stamp()} [${msg.params.type}] ${text}`.slice(0, 400))
	} else if (msg.method === 'Runtime.exceptionThrown') {
		const d = msg.params.exceptionDetails
		console.log(`${stamp()} [EXCEPTION] ${d.exception ? d.exception.description : d.text}`.slice(0, 1200))
	} else if (msg.method === 'Log.entryAdded') {
		const e = msg.params.entry
		console.log(`${stamp()} [${e.source}:${e.level}] ${e.text} ${e.url || ''}`.slice(0, 400))
	}
})

await send('Runtime.enable')
await send('Log.enable')
await send('Page.enable')
await send('Emulation.setDeviceMetricsOverride', { width: W, height: H, deviceScaleFactor: 1, mobile: false })
await send('Page.navigate', { url })

for (const action of actions) {
	const [verb, ...rest] = action.split(':')
	const arg = rest.join(':')
	if (verb === 'wait') {
		await sleep(Number(arg))
	} else if (verb === 'shot') {
		const { data } = await send('Page.captureScreenshot', { format: 'png' })
		const file = path.join(outdir, arg + '.png')
		fs.writeFileSync(file, Buffer.from(data, 'base64'))
		console.log(`${stamp()} [shot] ${file}`)
	} else if (verb === 'click') {
		const [x, y] = arg.split(',').map(Number)
		for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased'])
			await send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 })
		console.log(`${stamp()} [click] ${x},${y}`)
	} else if (verb === 'key') {
		const code = 'Key' + arg.toUpperCase()
		const keyCode = arg.toUpperCase().charCodeAt(0)
		await send('Input.dispatchKeyEvent', { type: 'keyDown', key: arg, code, windowsVirtualKeyCode: keyCode, text: arg })
		await send('Input.dispatchKeyEvent', { type: 'keyUp', key: arg, code, windowsVirtualKeyCode: keyCode })
		console.log(`${stamp()} [key] ${arg}`)
	} else if (verb === 'eval') {
		const r = await send('Runtime.evaluate', { expression: arg, returnByValue: true, awaitPromise: true })
		console.log(`${stamp()} [eval] ${JSON.stringify(r.result.value)}`.slice(0, 2000))
	}
}

ws.close()
chrome.kill()
await new Promise(r => chrome.once('exit', r))
fs.rmSync(profile, { recursive: true, force: true, maxRetries: 5 })
process.exit(0)
