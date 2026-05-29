// Servidor estático con fallback SPA: sirve los archivos de build/web y, para
// rutas que no son archivos (p. ej. /home, /report), devuelve index.html para
// que el enrutador de Flutter web tome la ruta inicial desde la URL.
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { join, extname, normalize } from 'node:path';

const root = process.argv[2] ?? 'build/web';
const port = Number(process.argv[3] ?? 8100);

const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.css': 'text/css',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.ico': 'image/x-icon',
  '.bin': 'application/octet-stream', '.symbols': 'application/octet-stream',
};

async function send(res, file, status = 200) {
  const body = await readFile(file);
  res.writeHead(status, { 'content-type': MIME[extname(file)] ?? 'application/octet-stream' });
  res.end(body);
}

createServer(async (req, res) => {
  try {
    const urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    const candidate = normalize(join(root, urlPath));
    if (urlPath !== '/' && extname(candidate)) {
      try {
        const s = await stat(candidate);
        if (s.isFile()) return await send(res, candidate);
      } catch {}
    }
    // Fallback SPA -> index.html
    await send(res, join(root, 'index.html'));
  } catch (err) {
    res.writeHead(500); res.end(String(err.message));
  }
}).listen(port, '127.0.0.1', () => console.log(`SPA server on http://127.0.0.1:${port} (root=${root})`));
