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

Depois reinicie: `bash scripts/francosvox-start`

---

## 2. Não digita no cursor — só mostra um card/notificação

**Causa:** o `wtype` falha no GNOME Wayland
(`Compositor does not support the virtual keyboard protocol`), então o voxtype
cai no fallback de clipboard + notificação.

**Diagnóstico:**
```bash
tail -30 /tmp/francosvox.log
# wtype failed: Compositor does not support the virtual keyboard protocol
```

**Fix:** usar ydotool como driver principal e **remover o `wtype`** (ele é
incompatível com o GNOME Wayland — ver seção 12):
```toml
driver_order = ["ydotool", "clipboard"]
```

E garantir o daemon do ydotool rodando:
```bash
sudo systemctl restart ydotoold
ls -l /tmp/.ydotool_socket
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

Ou use o `scripts/francosvox-start`, que executa `/usr/lib/voxtype/voxtype-vulkan`
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
cp bin/francosvox-osd ~/.local/bin/francosvox-osd
ln -sf francosvox-osd ~/.local/bin/voxtype-osd
chmod +x ~/.local/bin/francosvox-osd
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
sudo systemctl restart ydotoold
systemctl status ydotoold --no-pager
ls -l /tmp/.ydotool_socket
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

**Fix:** usar o atalho do projeto, que chama `francosvox-toggle`:
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
- OSD na **parte inferior central**; pode se sobrepor ao conteúdo, mas é click-through
  e não recebe foco.
- `mode = "file"`: a transcrição vai para arquivo; `francosvox-toggle` chama o helper de saída após o daemon voltar a idle. A inserção usa clipboard + Ctrl+V (o modo `type`
  tecla por tecla é lento e qualquer clique no meio joga o resto na janela errada).
- `pre_type_delay_ms = 800`: espera você soltar o Ctrl+Shift e o foco assentar.
- `driver_order` sem `wtype` (nunca funciona no GNOME; só atrasava e poluía o log).
- Atalho via `francosvox-toggle`: ignora toques durante a transcrição (em vez de
  parecer "travado") e tem debounce contra disparo duplo.

**Fluxo correto:**
1. Clique no campo onde quer digitar
2. `Ctrl+Shift+Espaço` → grava (OSD vermelho na parte inferior central)
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
   tail -50 /tmp/francosvox.log   # se o daemon morreu, veja o motivo
   ```

3. **Estado travado em "transcribing"** — se uma transcrição anterior travou,
   o toggle manda `SIGUSR1` (start), que é ignorado fora do estado idle, e nada
   acontece. Resete:
   ```bash
   echo idle > /run/user/$UID/voxtype/state
   bash scripts/francosvox-start   # reinicia o daemon limpo
   ```

4. **Duas instâncias do daemon** — o `francosvox-start` já mata as antigas pelo
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
bash scripts/francosvox-start   # reinicia o daemon
```

Depois disso a colagem é via **ydotool** e leva ~1,5s (confira com
`tail -f /tmp/francosvox.log` — "Text pasted via clipboard + ctrl+v" logo após
"Transcribed").

---

## 13. Comandos úteis

```bash
voxtype config        # mostra configuração ativa
voxtype status        # estado do daemon (idle/recording/transcribing)
voxtype setup check   # diagnóstico completo do sistema
voxtype record toggle # gravar/parar manualmente
tail -f /tmp/francosvox.log  # logs do daemon
tail -f /tmp/ydotoold.log # logs do ydotool
```
