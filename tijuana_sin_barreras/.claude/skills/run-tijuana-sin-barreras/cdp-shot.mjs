// Driver CDP mínimo para capturar una app web de Flutter (CanvasKit).
// Lanza google-chrome headless, espera a que el canvas pinte y captura PNG.
// Uso: node cdp-shot.mjs <url> <salida.png> [esperaMs]
import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';

const url = process.argv[2] ?? 'http://127.0.0.1:8099/';
const out = process.argv[3] ?? 'shot.png';
const waitMs = Number(process.argv[4] ?? 12000);
const PORT = 9222;
const CHROME = process.env.CHROME_EXECUTABLE || '/usr/bin/google-chrome';

const chrome = spawn(CHROME, [
  '--headless=new', '--no-sandbox', '--disable-gpu',
  '--window-size=480,900', '--hide-scrollbars',
  `--remote-debugging-port=${PORT}`,
  'about:blank',
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function getJson(path) {
  const res = await fetch(`http://127.0.0.1:${PORT}${path}`);
  return res.json();
}

let id = 0;
function rpc(ws, method, params = {}) {
  return new Promise((resolve) => {
    const myId = ++id;
    const onMsg = (e) => {
      const msg = JSON.parse(e.data);
      if (msg.id === myId) { ws.removeEventListener('message', onMsg); resolve(msg.result); }
    };
    ws.addEventListener('message', onMsg);
    ws.send(JSON.stringify({ id: myId, method, params }));
  });
}

try {
  // Esperar a que el endpoint de depuración esté listo.
  let target;
  for (let i = 0; i < 30; i++) {
    try {
      const list = await getJson('/json');
      target = list.find((t) => t.type === 'page');
      if (target?.webSocketDebuggerUrl) break;
    } catch {}
    await sleep(500);
  }
  if (!target) throw new Error('No se encontró target de página en Chrome');

  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((res) => ws.addEventListener('open', res, { once: true }));

  await rpc(ws, 'Page.enable');
  await rpc(ws, 'Page.navigate', { url });
  // Flutter web (CanvasKit) carga wasm/fuentes async; damos tiempo a pintar.
  await sleep(waitMs);
  const { data } = await rpc(ws, 'Page.captureScreenshot', { format: 'png' });
  writeFileSync(out, Buffer.from(data, 'base64'));
  console.log(`OK -> ${out}`);
  ws.close();
} catch (err) {
  console.error('ERROR:', err.message);
  process.exitCode = 1;
} finally {
  chrome.kill('SIGKILL');
}
