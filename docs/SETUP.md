# 📖 Guia de Instalação Completo

Setup do Voxtype para ditado em Português do Brasil com GPU e Wayland.

---

## 1. Instalar o Voxtype

```bash
# Download do .deb (versão 0.7.1+)
wget https://github.com/woheller69/voxtype/releases/latest/download/voxtype_amd64.deb
sudo dpkg -i voxtype_amd64.deb
# Se der erro de dependência:
sudo apt-get install -f
```

Verifique:
```bash
voxtype --version  # deve retornar 0.7.1+
```

---

## 2. Dependências do sistema

```bash
# ydotool (injeção de teclas no Wayland — funciona no GNOME)
sudo apt install ydotool

# OSD visual (GTK3 + cairo + conversor gi-cairo)
sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0 python3-cairo

# Clipboard fallback
sudo apt install wl-clipboard
```

> ⚠️ **Remova o `wtype`** se estiver instalado: ele é incompatível com o GNOME
> Wayland (protocolo virtual-keyboard não suportado) e, na colagem, o Voxtype
> tentava usá-lo primeiro — o que **travava a colagem por ~1 minuto**:
> ```bash
> sudo apt remove wtype
> ```

---

## 3. Baixar o modelo pt-BR (large-v3-turbo)

```bash
# Baixa e configura automaticamente
voxtype setup --download --model large-v3-turbo
```

O modelo (~1.6 GB) fica em `~/.local/share/voxtype/models/ggml-large-v3-turbo.bin`.

> **Alternativa menor (mais rápida, menos precisa):** `voxtype setup --download --model small`

---

## 4. Aplicar a configuração FrancosVox

```bash
bash scripts/apply.sh
```

O instalador cria o autostart, registra o atalho, instala o OSD e preserva os
idiomas escolhidos no painel quando atualiza a configuração. A saída padrão é
gravada em arquivo; `francosvox-toggle` aguarda o daemon voltar a `idle` e
então entrega a transcrição ao campo selecionado.

Pontos-chave da configuração do repositório:
```toml
[whisper]
model = "large-v3-turbo"
language = "pt"
gpu_isolation = false   # sem recarregar o modelo a cada ditado

[output]
mode = "file"
file_path = "/tmp/francosvox-transcript.txt"
driver_order = ["ydotool", "clipboard"]
pre_type_delay_ms = 800
```

Não substitua `mode = "file"` por `paste` sem também reconfigurar o wrapper de
atalho; o fluxo atual delega a inserção a `francosvox-toggle`.

---

## 5. Configurar o ydotool daemon

O `ydotool` injeta texto via kernel (uinput) — funciona em **qualquer** compositor Wayland.
O instalador configura o serviço `ydotoold` com socket `0600`, pertencente ao
usuário atual, em vez de expor a injeção de teclas a todos os usuários locais.
Para uma configuração manual temporária, use IDs numéricos e a mesma permissão:

```bash
USER_UID="$(id -u)"
USER_GID="$(id -g)"
sudo nohup ydotoold -o "$USER_UID:$USER_GID" -P 0600 > /tmp/ydotoold.log 2>&1 &
ls -l /tmp/.ydotool_socket
```

Não use `0666`: o socket controla a injeção de teclado e mouse no desktop.

> 💡 **Por que `wtype` não funciona no GNOME?** O wtype usa o protocolo
> `zwp_virtual_keyboard_v1`, que o **GNOME não implementa**. O ydotool contorna
> isso usando `uinput` (nível de kernel).

---

## 6. Instalar o OSD visual

`scripts/apply.sh` instala `bin/francosvox-osd` e cria o alias `voxtype-osd`
que o daemon espera encontrar no `PATH`.
O OSD é um **overlay na tela** (parte inferior central) com:
- 🎙 speaker + ondas vermelhas animadas **conforme o volume da voz**
- ⏳ "Transcrevendo..." em azul com borda pulsante
- some quando idle
- **nunca rouba o foco**: `accept_focus(False)` + click-through — o texto cola
  na caixa de diálogo onde você estava

---

## 7. Atalho global (GNOME, sem logout)

```bash
bash scripts/setup-gnome-shortcut.sh
```

Isso registra **Ctrl+Shift+Espaço → `francosvox-toggle`** (wrapper com debounce,
recuperação do daemon e trava durante a transcrição).

Modo **toggle**:
1. Clique no campo onde quer digitar
2. Pressiona `Ctrl+Shift+Espaço` → começa a gravar
3. Fala normalmente
4. Pressiona de novo → para, transcreve e **cola no cursor** (não clique em
   outro lugar até o OSD azul sumir; se cair na janela errada, clique na caixa
   certa e dê `Ctrl+V` — o texto continua no clipboard)

> 💡 O hotkey embutido do voxtype requer o grupo `input` (evdev), que só ativa
> após logout. O atalho do GNOME contorna isso — funciona imediatamente.

---

## 8. Iniciar com GPU

> **Importante:** em instalações via `.deb`, o `/usr/bin/voxtype` é um **symlink**
> para um binário em `/usr/lib/voxtype/` (avx2/avx512 = CPU, vulkan = GPU).
> A variável `VOXTYPE_GPU=1` **não ativa GPU no .deb** — ela só funciona no
> wrapper do AppImage. Para ativar a GPU no .deb use o comando oficial:

```bash
# 1. (uma única vez) Ativa GPU permanentemente — troca o symlink para voxtype-vulkan
sudo voxtype setup gpu --enable

# 2. Inicia com o script (ele executa /usr/lib/voxtype/voxtype-vulkan diretamente)
bash scripts/francosvox-start
```

O script `francosvox-start` detecta e usa o binário Vulkan automaticamente, mesmo
sem rodar o `setup gpu` (não precisa de sudo). Verifique que a GPU foi usada:

```bash
tail -f /tmp/francosvox.log
# ggml_vulkan: 0 = AMD Radeon RX 6750 XT (RADV NAVI22) (radv)
# whisper_init_with_params_no_state: use gpu = 1
```

Para voltar para CPU: `sudo voxtype setup gpu --disable`

---

## 9. Autostart (automático pelo apply.sh)

O `scripts/apply.sh` instala quatro autostarts no login: daemon, atualização do
repositório, indicador da bandeja e tradutor local. Para recriá-los, rode
`bash scripts/apply.sh`; não copie um `.desktop` manual antigo com caminhos de
usuário fixos. O daemon usa `scripts/francosvox-start` e aguarda o `ydotoold`.

---

## 10. Teste rápido

```bash
# 1. Confira o daemon
voxtype status  # deve mostrar "idle"

# 2. Grave um áudio de teste manualmente
voxtype record toggle   # fala algo...
voxtype record toggle   # para e transcreve

# 3. O texto aparece no cursor (ou no clipboard como fallback)
```

O log atual do wrapper fica em `/tmp/francosvox.log`.

---

## ✅ Checklist final

- [ ] `voxtype --version` → 0.7.1+
- [ ] Modelo `large-v3-turbo` em `~/.local/share/voxtype/models/`
- [ ] `dotool_xkb_layout = "br"` no config
- [ ] `ydotoold` rodando + socket acessível
- [ ] Atalho `Ctrl+Shift+Espaço` configurado no GNOME
- [ ] `sudo voxtype setup gpu --enable` ou `francosvox-start` → log mostra Vulkan device
- [ ] `francosvox-osd` e o alias `voxtype-osd` estão em `~/.local/bin/`
