<p align="center">
  <img src="docs/imgs/voxtype-hero.png" alt="FrancosVox em ação" width="720"/>
</p>

<h1 align="center">FrancosVox 🇧🇷</h1>

<p align="center">
  <b>Ditado por voz (voice-to-text) em tempo real no Linux</b><br/>
  Português do Brasil • GPU (Vulkan) • GNOME Wayland • OSD com onda senoidal animada
</p>

<p align="center">
  <a href="LICENSE"><img alt="Licença MIT" src="https://img.shields.io/badge/licença-MIT-blue.svg"/></a>
  <a href="https://github.com/woheller69/voxtype"><img alt="Baseado no Voxtype" src="https://img.shields.io/badge/base-Voxtype%200.7.1%2B-4a4a4a.svg"/></a>
  <img alt="Plataforma" src="https://img.shields.io/badge/plataforma-Linux%20(GNOME%20Wayland)-informational.svg"/>
  <img alt="GPU" src="https://img.shields.io/badge/GPU-Vulkan-8a2be2.svg"/>
  <img alt="Modelo" src="https://img.shields.io/badge/Whisper-large--v3--turbo-00b4d8.svg"/>
</p>

---

## ✨ O que é

**FrancosVox** transforma o [Voxtype](https://github.com/woheller69/voxtype) em um
sistema de ditado completo para **Português do Brasil**:

1. Pressione `Ctrl+Shift+Espaço` — aparece o **OSD com speaker + onda senoidal** que se move conforme a sua voz
2. Fale normalmente
3. Pressione `Ctrl+Shift+Espaço` de novo — o texto é transcrito **na GPU** e **colado no cursor**, na caixa de diálogo onde você estava

| 🎙 Ouvindo (a onda reage à voz) | ⏳ Transcrevendo |
|---|---|
| ![Gravando](docs/imgs/francosvox-osd-recording.gif) | ![Transcrevendo](docs/imgs/francosvox-osd-transcribing.png) |

---

## ✅ O que este projeto resolve

| Problema do Voxtype original | Solução do FrancosVox |
|---|---|
| Modelo `.en` — transcrição ruim em pt-BR | `large-v3-turbo` + `language = "pt"` (multilíngue) |
| Transcrição na CPU demora 70s+ | **GPU Vulkan** (AMD/NVIDIA/Intel) — 6,5s de áudio transcritos em **~0,7s** |
| `wtype` falha no GNOME Wayland ("virtual keyboard protocol not supported") e **travava a colagem por ~1 minuto** | `wtype` removido; colagem via **ydotool + clipboard** em ~1,5s |
| Sem feedback visual de gravação | **OSD na tela**: speaker + onda senoidal animada conforme o volume da voz |
| Texto cola na janela errada | OSD **click-through, sem foco** (`accept_focus=False`), nunca rouba a caixa de diálogo |
| Teclas ABNT2 saem trocadas (`;` vira `:`) | Colagem **atômica via Ctrl+V** (nenhuma tecla é digitada) |
| Atalho morto após o reboot | **Autostart do daemon** no login + atalho que **auto-recupera** o daemon |
| 2º toque ignorado / disparo duplo | Wrapper `francosvox-toggle` com debounce e trava durante a transcrição |
| Tradução só para inglês (e instável) | **Tradutor local real** (LibreTranslate + Argos, offline): pt→en/es direto, fr/de/it via inglês |
| Não saber quando o daemon reinicia | **Loading no OSD** ("Reiniciando…" com anel girando) + **ícone na barra superior** com estado e ⟳ |
| RAM presa após uso | Tradutor **sob demanda**: modelo só carrega quando traduz (~128 MB) e o servidor **se auto-encerra após 10 min ocioso** |
| OSD aparece na dock como ícone genérico | OSD roda via **XWayland** — `skip-taskbar` funciona e a dock fica limpa |
| Onda do OSD congela após reinício | Limpeza do `audio.sock` órfão no start — conexão sempre renovada |

---

## 🖥️ Demonstração

O OSD fica ancorado na **parte inferior central** da tela — pequeno, nunca cobre
a caixa de diálogo e **não rouba o foco**:

- 🔴 **Ouvindo** — o speaker pulsa e a onda cresce conforme o volume da sua voz
- 🔵 **Transcrevendo** — borda azul pulsante + onda animada
- Some automaticamente quando idle

> O overlay usa `Gtk.WindowTypeHint.NOTIFICATION`, `set_accept_focus(False)` e
> input region vazia (click-through): cliques e foco **atravessam** o OSD.

---

## 📦 Componentes

| Arquivo | Função |
|---|---|
| `bin/francosvox-osd` | Overlay GTK3 com speaker + onda senoidal animada (sempre mapeado — não rouba o foco; rodado via XWayland para sumir da dock) |
| `config/config.toml` | Configuração pt-BR: GPU, modelo, idiomas de entrada/saída, saída em arquivo |
| `scripts/francosvox-start` | Inicia o daemon com o binário Vulkan (GPU), limpa socket órfão e garante o tradutor |
| `scripts/francosvox-toggle` | Wrapper do atalho: debounce, trava na transcrição, auto-recuperação do daemon |
| `scripts/francosvox-type` | **Cola a transcrição** (wl-copy + Ctrl+Shift+V por keycodes) e **traduz antes de colar** quando a saída é outro idioma |
| `scripts/francosvox-settings` | Painel de configuração: **entrada** (o que você fala) + **saída** (tradução), colar instantâneo × digitar — busque "FrancosVox" no menu |
| `scripts/francosvox-keybinding` | Aplica o atalho global **mesclando** na lista do GNOME (não apaga outros atalhos personalizados) |
| `scripts/francosvox-tray` | **Ícone na barra superior** (topo, ao lado do Bluetooth): estado 🎙/🎤/⏳, menu Configurações/Reiniciar daemon/Sair |
| `scripts/francosvox-translate-start` | Garante o tradutor local (LibreTranslate :5000) **sob demanda** — watchdog encerra após 10 min ocioso (libera RAM) |
| `scripts/francosvox-keys-reset` | Libera teclas injetadas que ficaram presas (anti-tecla-presa) |
| `scripts/setup-gnome-shortcut.sh` | Registra `Ctrl+Shift+Espaço` no GNOME |
| `scripts/install.sh` | **Instalador completo em 1 comando** (deps + Voxtype + modelo + tradutor + ydotoold + apply) |
| `scripts/apply.sh` | Sincroniza o repo → sistema (config, OSD, atalho, autostarts, menu) — **preserva seus idiomas** ao atualizar |
| `scripts/francosvox-autoupdate.sh` | Auto-update no login (pull + apply) |
| `whisper-http-server.js` | API HTTP `/transcribe` (opcional, para integrações) |

---

## 🚀 Instalação

### Tudo em UM comando (recomendado)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/FrancosCorporation/FrancosVox/main/scripts/install.sh)"
```

O instalador faz tudo sozinho (pode rodar de novo — só completa o que falta):

| Passo | O que faz |
|---|---|
| 1. Dependências | `ydotool`, `wl-clipboard`, GTK/AppIndicator, `venv` — e **remove o `wtype`** (incompatível com GNOME Wayland) |
| 2. Voxtype | Baixa o `.deb` oficial + modelo Whisper `large-v3-turbo` (GPU Vulkan) |
| 3. Tradutor | Venv isolado + LibreTranslate + modelos Argos (offline, sob demanda) |
| 4. ydotool | Serviço systemd — daemon de injeção de teclas inicia sozinho |
| 5. apply.sh | OSD, atalho `Ctrl+Shift+Espaço`, bandeja, autostarts, menu |

> Após o fim: **faça logout/login** (entra no grupo `input`) e é só usar.
> Instalação manual detalhada: veja as seções abaixo.

### 1. Voxtype + dependências

```bash
# Voxtype (0.7.1+)
wget https://github.com/woheller69/voxtype/releases/latest/download/voxtype_amd64.deb
sudo dpkg -i voxtype_amd64.deb && sudo apt-get install -f

# Dependências do sistema
sudo apt install ydotool wl-clipboard python3-gi python3-gi-cairo gir1.2-gtk-3.0 python3-cairo

# Modelo pt-BR (large-v3-turbo, ~1,6 GB)
voxtype setup --download --model large-v3-turbo
```

> ⚠️ **Remova o `wtype`** se instalado: ele é incompatível com o GNOME Wayland e
> fazia a colagem travar por ~1 minuto:
> ```bash
> sudo apt remove wtype
> ```

### 2. Este repositório

```bash
git clone https://github.com/FrancosCorporation/FrancosVox.git ~/Git/voxtype-br
cd ~/Git/voxtype-br
bash scripts/apply.sh        # instala config, OSD, atalho, autostart e inicia o daemon
```

### 2b. Tradutor local (para saída em outro idioma — en/es/fr/de/it)

```bash
# Instala o tradutor offline (LibreTranslate + modelos Argos) num venv isolado
python3 -m venv ~/.local/voxtype-translator
~/.local/voxtype-translator/bin/pip install libretranslate

# Modelos de tradução (pt-en/pt-es diretos; fr/de/it via inglês)
export PATH="$HOME/.local/voxtype-translator/bin:$PATH"
argospm install translate-pt_en translate-pt_es translate-en_pt translate-es_pt
argospm install translate-en_fr translate-en_de translate-en_it
```

> O tradutor é **sob demanda**: o modelo carrega só quando você dita com a saída
> em outro idioma e o servidor se auto-encerra após 10 min sem uso (~128 MB base,
> RAM devolvida ao sistema). O `apply.sh` já instala o autostart dele.

### 3. ydotool (injeção de teclas no Wayland)

```bash
sudo usermod -aG input $USER   # acesso ao /dev/uinput (logout/login)
sudo nohup ydotoold -o $USER:$USER -P 0666 > /tmp/ydotoold.log 2>&1 &
```

### 4. GPU (opcional, recomendado)

O `scripts/francosvox-start` detecta e usa `/usr/lib/voxtype/voxtype-vulkan`
automaticamente. Confirme no log:

```
ggml_vulkan: Found 1 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon RX 6750 XT (RADV NAVI22) (radv)
whisper_init_with_params_no_state: use gpu = 1
```

---

## 🎤 Como usar

1. Clique na caixa de texto (chat, e-mail, formulário…)
2. **`Ctrl+Shift+Espaço`** → OSD vermelho aparece ("Ouvindo...")
3. Fale naturalmente — o OSD reage à sua voz
4. **`Ctrl+Shift+Espaço`** → OSD azul ("Transcrevendo...") e o texto é colado no cursor
5. Se cair na janela errada: clique na caixa certa e dê `Ctrl+V` (o texto continua no clipboard)

> Durante a transcrição **não clique em outro lugar** — o texto cola na janela
> focada no momento da colagem.

---

## ⚙️ Configuração essencial

```toml
[whisper]
model = "large-v3-turbo"   # melhor equilíbrio pt-BR: qualidade × velocidade
source_language = "pt"     # idioma de ENTRADA (o que você fala): pt, en, es, fr, de, it, auto
target_language = "pt"     # idioma de SAÍDA (tradução): pt, en, es, fr, de, it
language = "pt"            # decode do Whisper = idioma de ENTRADA (escrito pelo painel)
translate = false          # IGNORADO por esta versão do Voxtype — fica false
gpu_isolation = false      # modelo fica na memória (sem recarregar a cada ditado)

[output]
mode = "file"              # o daemon grava a transcrição; quem cola é o francosvox-type
file_path = "/tmp/francosvox-transcript.txt"
```

> Os dois idiomas (entrada/saída) também são escolhidos pelo painel
> **FrancosVox** (menu do GNOME). A entrada define a transcrição (Whisper, na
> GPU); a saída é traduzida na hora de colar por um **tradutor local**
> (LibreTranslate + modelos Argos, offline em `localhost:5000`) — inglês e
> espanhol direto, francês/alemão/italiano via inglês (pt→en→fr, etc.).
> Ao aplicar uma mudança, o OSD mostra **"Reiniciando…"** (anel girando na
> pílula) e o ícone da barra superior vira **⟳** até o servidor voltar.

---

## 🧩 Requisitos

- Ubuntu 24.04+ / GNOME Wayland (X11 também funciona)
- Voxtype 0.7.1+ ([.deb](https://github.com/woheller69/voxtype/releases))
- `ydotool` + daemon `ydotoold` (injeção de teclas)
- GPU com driver Vulkan (recomendado) — AMD: `mesa-vulkan-drivers`
- Python 3 + venv para o tradutor local (só se usar saída traduzida)
- `gir1.2-ayatanaappindicator3-0.1` (ícone na barra superior)

---

## 🔍 Solução de problemas

| Sintoma | Causa / Fix |
|---|---|
| Atalho não faz nada após reboot | O daemon não subiu — o atalho agora **inicia sozinho** (`francosvox-toggle`); ou rode `bash scripts/francosvox-start` |
| Texto não cola na caixa | O ydotool desta versão **não injeta combinações nomeadas** (`key ctrl+shift+v`) — use keycodes brutos (`29:1 42:1 47:1 47:0 42:0 29:0`), já configurado |
| Texto cai em outra janela | O OSD ficava mapeando/desmapeando (mexia no foco) — agora fica sempre mapeado e transparente no idle |
| Teclas presas (Ctrl travado) | Injeção interrompida no meio — rode `bash francosvox-keys-reset` para liberar |
| Texto some na transcrição | O pop-up do GNOME rouba o foco do teclado — notificações desligadas (feedback pelo OSD) |
| Transcrição lenta (CPU 100%) | Confira que `francosvox-start` está usando o binário Vulkan (`grep -i vulkan /tmp/francosvox.log`) |
| Caracteres ABNT2 trocados | A colagem via clipboard não digita teclas — acentos saem corretos |
| Onda do OSD congelada | Socket de áudio órfão de um reinício corrido — rode `bash scripts/francosvox-start` (limpa o `audio.sock` e recria a conexão) |
| Saída traduzida cola o texto original | Tradutor local encerrado pelo watchdog (10 min ocioso) — ele **reinicia sozinho** no próximo ditado; se persistir, `bash ~/.local/bin/francosvox-translate-start` |

Mais detalhes em [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

---

## 🛠️ Desenvolvimento

```bash
git pull && bash scripts/apply.sh   # aplica mudanças do repo no sistema
tail -f /tmp/francosvox.log            # logs do daemon
python3 docs/generate_screenshots.py  # regenera os screenshots do README
```

---

## 🙏 Créditos

- [Voxtype](https://github.com/woheller69/voxtype) — ferramenta base de ditado push-to-talk
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) — motor de transcrição local (GPU Vulkan)

## 📄 Licença

MIT — use, modifique e compartilhe à vontade.