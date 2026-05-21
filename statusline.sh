#!/usr/bin/env bash
# statusline.sh — Claude Code custom statusline (Linux/macOS)
# Deps: jq (ou python3 como fallback), git, awk

set -uo pipefail
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 2>/dev/null || true

# ── chars & cores ─────────────────────────────────────────────────────────────
B_FULL=$'\xE2\x96\x88'   # █
B_LIGHT=$'\xE2\x96\x91'  # ░

c_reset=$'\033[0m'
c_green=$'\033[32m'
c_yellow=$'\033[33m'
c_orange=$'\033[38;5;208m'
c_red=$'\033[31m'
c_dim=$'\033[2m'

# ── json helper ───────────────────────────────────────────────────────────────
json_get() {
    local data="$1" path="$2"
    if command -v jq &>/dev/null; then
        printf '%s' "$data" | jq -r "$path // empty" 2>/dev/null
    else
        python3 - "$data" "$path" 2>/dev/null <<'PYEOF'
import sys, json
try:
    data = json.loads(sys.argv[1])
    path = sys.argv[2].lstrip('.')
    v = data
    for k in path.split('.'):
        if isinstance(v, dict): v = v.get(k)
        else: v = None; break
    if v is not None: print(v)
except: pass
PYEOF
    fi
}

# ── math helpers ──────────────────────────────────────────────────────────────
# Arredonda float para int
round_int() { awk "BEGIN { printf \"%d\", int($1 + 0.5) }"; }

# Clamp 0-100
clamp100() {
    local n="$1"
    awk "BEGIN { n=$n; if(n<0)n=0; if(n>100)n=100; print int(n+0.5) }"
}

# Converte valor para percentual inteiro 0-100
# Só multiplica por 100 se for float < 1 (ex: 0.05 → 5)
to_pct() {
    local val="$1"
    [ -z "$val" ] && return 1
    awk -v v="$val" 'BEGIN {
        gsub(/%/,"",v); gsub(/,/,".",v)
        n = v+0
        if (index(v,".") && n>0 && n<1) n = n*100
        if (n<0) n=0; if (n>100) n=100
        printf "%d\n", int(n+0.5)
    }'
}

# ── formatação de tokens ───────────────────────────────────────────────────────
fmt_tokens() {
    local n="$1"
    awk -v n="$n" 'BEGIN {
        if (n >= 1000000) {
            v = n/1000000
            if (v >= 10) printf "%dM\n", v
            else printf "%.1fM\n", v
        } else if (n >= 1000) {
            v = n/1000
            if (v >= 10) printf "%dk\n", v
            else printf "%.1fk\n", v
        } else {
            printf "%d\n", n
        }
    }'
}

# ── barra de progresso ────────────────────────────────────────────────────────
new_bar() {
    local pct="$1" width=10
    local filled
    filled=$(awk -v p="$pct" -v w="$width" 'BEGIN { f=int(p/100.0*w); if(f<0)f=0; if(f>w)f=w; print f }')
    local empty=$(( width - filled ))
    local bar="["
    for ((i=0; i<filled; i++)); do bar+="$B_FULL"; done
    for ((i=0; i<empty; i++)); do bar+="$B_LIGHT"; done
    bar+="]"
    printf '%s' "$bar"
}

# ── display colorido ──────────────────────────────────────────────────────────
pretty_usage() {
    local pct="$1"
    local bar; bar=$(new_bar "$pct")
    if   [ "$pct" -lt 50 ]; then printf '%s%s %d%%%s' "$c_green"  "$bar" "$pct" "$c_reset"
    elif [ "$pct" -lt 65 ]; then printf '%s%s %d%%%s' "$c_yellow" "$bar" "$pct" "$c_reset"
    elif [ "$pct" -lt 80 ]; then printf '%s%s %d%%%s' "$c_orange" "$bar" "$pct" "$c_reset"
    else                          printf '%s%s %d%%%s' "$c_red"    "$bar" "$pct" "$c_reset"
    fi
}

unavailable() {
    printf '%s[░░░░░░░░░░] --%s' "$c_dim" "$c_reset"
}

# ── cache de rate limits ──────────────────────────────────────────────────────
CACHE_DIR="$HOME/.claude/cache"
CACHE_FILE="$CACHE_DIR/statusline-rate-limits.json"

read_cache() {
    [ -f "$CACHE_FILE" ] || return 1
    cat "$CACHE_FILE"
}

write_cache() {
    local rl5="$1" rl7="$2"
    mkdir -p "$CACHE_DIR"
    printf '{"rl5_pct":%d,"rl7_pct":%d,"updated_at":%d}\n' \
        "$rl5" "$rl7" "$(date +%s)" > "$CACHE_FILE" 2>/dev/null || true
}

# ── lê stdin ──────────────────────────────────────────────────────────────────
raw=$(cat)

if [ -z "$raw" ]; then
    printf '[model?] unknown | git: n/a\n'
    printf 'Contexto %s | Token 5h %s | Token 7D %s\n' \
        "$(unavailable)" "$(unavailable)" "$(unavailable)"
    exit 0
fi

# ── extrai campos ─────────────────────────────────────────────────────────────
model=$(json_get "$raw" '.model.display_name')
[ -z "$model" ] && model="model?"

dir=$(json_get "$raw" '.workspace.current_dir')
[ -z "$dir" ] && dir=$(json_get "$raw" '.cwd')
[ -z "$dir" ] && dir="unknown"
folder=$(basename "$dir")
[ -z "$folder" ] && folder="$dir"

# ── contexto ─────────────────────────────────────────────────────────────────
AUTO_COMPACT_BUFFER=16.5

ctx_remaining=$(json_get "$raw" '.context_window.remaining_percentage')
ctx_used_pct=""
if [ -n "$ctx_remaining" ]; then
    ctx_used_pct=$(awk -v r="$ctx_remaining" -v buf="$AUTO_COMPACT_BUFFER" 'BEGIN {
        usable = (r - buf) / (100 - buf) * 100
        if (usable < 0) usable = 0
        used = 100 - usable
        if (used < 0) used = 0
        if (used > 100) used = 100
        printf "%d\n", int(used+0.5)
    }')
else
    raw_up=$(json_get "$raw" '.context_window.used_percentage')
    [ -n "$raw_up" ] && ctx_used_pct=$(to_pct "$raw_up")
fi

ctx_in=$(json_get "$raw" '.context_window.total_input_tokens')
ctx_out=$(json_get "$raw" '.context_window.total_output_tokens')
ctx_size=$(json_get "$raw" '.context_window.context_window_size')

token_info=""
if [ -n "$ctx_in" ] && [ -n "$ctx_size" ]; then
    used_tok=$(awk -v i="$ctx_in" -v o="${ctx_out:-0}" 'BEGIN { printf "%d", i+o }')
    token_info=" $(fmt_tokens "$used_tok") / $(fmt_tokens "$ctx_size")"
fi

if [ -n "$ctx_used_pct" ]; then
    ctx_part="$(pretty_usage "$ctx_used_pct")$token_info"
else
    ctx_part=$(unavailable)
fi

# ── rate limits ───────────────────────────────────────────────────────────────
rl5_raw=$(json_get "$raw" '.rate_limits.five_hour.used_percentage')
rl7_raw=$(json_get "$raw" '.rate_limits.seven_day.used_percentage')

rl5_pct="" rl7_pct=""
[ -n "$rl5_raw" ] && rl5_pct=$(to_pct "$rl5_raw")
[ -n "$rl7_raw" ] && rl7_pct=$(to_pct "$rl7_raw")

if [ -n "$rl5_pct" ] || [ -n "$rl7_pct" ]; then
    [ -z "$rl5_pct" ] && rl5_pct=0
    [ -z "$rl7_pct" ] && rl7_pct=0
    write_cache "$rl5_pct" "$rl7_pct"
else
    cached=$(read_cache 2>/dev/null || true)
    if [ -n "$cached" ]; then
        c5=$(printf '%s' "$cached" | json_get "$(cat <<< "$cached")" '.rl5_pct' 2>/dev/null || true)
        c7=$(printf '%s' "$cached" | json_get "$(cat <<< "$cached")" '.rl7_pct' 2>/dev/null || true)
        [ -n "$c5" ] && rl5_pct="$c5"
        [ -n "$c7" ] && rl7_pct="$c7"
    fi
fi

[ -n "$rl5_pct" ] && rl5_part=$(pretty_usage "$rl5_pct") || rl5_part=$(unavailable)
[ -n "$rl7_pct" ] && rl7_part=$(pretty_usage "$rl7_pct") || rl7_part=$(unavailable)

# ── git ───────────────────────────────────────────────────────────────────────
git_text="git: n/a"
if command -v git &>/dev/null; then
    if git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
        branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null | head -1)
        [ -z "$branch" ] && branch="(detached)"
        changes=$(git -C "$dir" status --porcelain 2>/dev/null)
        if [ -n "$changes" ]; then
            git_text="git: $branch *"
        else
            git_text="git: $branch ok"
        fi
    fi
fi

# ── output ────────────────────────────────────────────────────────────────────
printf '%s | %s | %s\n' "$model" "$folder" "$git_text"
printf 'Contexto %s | Token 5h %s | Token 7D %s\n' \
    "$ctx_part" "$rl5_part" "$rl7_part"
