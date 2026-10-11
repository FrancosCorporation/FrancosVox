# API HTTP opcional

`whisper-http-server.js` recebe arquivos WAV para transcrição via Voxtype. Ele
escuta em `127.0.0.1:3003` por padrão, aceita uma transcrição por vez e mantém
no máximo cinco itens aguardando.

## Executar localmente

Use Node.js e mantenha o servidor no loopback:

```bash
node whisper-http-server.js
```

O `GET /health` retorna `ok`. Para transcrever, envie JSON com um WAV codificado
em base64. O limite do arquivo decodificado é 20 MiB:

```bash
curl --fail --silent --show-error \
  -H 'Content-Type: application/json' \
  --data-binary "{\"audio_base64\":\"$(base64 -w 0 exemplo.wav)\"}" \
  http://127.0.0.1:3003/transcribe
```

O arquivo temporário é criado com permissão `0600` e removido após o processo.
Respostas de erro não incluem detalhes internos do processo Voxtype.

## Escutar em outra interface

Um bind que não seja `localhost` ou loopback exige `WHISPER_TOKEN` com pelo
menos 32 bytes. Gere um token e inicie o servidor:

```bash
export WHISPER_HOST=0.0.0.0
export WHISPER_TOKEN="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
node whisper-http-server.js
```

Envie `Authorization: Bearer "$WHISPER_TOKEN"` tanto para `/transcribe` quanto
para `/health`. Não publique o token nem exponha o servidor diretamente à
Internet: use uma rede confiável, firewall e um proxy TLS quando o tráfego
precisar atravessar a rede.

Os limites de corpo, WAV e fila continuam ativos fora do loopback. A API não
habilita CORS; clientes de navegador precisam de um proxy ou integração de
mesma origem configurada pelo responsável pelo serviço.
