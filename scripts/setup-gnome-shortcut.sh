#!/bin/bash
# setup-gnome-shortcut.sh — Configura o atalho global Ctrl+Shift+Espaço no GNOME.
# Funciona no GNOME Wayland (sem precisar logout/login).
set -e

SHORTCUT_NAME="FrancosVox Ditado"
SHORTCUT_BINDING="<Ctrl><Shift>space"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYBINDING="$SCRIPT_DIR/francosvox-keybinding"

# Instala o wrapper (debounce + trava durante transcrição) no PATH do usuário
mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR/francosvox-toggle" "$HOME/.local/bin/francosvox-toggle"
cp "$SCRIPT_DIR/francosvox-keybinding" "$HOME/.local/bin/francosvox-keybinding"
chmod +x "$HOME/.local/bin/francosvox-toggle" "$HOME/.local/bin/francosvox-keybinding"
SHORTCUT_CMD="$HOME/.local/bin/francosvox-toggle"

echo "🎯 Configurando atalho: Ctrl+Shift+Espaço → $SHORTCUT_CMD"

# O helper MESCLA na lista de custom-keybindings (não apaga os atalhos do usuário)
python3 "$KEYBINDING" set "$SHORTCUT_BINDING"

echo "✅ Atalho configurado!"
echo "   $SHORTCUT_NAME: Ctrl+Shift+Espaço"
echo "   Comando: $SHORTCUT_CMD"
echo ""
echo "   Dica: para trocar o atalho, abra Configurações → Teclado → Atalhos → Atalhos personalizados"