// Servidor HTTP de transcrição usando voxtype (whisper.cpp + GPU Vulkan).
// POST /transcribe JSON { audio_base64: "<WAV em base64>" } -> { text, language, ms }
// Por padrão escuta apenas no loopback. Um bind externo exige WHISPER_TOKEN.
const http = require('http');
const { execFile } = require('child_process');
const { promisify } = require('util');
const crypto = require('crypto');
const net = require('net');
const fs = require('fs');
const os = require('os');
const path = require('path');

const execFileAsync = promisify(execFile);
const HOST = process.env.WHISPER_HOST || '127.0.0.1';
const PORT = Number(process.env.WHISPER_PORT || 3003);
const API_TOKEN = process.env.WHISPER_TOKEN || '';
const API_TOKEN_BUFFER = Buffer.from(API_TOKEN);
const MAX_QUEUE = 5;
const MAX_AUDIO_BYTES = 20 * 1024 * 1024;
const MAX_BASE64_CHARS = Math.ceil(MAX_AUDIO_BYTES / 3) * 4;
const MAX_BODY_BYTES = MAX_BASE64_CHARS + 1024;

if (!Number.isInteger(PORT) || PORT < 1 || PORT > 65535) {
  throw new Error('WHISPER_PORT precisa ser um inteiro entre 1 e 65535.');
}

function isLoopbackHost(host) {
  if (host.toLowerCase() === 'localhost') return true;
  const family = net.isIP(host);
  return (family === 4 && host.startsWith('127.')) || (family === 6 && host === '::1');
}

const REMOTE_BIND = !isLoopbackHost(HOST);
if (REMOTE_BIND && API_TOKEN_BUFFER.length < 32) {
  throw new Error('WHISPER_TOKEN com pelo menos 32 bytes é obrigatório para bind fora do loopback.');
}

// Resolve o binário com GPU. Em instalações .deb o /usr/bin/voxtype é um
// symlink para o binário CPU; a GPU só roda com o binário Vulkan direto.
const VULKAN_CANDIDATES = [
  '/usr/lib/voxtype/voxtype-vulkan',
  '/usr/local/lib/voxtype/voxtype-vulkan',
  `${process.env.HOME}/.local/lib/voxtype/voxtype-vulkan`,
];
const VOXTYPE_BIN = (() => {
  for (const candidate of VULKAN_CANDIDATES) {
    try {
      fs.accessSync(candidate, fs.constants.X_OK);
      return candidate;
    } catch {}
  }
  return 'voxtype';
})();

let busy = false;
const queue = [];

function sendJson(res, status, payload) {
  if (res.destroyed || res.writableEnded) return;
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  res.end(JSON.stringify(payload));
}

function authorized(req) {
  if (!REMOTE_BIND) return true;
  const authorization = req.headers.authorization || '';
  const match = /^Bearer ([^\s]+)$/.exec(authorization);
  if (!match) return false;
  const candidate = Buffer.from(match[1]);
  return candidate.length === API_TOKEN_BUFFER.length
    && crypto.timingSafeEqual(candidate, API_TOKEN_BUFFER);
}

function decodeWav(audioBase64) {
  if (typeof audioBase64 !== 'string' || audioBase64.length === 0) {
    throw new Error('audio_base64 obrigatório');
  }
  if (audioBase64.length > MAX_BASE64_CHARS || audioBase64.length % 4 !== 0
      || !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(audioBase64)) {
    throw new Error('audio_base64 inválido ou acima do limite');
  }

  const audio = Buffer.from(audioBase64, 'base64');
  if (audio.length < 44 || audio.length > MAX_AUDIO_BYTES
      || audio.toString('ascii', 0, 4) !== 'RIFF'
      || audio.toString('ascii', 8, 12) !== 'WAVE') {
    throw new Error('envie um arquivo WAV válido de até 20 MiB');
  }
  return audio;
}

function parseText(output) {
  const match = output.match(/Transcription completed in [\d.]+s:\s*"([^"]*)"(?:\n|$)/);
  if (match) return match[1].trim();
  const lines = output.split('\n').map(line => line.trim()).filter(Boolean);
  for (let i = lines.length - 1; i >= 0; i--) {
    if (!lines[i].includes('INFO') && !lines[i].includes('whisper_')
        && !lines[i].includes('ggml_') && lines[i] !== '.') {
      return lines[i];
    }
  }
  return '';
}

async function transcribe(audio) {
  const tmp = path.join(os.tmpdir(), `francosvox-${process.pid}-${crypto.randomBytes(16).toString('hex')}.wav`);
  fs.writeFileSync(tmp, audio, { flag: 'wx', mode: 0o600 });
  try {
    const startedAt = Date.now();
    const { stdout, stderr } = await execFileAsync(VOXTYPE_BIN, ['transcribe', tmp], {
      env: { ...process.env, VOXTYPE_GPU: '1' },
      timeout: 120000,
      maxBuffer: 20 * 1024 * 1024,
    });
    return { text: parseText(`${stdout}\n${stderr}`), ms: Date.now() - startedAt };
  } finally {
    try { fs.unlinkSync(tmp); } catch {}
  }
}

function processQueue() {
  if (busy || queue.length === 0) return;
  busy = true;
  const { res, audio } = queue.shift();
  transcribe(audio)
    .then(result => sendJson(res, 200, {
      ok: true,
      text: result.text,
      language: 'pt',
      ms: result.ms,
    }))
    .catch(error => {
      console.error('[whisper-http] transcrição falhou:', error);
      sendJson(res, 500, { ok: false, error: 'falha na transcrição' });
    })
    .finally(() => {
      busy = false;
      processQueue();
    });
}

const server = http.createServer((req, res) => {
  if (!authorized(req)) {
    sendJson(res, 401, { ok: false, error: 'não autorizado' });
    req.resume();
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end('ok');
    return;
  }

  if (req.method !== 'POST' || req.url !== '/transcribe') {
    sendJson(res, 404, { ok: false, error: 'não encontrado' });
    req.resume();
    return;
  }

  const contentType = (req.headers['content-type'] || '').split(';', 1)[0].trim().toLowerCase();
  if (contentType !== 'application/json') {
    sendJson(res, 415, { ok: false, error: 'use Content-Type: application/json' });
    req.resume();
    return;
  }

  const contentLength = Number(req.headers['content-length'] || 0);
  if (contentLength > MAX_BODY_BYTES) {
    sendJson(res, 413, { ok: false, error: 'corpo acima do limite de 20 MiB de áudio' });
    req.resume();
    return;
  }

  const chunks = [];
  let bodyBytes = 0;
  let rejected = false;
  req.on('data', chunk => {
    if (rejected) return;
    bodyBytes += chunk.length;
    if (bodyBytes > MAX_BODY_BYTES) {
      rejected = true;
      chunks.length = 0;
      sendJson(res, 413, { ok: false, error: 'corpo acima do limite de 20 MiB de áudio' });
      return;
    }
    chunks.push(chunk);
  });

  req.on('end', () => {
    if (rejected) return;
    let audio;
    try {
      const payload = JSON.parse(Buffer.concat(chunks).toString('utf8'));
      audio = decodeWav(payload.audio_base64);
    } catch (error) {
      sendJson(res, 400, { ok: false, error: error.message === 'audio_base64 obrigatório'
        ? error.message
        : 'JSON ou áudio inválido' });
      return;
    }

    if (queue.length >= MAX_QUEUE) {
      sendJson(res, 429, { ok: false, error: 'fila cheia, tente novamente' });
      return;
    }
    queue.push({ res, audio });
    processQueue();
  });
});

server.requestTimeout = 60000;
server.headersTimeout = 10000;
server.maxHeadersCount = 100;

server.listen(PORT, HOST, () => {
  console.log(`[whisper-http] ouvindo em ${HOST}:${PORT}${REMOTE_BIND ? ' (Bearer token obrigatório)' : ''}`);
});
