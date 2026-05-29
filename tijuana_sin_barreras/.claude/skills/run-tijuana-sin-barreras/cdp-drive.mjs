// Driver CDP con sesión persistente para verificar FLUJOS (no solo capturas).
// Lanza Chrome headless una vez y lo deja vivo entre invocaciones, de modo que
// se pueda: navegar, capturar, hacer click en coordenadas y volver a capturar.
//
// Subcomandos:
//   start <url> [waitMs] [w] [h]   lanza Chrome (detached), navega y espera
//   shot  <out.png>                captura la página actual
//   nav   <url> [waitMs] <out.png> navega a otra URL y captura
//   click <x> <y> [waitMs] <out>   click en (x,y), espera y captura
//   stop                           cierra Chrome
//
// Pensado para Windows (CHROME_EXECUTABLE apunta al chrome.exe real).
import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';

const PORT = 9222;
const CHROME = process.env.CHROME_EXECUTABLE
  || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function getJson(path) {
  const res = await fetch(`http://127.0.0.1:${PORT}${path}`);
  return res.json();
}

async function pageTarget() {
  for (let i = 0; i < 40; i++) {
    try {
      const list = await getJson('/json');
      const t = list.find((x) => x.type === 'page' && x.webSocketDebuggerUrl);
      if (t) return t;
    } catch {}
    await sleep(500);
  }
  throw new Error('No se encontró target de página en Chrome (¿está corriendo?)');
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

async function connect() {
  const target = await pageTarget();
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((res) => ws.addEventListener('open', res, { once: true }));
  await rpc(ws, 'Page.enable');
  return ws;
}

async function capture(ws, out) {
  const { data } = await rpc(ws, 'Page.captureScreenshot', { format: 'png' });
  writeFileSync(out, Buffer.from(data, 'base64'));
  console.log(`OK -> ${out}`);
}

async function clickAt(ws, x, y) {
  for (const type of ['mousePressed', 'mouseReleased']) {
    await rpc(ws, 'Input.dispatchMouseEvent', {
      type, x, y, button: 'left', clickCount: 1,
    });
  }
}

const [cmd, ...rest] = process.argv.slice(2);

try {
  if (cmd === 'start') {
    const url = rest[0] ?? 'http://127.0.0.1:8099/';
    const waitMs = Number(rest[1] ?? 15000);
    const w = Number(rest[2] ?? 420);
    const h = Number(rest[3] ?? 880);
    const chrome = spawn(CHROME, [
      '--headless=new', '--no-sandbox', '--disable-gpu',
      `--window-size=${w},${h}`, '--hide-scrollbars',
      '--use-fake-ui-for-media-stream',
      `--remote-debugging-port=${PORT}`,
      'about:blank',
    ], { stdio: 'ignore', detached: true });
    chrome.unref();
    const ws = await connect();
    // Grant geolocation override so the map screen doesn't hang on a prompt.
    await rpc(ws, 'Emulation.setGeolocationOverride', {
      latitude: 32.5149, longitude: -117.0382, accuracy: 30,
    });
    await rpc(ws, 'Page.navigate', { url });
    await sleep(waitMs);
    console.log('STARTED');
    ws.close();
  } else if (cmd === 'shot') {
    const ws = await connect();
    await capture(ws, rest[0]);
    ws.close();
  } else if (cmd === 'nav') {
    const url = rest[0];
    const waitMs = Number(rest[1] ?? 12000);
    const out = rest[2];
    const ws = await connect();
    await rpc(ws, 'Page.navigate', { url });
    await sleep(waitMs);
    await capture(ws, out);
    ws.close();
  } else if (cmd === 'click') {
    const x = Number(rest[0]);
    const y = Number(rest[1]);
    const waitMs = Number(rest[2] ?? 4000);
    const out = rest[3];
    const ws = await connect();
    await clickAt(ws, x, y);
    await sleep(waitMs);
    await capture(ws, out);
    ws.close();
  } else if (cmd === 'stop') {
    try {
      const t = await pageTarget();
      const ws = new WebSocket(t.webSocketDebuggerUrl);
      await new Promise((res) => ws.addEventListener('open', res, { once: true }));
      await rpc(ws, 'Browser.close');
      ws.close();
    } catch {}
    console.log('STOPPED');
  } else {
    console.error('Subcomando desconocido:', cmd);
    process.exitCode = 1;
  }
} catch (err) {
  console.error('ERROR:', err.message);
  process.exitCode = 1;
}
