// Servidor HTTP de transcrição usando voxtype (whisper.cpp + GPU Vulkan).
// POST /transcribe  JSON { audio_base64: "..." }  -> { text, language, ms }
// Fila única: GPU processa 1 áudio por vez; fila limitada (rate limit).
const http = require('http');
const { execFile } = require('child_process');
const { promisify } = require('util');
const fs = require('fs');
const os = require('os');
const path = require('path');

const execFileAsync = promisify(execFile);
const PORT = process.env.WHISPER_PORT || 3003;
// Escuta só em localhost por padrão: o endpoint não tem autenticação e não
// deve ficar exposto na rede. Para expor de propósito, WHISPER_HOST=0.0.0.0.
const HOST = process.env.WHISPER_HOST || '127.0.0.1';
const MAX_QUEUE = 5;

// Resolve o binário com GPU. Em instalações .deb o /usr/bin/voxtype é um
// symlink para o binário CPU; a GPU só roda com o binário Vulkan direto
// (VOXTYPE_GPU=1 só funciona no wrapper do AppImage).
const VULKAN_CANDIDATES = [
  '/usr/lib/voxtype/voxtype-vulkan',
  '/usr/local/lib/voxtype/voxtype-vulkan',
  `${process.env.HOME}/.local/lib/voxtype/voxtype-vulkan`,
];
const VOXTYPE_BIN = (() => {
  for (const p of VULKAN_CANDIDATES) {
    try { fs.accessSync(p, fs.constants.X_OK); return p; } catch {}
  }
  return 'voxtype';
})();

let busy = false;
const queue = [];

function parseText(output) {
  const m = output.match(/Transcription completed in [\d.]+s:\s*"([^"]*)"(?:\n|$)/);
  if (m) return m[1].trim();
  const lines = output.split('\n').map(l => l.trim()).filter(Boolean);
  for (let i = lines.length - 1; i >= 0; i--) {
    if (!lines[i].includes('INFO') && !lines[i].includes('whisper_') && !lines[i].includes('ggml_') && lines[i] !== '.') {
      return lines[i];
    }
  }
  return '';
}

async function transcribe(audioBase64) {
  const tmp = path.join(os.tmpdir(), `wx_${Date.now()}_${Math.random().toString(36).slice(2)}.wav`);
  fs.writeFileSync(tmp, Buffer.from(audioBase64, 'base64'));
  try {
    const t0 = Date.now();
    const { stdout, stderr } = await execFileAsync(VOXTYPE_BIN, ['transcribe', tmp], {
      env: { ...process.env, VOXTYPE_GPU: '1' },
      timeout: 120000,
      maxBuffer: 20 * 1024 * 1024,
    });
    const text = parseText(stdout + '\n' + stderr);
    return { text, ms: Date.now() - t0 };
  } finally {
    try { fs.unlinkSync(tmp); } catch {}
  }
}

function processQueue() {
  if (busy || queue.length === 0) return;
  busy = true;
  const { req, res, audioBase64 } = queue.shift();
  transcribe(audioBase64)
    .then(r => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, text: r.text, language: 'pt', ms: r.ms }));
    })
    .catch(e => {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: false, error: e.message }));
    })
    .finally(() => { busy = false; processQueue(); });
}

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/transcribe') {
    let body = '';
    req.on('data', d => { body += d; if (body.length > 30 * 1024 * 1024) req.destroy(); });
    req.on('end', () => {
      try {
        const { audio_base64 } = JSON.parse(body || '{}');
        if (!audio_base64) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ ok: false, error: 'audio_base64 obrigatório' }));
        }
        if (queue.length >= MAX_QUEUE) {
          res.writeHead(429, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ ok: false, error: 'fila cheia, tente novamente' }));
        }
        queue.push({ req, res, audioBase64: audio_base64 });
        processQueue();
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: e.message }));
      }
    });
    return;
  }
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200); return res.end('ok');
  }
  res.writeHead(404); res.end();
});

server.listen(PORT, HOST, () => console.log(`[whisper-http] ouvindo em ${HOST}:${PORT}`));