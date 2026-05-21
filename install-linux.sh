#!/usr/bin/env bash
# install-linux.sh — instala statusline customizada do Claude Code (Linux/macOS)
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/frshaka/claude-statusline/main/install-linux.sh)

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/frshaka/claude-statusline/main"
STATUSLINE_URL="$REPO_RAW/statusline.sh"
TARGET_FILE="$HOME/.claude/statusline.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

# ── cores ─────────────────────────────────────────────────────────────────────
c_cyan=$'\033[36m'
c_green=$'\033[32m'
c_yellow=$'\033[33m'
c_reset=$'\033[0m'

step()  { printf '  → %s\n' "$*"; }
ok()    { printf '  %s✔%s %s\n' "$c_green" "$c_reset" "$*"; }
warn()  { printf '  %s⚠%s  %s\n' "$c_yellow" "$c_reset" "$*"; }
die()   { printf '\n  ✘ ERRO: %s\n\n' "$*" >&2; exit 1; }

printf '\n%s╔══════════════════════════════════════════════╗%s\n' "$c_cyan" "$c_reset"
printf '%s║   Claude Code — Instalador de Statusline     ║%s\n' "$c_cyan" "$c_reset"
printf '%s╚══════════════════════════════════════════════╝%s\n\n' "$c_cyan" "$c_reset"

# ── verifica dependências ─────────────────────────────────────────────────────
step "Verificando dependências..."

if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
    die "curl ou wget não encontrado. Instale um deles e tente novamente."
fi

if ! command -v jq &>/dev/null; then
    warn "jq não encontrado — tentando instalar..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y jq &>/dev/null && ok "jq instalado via apt." || \
            warn "Falha ao instalar jq. Usando fallback python3."
    elif command -v brew &>/dev/null; then
        brew install jq &>/dev/null && ok "jq instalado via brew." || \
            warn "Falha ao instalar jq. Usando fallback python3."
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y jq &>/dev/null && ok "jq instalado via dnf." || \
            warn "Falha ao instalar jq. Usando fallback python3."
    else
        warn "Gerenciador de pacotes não reconhecido. Usando fallback python3."
        if ! command -v python3 &>/dev/null; then
            die "Nem jq nem python3 disponíveis. Instale um deles."
        fi
    fi
fi

if ! command -v awk &>/dev/null; then
    die "awk não encontrado. Instale gawk ou mawk."
fi

ok "Dependências OK."

# ── cria diretório .claude ────────────────────────────────────────────────────
mkdir -p "$HOME/.claude"

# ── baixa statusline.sh ───────────────────────────────────────────────────────
step "Baixando statusline.sh..."

if command -v curl &>/dev/null; then
    curl -fsSL "$STATUSLINE_URL" -o "$TARGET_FILE" || die "Falha ao baixar $STATUSLINE_URL"
else
    wget -qO "$TARGET_FILE" "$STATUSLINE_URL" || die "Falha ao baixar $STATUSLINE_URL"
fi

chmod +x "$TARGET_FILE"
ok "statusline.sh instalado em $TARGET_FILE"

# ── atualiza settings.json ────────────────────────────────────────────────────
step "Atualizando settings.json..."

STATUS_LINE_CMD="bash \\\"$TARGET_FILE\\\""

if [ -f "$SETTINGS_FILE" ]; then
    # Faz backup
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"

    if command -v jq &>/dev/null; then
        tmp=$(mktemp)
        jq --arg cmd "bash \"$TARGET_FILE\"" \
           '.statusLine = {"type": "command", "command": $cmd, "padding": 2}' \
           "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    else
        python3 - "$SETTINGS_FILE" "$TARGET_FILE" <<'PYEOF'
import sys, json
path, target = sys.argv[1], sys.argv[2]
with open(path) as f:
    s = json.load(f)
s['statusLine'] = {
    'type': 'command',
    'command': f'bash "{target}"',
    'padding': 2
}
with open(path, 'w') as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
PYEOF
    fi
else
    # Cria settings.json do zero
    if command -v jq &>/dev/null; then
        jq -n --arg cmd "bash \"$TARGET_FILE\"" \
           '{"statusLine": {"type": "command", "command": $cmd, "padding": 2}}' \
           > "$SETTINGS_FILE"
    else
        python3 - "$SETTINGS_FILE" "$TARGET_FILE" <<'PYEOF'
import sys, json
path, target = sys.argv[1], sys.argv[2]
s = {'statusLine': {'type': 'command', 'command': f'bash "{target}"', 'padding': 2}}
with open(path, 'w') as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
PYEOF
    fi
fi

ok "settings.json atualizado."

# ── teste ─────────────────────────────────────────────────────────────────────
step "Testando script..."

TEST_JSON='{"model":{"display_name":"Test"},"workspace":{"current_dir":"/tmp"},"context_window":{"total_input_tokens":10000,"total_output_tokens":200,"context_window_size":200000,"used_percentage":5,"remaining_percentage":95},"rate_limits":{"five_hour":{"used_percentage":10},"seven_day":{"used_percentage":5}}}'

output=$(echo "$TEST_JSON" | bash "$TARGET_FILE" 2>&1) && {
    ok "Script funcionando:"
    printf '\n'
    echo "$output" | while IFS= read -r line; do printf '     %s\n' "$line"; done
    printf '\n'
} || warn "Script retornou erro — verifique manualmente: $TARGET_FILE"

printf '%s╔══════════════════════════════════════════════╗%s\n' "$c_green" "$c_reset"
printf '%s║   Instalação concluída! Reinicie o Claude.   ║%s\n' "$c_green" "$c_reset"
printf '%s╚══════════════════════════════════════════════╝%s\n\n' "$c_green" "$c_reset"
