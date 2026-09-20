#!/bin/bash
# =============================================================================
# FrancosVox — INSTALADOR COMPLETO (tudo em um comando)
#
#   Uso (a partir do repo):
#     bash scripts/install.sh
#
#   Ou direto do GitHub (sem clonar na mão):
#     bash -c "$(curl -fsSL https://raw.githubusercontent.com/FrancosCorporation/FrancosVox/main/scripts/install.sh)"
#
# Faz, automaticamente:
#   1. Dependências do sistema (ydotool, wl-clipboard, GTK, appindicator, venv)
#   2. Voxtype (.deb oficial) + modelo Whisper large-v3-turbo (GPU Vulkan)
#   3. Tradutor local (venv isolado + LibreTranslate + modelos Argos)
#   4. ydotool daemon (serviço systemd, inicia sozinho)
#   5. apply.sh (OSD, atalho Ctrl+Shift+Espaço, bandeja, autostarts, menu)
#
# Idempotente: pode rodar de novo que ele só completa o que falta.
# =============================================================================
set -u

REPO_URL="https://github.com/FrancosCorporation/FrancosVox.git"
TRANSLATOR_DIR="$HOME/.local/voxtype-translator"
VOXTYPE_DEB_URL="https://github.com/woheller69/voxtype/releases/latest/download/voxtype_amd64.deb"

ok()   { echo -e "\033[1;32m✅ $*\033[0m"; }
info() { echo -e "\033[1;36mℹ️  $*\033[0m"; }
warn() { echo -e "\033[1;33m⚠️  $*\033[0m"; }
die()  { echo -e "\033[1;31m❌ $*\033[0m"; exit 1; }

need_sudo() {
    sudo -n true 2>/dev/null || {
        info "Vou pedir a senha do sudo (para instalar dependências e o daemon)."
        sudo true || die "sudo necessário para continuar."
    }
}

info "=== FrancosVox — instalador completo ==="
[ "$(uname -m)" = "x86_64" ] || die "Este instalador suporta x86_64 (seu sistema: $(uname -m))"

# ---------------------------------------------------------------------------
# 0) Bootstrap: rodando sem checkout (curl | bash / bash -c), clona e re-executa
#    Sem isso, `${BASH_SOURCE[0]}` nem existe sob `set -u` e o comando "tudo em
#    um" do README falhava antes de instalar qualquer coisa.
# ---------------------------------------------------------------------------
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
    [ -f "$_dir/apply.sh" ] && SCRIPT_DIR="$_dir"
fi
if [ -z "$SCRIPT_DIR" ]; then
    info "[0/5] Sem checkout local — preparando o repositório..."
    need_sudo
    command -v git >/dev/null 2>&1 || sudo apt-get install -y -qq git || die "Falha ao instalar o git"
    REPO_DIR="${FRANCOSVOX_DIR:-$HOME/Git/voxtype-br}"
    if [ -d "$REPO_DIR/.git" ]; then
        git -C "$REPO_DIR" pull --ff-only 2>/dev/null || warn "Não consegui atualizar o repo — usando o existente."
    else
        mkdir -p "$(dirname "$REPO_DIR")"
        git clone --depth 1 "$REPO_URL" "$REPO_DIR" || die "Falha ao clonar $REPO_URL"
    fi
    exec bash "$REPO_DIR/scripts/install.sh"
fi

ROOT_DIR="$(dirname "$SCRIPT_DIR")"
USER_NAME="$(id -un)"
USER_GROUP="$(id -gn)"
info "Usuário: $USER_NAME | Repo: $ROOT_DIR"

need_sudo

# ---------------------------------------------------------------------------
# 1) Dependências do sistema
# ---------------------------------------------------------------------------
info "[1/5] Dependências do sistema (apt)..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    ydotool wl-clipboard \
    python3-gi python3-gi-cairo gir1.2-gtk-3.0 python3-cairo \
    gir1.2-ayatanaappindicator3-0.1 python3-venv python3-pip \
    curl wget x11-utils ca-certificates
# wtype quebra a colagem no GNOME Wayland — remove se estiver instalado
if dpkg -s wtype >/dev/null 2>&1; then
    warn "Removendo wtype (incompatível com GNOME Wayland — travava a colagem)..."
    sudo apt-get remove -y -qq wtype
fi
ok "Dependências do sistema instaladas."

# ---------------------------------------------------------------------------
# 2) Voxtype + modelo Whisper
# ---------------------------------------------------------------------------
info "[2/5] Voxtype (binário oficial) + modelo Whisper..."
if ! command -v voxtype >/dev/null 2>&1; then
    info "Baixando Voxtype (.deb)..."
    DEB="/tmp/voxtype_amd64.deb"
    curl -fsSL -o "$DEB" "$VOXTYPE_DEB_URL" || die "Falha ao baixar o Voxtype"
    sudo dpkg -i "$DEB" >/dev/null 2>&1 || sudo apt-get install -f -y -qq >/dev/null 2>&1
    rm -f "$DEB"
    command -v voxtype >/dev/null 2>&1 || die "Falha ao instalar o Voxtype"
    ok "Voxtype instalado."
else
    ok "Voxtype já instalado ($(command -v voxtype))."
fi
if [ ! -f "$HOME/.local/share/voxtype/models/ggml-large-v3-turbo.bin" ]; then
    info "Baixando modelo large-v3-turbo (~1,6 GB, uma vez só)..."
    voxtype setup --download --model large-v3-turbo || die "Falha ao baixar o modelo"
fi
ok "Modelo Whisper pronto."

# ---------------------------------------------------------------------------
# 3) Tradutor local (LibreTranslate + Argos, offline, sob demanda)
# ---------------------------------------------------------------------------
info "[3/5] Tradutor local (venv isolado)..."
if [ ! -x "$TRANSLATOR_DIR/bin/libretranslate" ]; then
    info "Criando venv e instalando LibreTranslate (pode demorar um pouco)..."
    python3 -m venv "$TRANSLATOR_DIR"
    "$TRANSLATOR_DIR/bin/pip" install -q libretranslate || die "Falha ao instalar o LibreTranslate"
    ok "LibreTranslate instalado."
else
    ok "LibreTranslate já instalado."
fi
export PATH="$TRANSLATOR_DIR/bin:$PATH"
for pair in pt_en pt_es en_pt es_pt en_fr en_de en_it; do
    if ! "$TRANSLATOR_DIR/bin/argospm" list 2>/dev/null | grep -q "translate-$pair"; then
        info "Modelo de tradução $pair..."
        "$TRANSLATOR_DIR/bin/argospm" install "translate-$pair" >/dev/null 2>&1 \
            || warn "Falha ao instalar modelo $pair (pode tentar depois: argospm install translate-$pair)"
    fi
done
ok "Tradutor local pronto."

# ---------------------------------------------------------------------------
# 4) ydotool daemon (injeção de teclas no Wayland)
# ---------------------------------------------------------------------------
info "[4/5] Daemon do ydotool (inicia sozinho)..."
sudo usermod -aG input "$USER_NAME" 2>/dev/null
sudo tee /etc/systemd/system/ydotoold.service >/dev/null <<EOF
[Unit]
Description=ydotool daemon (injeção de teclas — FrancosVox)
After=systemd-user-sessions.service

[Service]
ExecStart=/usr/bin/ydotoold -o $USER_NAME:$USER_GROUP -P 0666
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now ydotoold >/dev/null 2>&1
systemctl is-active ydotoold >/dev/null 2>&1 || sudo systemctl start ydotoold
ok "ydotoold ativo como serviço do sistema."

# ---------------------------------------------------------------------------
# 5) apply.sh — OSD, atalho, bandeja, autostarts, menu
# ---------------------------------------------------------------------------
info "[5/5] Aplicando FrancosVox no sistema (OSD, atalho, bandeja, autostarts)..."
bash "$SCRIPT_DIR/apply.sh" || die "Falha no apply.sh"
ok "FrancosVox aplicado."

# ---------------------------------------------------------------------------
# Grupo 'input' só vale após logout/login
# ---------------------------------------------------------------------------
if ! id -nG | grep -q "\binput\b"; then
    warn "Você entrou no grupo 'input' (necessário para injetar teclas)."
    warn "Faça LOGOUT e login novamente para valer — depois é só usar Ctrl+Shift+Espaço."
else
    ok "Tudo pronto! Clique numa caixa de texto e use Ctrl+Shift+Espaço."
fi

echo ""
info "Resumo:"
echo "   Atalho:      Ctrl+Shift+Espaço (1ª = grava, 2ª = cola)"
echo "   Painel:      busque 'FrancosVox' no menu do GNOME"
echo "   Ícone:       barra superior (estado + menu)"
echo "   Logs:        tail -f /tmp/francosvox.log"
echo "   Reinstalar:  bash $ROOT_DIR/scripts/install.sh"