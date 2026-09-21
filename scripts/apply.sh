#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

ok()   { echo "✅ $*"; }
info() { echo "ℹ️  $*"; }
warn() { echo "⚠️  $*" >&2; }

mkdir -p ~/.config/voxtype ~/.local/bin ~/.local/share/francosvox/assets

if [ -f ~/.config/voxtype/config.toml ]; then
    cp ~/.config/voxtype/config.toml ~/.config/voxtype/config.toml.bak.$(date +%Y%m%d-%H%M%S)
    info "Backup da config atual criado em ~/.config/voxtype/"
    # Preserva a escolha de idiomas do usuário ao instalar a config nova
    # (senão o auto-update no login apagaria a seleção de entrada/saída).
    python3 - "$ROOT_DIR/config/config.toml" <<'PYEOF'
import os, re, sys
new = sys.argv[1]
keys = ("source_language", "target_language", "language", "translate")
vals = {}
try:
    for line in open(os.path.expanduser("~/.config/voxtype/config.toml")):
        m = re.match(r"^\s*(" + "|".join(keys) + r")\s*=\s*\"?([^\"\s#]+)", line)
        if m:
            vals[m.group(1)] = m.group(2)
except OSError:
    pass
content = open(new).read()
# language SEMPRE = source_language (a entrada define a transcrição; a saída
# é traduzida depois pelo tradutor local).
if "source_language" in vals:
    vals["language"] = vals["source_language"]
vals["translate"] = "false"
for k, v in vals.items():
    val = v if k == "translate" else f'"{v}"'
    # Substitui a linha inteira do valor (descarta qualquer resto de aspas
    # corrompidas; o comentário original da linha é regenerado pela config).
    content = re.sub(rf"^({k}\s*=\s*)[^\n]*",
                     rf"\g<1>{val}", content, count=1, flags=re.M)
open(new, "w").write(content)
PYEOF
fi
cp "$ROOT_DIR/config/config.toml" ~/.config/voxtype/config.toml
ok "config.toml instalado em ~/.config/voxtype/ (idiomas do usuário preservados)"

cp "$ROOT_DIR/bin/francosvox-osd" ~/.local/bin/francosvox-osd
cp "$ROOT_DIR/scripts/francosvox-toggle" ~/.local/bin/francosvox-toggle
cp "$ROOT_DIR/scripts/francosvox-type" ~/.local/bin/francosvox-type
cp "$ROOT_DIR/scripts/francosvox-settings" ~/.local/bin/francosvox-settings
cp "$ROOT_DIR/scripts/francosvox-start" ~/.local/bin/francosvox-start
cp "$ROOT_DIR/scripts/francosvox-keybinding" ~/.local/bin/francosvox-keybinding
cp "$ROOT_DIR/scripts/francosvox-keys-reset" ~/.local/bin/francosvox-keys-reset
cp "$ROOT_DIR/scripts/francosvox-tray" ~/.local/bin/francosvox-tray
cp "$ROOT_DIR/scripts/francosvox-translate-start" ~/.local/bin/francosvox-translate-start
cp "$ROOT_DIR/scripts/notify-send-shim" ~/.local/bin/notify-send
chmod +x ~/.local/bin/francosvox-osd ~/.local/bin/francosvox-toggle ~/.local/bin/francosvox-type ~/.local/bin/francosvox-settings ~/.local/bin/francosvox-start ~/.local/bin/francosvox-keybinding ~/.local/bin/francosvox-keys-reset ~/.local/bin/francosvox-tray ~/.local/bin/francosvox-translate-start ~/.local/bin/notify-send

# Limpeza de nomes antigos (voxtype-*) + symlink exigido pelo daemon:
# o binário do Voxtype procura o OSD pelo nome hardcoded "voxtype-osd" no PATH.
rm -f ~/.local/bin/voxtype-toggle ~/.local/bin/voxtype-type ~/.local/bin/voxtype-settings \
      ~/.local/bin/voxtype-keys-reset ~/.local/bin/voxtype-tray ~/.local/bin/voxtype-start \
      ~/.local/bin/voxtype-translate-start ~/.local/bin/voxtype-autoupdate.sh
ln -sf francosvox-osd ~/.local/bin/voxtype-osd
rm -f ~/.config/autostart/voxtype.desktop ~/.config/autostart/voxtype-tray.desktop \
      ~/.config/autostart/voxtype-update.desktop ~/.config/autostart/voxtype-translate.desktop
# Remove SÓ os arquivos de marca antiga do voxtype (~/.local/share/voxtype);
# NUNCA a pasta inteira — ela contém os modelos do Whisper (1,6 GB).
rm -f ~/.local/share/voxtype/repo_path
rm -rf ~/.local/share/voxtype/assets

mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/francosvox-settings.desktop <<EOF
[Desktop Entry]
Type=Application
Name=FrancosVox
Comment=Configurações do ditado por voz (modo de saída)
Exec=$HOME/.local/bin/francosvox-settings
Icon=$HOME/.local/share/francosvox/assets/francosvox-icon.svg
Terminal=false
Categories=Utility;
EOF
ok "menu instalado (busque 'FrancosVox' no GNOME)"

cp -r "$ROOT_DIR/assets/"* ~/.local/share/francosvox/assets/
ok "assets instalados em ~/.local/share/francosvox/assets/"

mkdir -p ~/.local/share/francosvox
echo "$ROOT_DIR" > ~/.local/share/francosvox/repo_path
ok "caminho do repo registrado (auto-recuperação do atalho)"
ok "shim notify-send instalado (pop-up curto, sem roubar o foco)"

ok "francosvox-osd + francosvox-toggle instalados em ~/.local/bin/"

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) warn "~/.local/bin NÃO está no PATH. Adicione ao ~/.bashrc: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

bash "$SCRIPT_DIR/setup-gnome-shortcut.sh"

mkdir -p ~/.config/autostart
cat > ~/.config/autostart/francosvox-update.desktop <<EOF
[Desktop Entry]
Type=Application
Name=FrancosVox Autoupdate
Comment=Sincroniza FrancosVox do GitHub e reaplica no login (sem acao manual)
Exec=bash $ROOT_DIR/scripts/francosvox-autoupdate.sh $ROOT_DIR
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
ok "auto-update instalado (login aplica novidades sozinho)"

cat > ~/.config/autostart/francosvox.desktop <<EOF
[Desktop Entry]
Type=Application
Name=FrancosVox
Comment=Daemon de ditado por voz com GPU (Ctrl+Shift+Espaço)
Exec=bash -c 'for i in {1..30}; do pgrep -x ydotoold >/dev/null 2>&1 && break; sleep 1; done; exec bash $ROOT_DIR/scripts/francosvox-start'
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
ok "autostart do daemon instalado (sobe sozinho no login, aguarda ydotoold)"

cat > ~/.config/autostart/francosvox-tray.desktop <<EOF
[Desktop Entry]
Type=Application
Name=FrancosVox Tray
Comment=Ícone do FrancosVox na barra superior (estado do ditado)
Exec=bash -c 'sleep 2 && python3 $HOME/.local/bin/francosvox-tray'
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
ok "autostart do indicador de bandeja instalado (top bar)"

cat > ~/.config/autostart/francosvox-translate.desktop <<EOF
[Desktop Entry]
Type=Application
Name=FrancosVox Tradutor
Comment=Tradutor local do FrancosVox (libretranslate em localhost:5000)
Exec=bash $HOME/.local/bin/francosvox-translate-start
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
ok "autostart do tradutor local instalado (localhost:5000)"

bash "$SCRIPT_DIR/francosvox-start"

echo ""
echo "🔍 Conferindo se o instalado bate com o repo:"
for pair in "config/config.toml:$HOME/.config/voxtype/config.toml" "bin/francosvox-osd:$HOME/.local/bin/francosvox-osd" "scripts/francosvox-toggle:$HOME/.local/bin/francosvox-toggle"; do
    src="$ROOT_DIR/${pair%%:*}"; dst="${pair##*:}"
    if cmp -s "$src" "$dst"; then ok "$(basename "$dst") sincronizado"; else warn "$(basename "$dst") DIVERGENTE de $src"; fi
done
command -v francosvox-osd >/dev/null 2>&1 && ok "francosvox-osd no PATH" || warn "francosvox-osd fora do PATH (abra um novo terminal)"
echo ""
ok "Pronto. Teste: clique numa caixa de texto, Ctrl+Shift+Espaço, fale, Ctrl+Shift+Espaço."
