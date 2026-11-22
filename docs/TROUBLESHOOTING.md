# 🔧 Solução de Problemas

Guia de diagnóstico dos erros mais comuns do Voxtype em pt-BR/Wayland.

---

## 1. "Letras viram `:`" ou caracteres trocados

**Causa:** o ydotool usa keymap US por padrão. Em teclado ABNT2, caracteres
como `;` → `:`, e acentos/`ç` saem errados.

**Fix:**
```toml
# ~/.config/voxtype/config.toml
[output]
dotool_xkb_layout = "br"
```

Depois reinicie: `bash scripts/voxtype-start`

---

## 2. Não digita no cursor — só mostra um card/notificação

**Causa:** o `wtype` falha no GNOME Wayland
(`Compositor does not support the virtual keyboard protocol`), então o voxtype
cai no fallback de clipboard + notificação.

**Diagnóstico:**
```bash
tail -30 /tmp/voxtype.log
# wtype failed: Compositor does not support the virtual keyboard protocol
```

**Fix:** usar ydotool como driver principal e **remover o `wtype`** (ele é
incompatível com o GNOME Wayland — ver seção 12):
```toml
driver_order = ["ydotool", "clipboard"]
```

E garantir o daemon do ydotool rodando:
```bash
sudo nohup ydotoold -o $USER:$USER -P 0666 > /tmp/ydotoold.log 2>&1 &
```

---

## 3. Transcrição demora muito (CPU subindo)

**Causa:** no pacote `.deb`, `/usr/bin/voxtype` é um symlink para o binário CPU
(`voxtype-avx2`/`voxtype-avx512`). A variável `VOXTYPE_GPU=1` **não ativa GPU no
.deb** — ela só funciona no wrapper do AppImage.

**Fix:** ativar a GPU Vulkan (uma única vez):
```bash
sudo voxtype setup gpu --enable
```

Ou use o `scripts/voxtype-start`, que executa `/usr/lib/voxtype/voxtype-vulkan`
diretamente (sem sudo).

Confira no log:
```
ggml_vulkan: Found 1 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon RX 6750 XT (RADV NAVI22) (radv)
whisper_init_with_params_no_state: use gpu = 1
```

Se aparecer `no GPU found`, seu driver Vulkan não está instalado:
```bash
sudo apt install mesa-vulkan-drivers  # AMD/Intel
# ou
sudo apt install nvidia-driver-545    # NVIDIA
```

Se o binário `voxtype-vulkan` não existir em `/usr/lib/voxtype/`, instale o
pacote que o inclui ou use o AppImage:
```bash
ls -la /usr/lib/voxtype/
```

---

## 4. `voxtype-osd` não aparece

**Verificar:**
```bash
which voxtype-osd   # precisa estar no PATH
ls ~/.local/bin/voxtype-osd
```

**Erro no log:** `Failed to spawn voxtype-osd: No such file or directory`

**Fix:**
```bash
cp bin/voxtype-osd ~/.local/bin/
chmod +x ~/.local/bin/voxtype-osd
export PATH="$HOME/.local/bin:$PATH"   # adicione ao ~/.bashrc
```

---

## 5. OSD roda mas com erros de `cairo.Context`

**Causa:** PyGObject precisa do módulo cairo registrado explicitamente.

**Fix:** o script já importa `import cairo`. Garanta o pacote:
```bash
sudo apt install python3-cairo
```

---

## 6. `ydotoold: failed to open uinput device: Permission denied`

**Causa:** o daemon não tem acesso a `/dev/uinput`.

**Fix:** rodar como root (recomendado para uso desktop):
```bash
sudo nohup ydotoold -p /run/user/$UID/.ydotool_socket -o $UID:$UID -P 0666 > /tmp/ydotoold.log 2>&1 &
```

Alternativa sem root (exige logout): adicionar ao grupo `input`:
```bash
sudo usermod -aG input $USER
# e reiniciar a sessão
```

---

## 7. Atalho não funciona (hotkey embutido)

**Causa:** o hotkey embutido usa evdev (`/dev/input/`) e o usuário não está no
grupo `input` (só ativa após logout).

**Fix:** usar atalho do GNOME apontando para `voxtype record toggle`:
```bash
bash scripts/setup-gnome-shortcut.sh
```

---

## 8. O texto cola no lugar errado (não no cursor) / a caixa perde a seleção

**Como funciona:** o voxtype injeta na **janela focada no momento da injeção**,
não na que estava focada quando você começou a gravar. Se a transcrição demora
(CPU: 60–120 s com `large-v3-turbo`) e você clica em outro lugar no meio do
caminho, o texto cai lá.

**O que este repo já faz por você:**
- OSD no **topo da tela** (nunca cobre a caixa de diálogo) + **click-through**
  (cliques atravessam) + nunca rouba o foco — a seleção do campo se mantém.
- `mode = "paste"`: colagem atômica via Ctrl+V (instantânea; o modo `type`
  tecla por tecla é lento e qualquer clique no meio joga o resto na janela errada).
- `pre_type_delay_ms = 450`: espera você soltar o Ctrl+Shift e o foco assentar.
- `driver_order` sem `wtype` (nunca funciona no GNOME; só atrasava e poluía o log).
- Atalho via `voxtype-toggle`: ignora toques durante a transcrição (em vez de
  parecer "travado") e tem debounce contra disparo duplo.

**Fluxo correto:**
1. Clique no campo onde quer digitar
2. `Ctrl+Shift+Espaço` → grava (OSD vermelho no topo)
3. `Ctrl+Shift+Espaço` → transcreve (OSD azul) e cola **sem clicar em outro
   lugar até o OSD sumir**
4. Se caiu na janela errada: clique na caixa certa e dê `Ctrl+V` — a transcrição
   continua no clipboard (rede de segurança).

---

## 9. Modelo `large-v3-turbo` demora para carregar na 1ª vez

É normal: são 1.6 GB. Na CPU ~7s, na GPU ~1s.
Se carregar toda vez, use `gpu_isolation = false` (mantém o modelo na memória):
```toml
[whisper]
gpu_isolation = false
```

---

## 10. Transcrição no idioma errado

**Fix:**
```toml
[whisper]
language = "pt"
```

---

## 11. Atalho: 2º toque não finaliza / não digita o texto

**Sintoma:** `Ctrl+Shift+Espaço` começa a gravação, mas o 2º toque não para
nem cola o texto.

**Causas mais comuns:**

1. **Transcrição lenta na CPU** — com `large-v3-turbo` (~1.6 GB) na CPU, a
   transcrição leva 60-120 s (parece que "não finaliza"). Com GPU leva ~1 s.
   → Veja a seção 3 (GPU).

2. **Daemon não está rodando** — o comando `voxtype record toggle` exige o
   daemon vivo (lê `voxtype.lock`). O atalho do GNOME roda sem terminal, então
   o erro fica invisível. Verifique:
   ```bash
   voxtype status              # "not running"?
   ls -la /run/user/$UID/voxtype/voxtype.lock
   tail -50 /tmp/voxtype.log   # se o daemon morreu, veja o motivo
   ```

3. **Estado travado em "transcribing"** — se uma transcrição anterior travou,
   o toggle manda `SIGUSR1` (start), que é ignorado fora do estado idle, e nada
   acontece. Resete:
   ```bash
   echo idle > /run/user/$UID/voxtype/state
   bash scripts/voxtype-start   # reinicia o daemon limpo
   ```

4. **Duas instâncias do daemon** — o `voxtype-start` já mata as antigas pelo
   lockfile; se você roda o daemon via systemd **e** pelo script ao mesmo tempo,
   pode haver conflito. Prefira um só método de inicialização.

---

## 12. Colagem demora ~1 minuto (ou parece travada em "Transcrevendo")

**Sintoma:** a transcrição termina rápido, mas o texto só aparece (ou não
aparece) ~50s depois; o estado fica preso em `transcribing`; o texto acaba
colando na janela errada porque você já clicou em outro lugar.

**Causa:** o `wtype` está instalado. Na colagem, o Voxtype tenta enviar o
`Ctrl+V` primeiro via `wtype`, que é **incompatível com o GNOME Wayland**
(protocolo virtual-keyboard não suportado) e faz a injeção travar.

**Fix:**
```bash
sudo apt remove wtype
bash scripts/voxtype-start   # reinicia o daemon
```

Depois disso a colagem é via **ydotool** e leva ~1,5s (confira com
`tail -f /tmp/voxtype.log` — "Text pasted via clipboard + ctrl+v" logo após
"Transcribed").

---

## 13. Modelo de voz ausente

O modelo `large-v3-turbo` é necessário para transcrever e ocupa cerca de 1,6 GB.
O `francosvox-start`, usado no login e no reinício manual, verifica o arquivo
`~/.local/share/voxtype/models/ggml-large-v3-turbo.bin` antes de iniciar o
daemon. Se estiver ausente ou vazio, baixa-o com `voxtype setup` e só continua
quando o arquivo estiver disponível. No primeiro início após a perda do modelo,
o download pode demorar conforme a conexão; o atalho avisa e aguarda até 20 min.

Para acompanhar ou diagnosticar:

```bash
ls -lh ~/.local/share/voxtype/models/ggml-large-v3-turbo.bin
tail -f /tmp/francosvox.log
tail -f /tmp/francosvox-model-download.log
voxtype status
```

O log de download deve terminar com `Setup complete`; o log do daemon deve
mostrar `Model loaded, ready for voice input`. Se aparecer falha de download,
confira a conexão e execute novamente:

```bash
bash ~/.local/bin/francosvox-start
```

O script não inicia reconhecimento sem o arquivo. Se ele existir mas o log
indicar erro ao carregá-lo, o arquivo pode estar incompleto ou corrompido;
consulte o log antes de qualquer ação manual no arquivo.

## 14. Comandos úteis

```bash
voxtype config        # mostra configuração ativa
voxtype status        # estado do daemon (idle/recording/transcribing)
voxtype setup check   # diagnóstico completo do sistema
voxtype record toggle # gravar/parar manualmente
tail -f /tmp/voxtype.log  # logs do daemon
tail -f /tmp/ydotoold.log # logs do ydotool
```
