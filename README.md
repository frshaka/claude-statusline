# Claude Code — Statusline Customizada

Statusline para o [Claude Code](https://claude.ai/code) que exibe em tempo real:

- **Modelo ativo** e **pasta atual**
- **Branch Git** (com indicador de mudanças pendentes)
- **Uso do contexto** — barra + percentual + tokens usados / total
- **Limite de tokens 5h** — barra + percentual
- **Limite de tokens 7 dias** — barra + percentual

![preview](https://i.imgur.com/4cAcKPV.png)

```
Opus 4.7 (1M context) | meu-projeto | git: main ok
Contexto [████░░░░░░] 38% 380k / 1M | Token 5h [██░░░░░░░░] 20% | Token 7D [░░░░░░░░░░] 3%
```

---

## Requisitos

### Windows
- Windows 10/11
- [PowerShell 7+](https://aka.ms/powershell) (`pwsh`)
- [Claude Code](https://claude.ai/code) instalado

### Linux / macOS
- `bash`, `awk`, `git` (normalmente já instalados)
- `jq` (recomendado) **ou** `python3` como fallback
- [Claude Code](https://claude.ai/code) instalado

---

## Instalação

### Windows — PowerShell 7

```powershell
irm https://raw.githubusercontent.com/frshaka/claude-statusline/main/install-statusline.ps1 | iex
```

### Linux / macOS — Bash

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/frshaka/claude-statusline/main/install-linux.sh)
```

O instalador vai:
1. Verificar/instalar dependências (`jq`)
2. Baixar o script para `~/.claude/`
3. Configurar automaticamente o `~/.claude/settings.json`
4. Testar a saída e exibir preview

Reinicie o Claude Code após a instalação.

---

## Atualização

Basta rodar o mesmo comando de instalação novamente. O arquivo é sobrescrito e o `settings.json` é atualizado sem perder outras configurações.

---

## Desinstalação

1. Remova o bloco `statusLine` do `~/.claude/settings.json`
2. Delete o script instalado (`~/.claude/statusline.ps1` ou `~/.claude/statusline.sh`)

```json
"statusLine": {
  "type": "command",
  "command": "...",
  "padding": 2
}
```

---

## Como funciona

O Claude Code chama o script a cada atualização do status, passando um JSON via `stdin` com dados da sessão. O script processa e imprime **2 linhas** no statusline.

### Campos exibidos

| Campo | Fonte no JSON |
|---|---|
| Modelo | `model.display_name` |
| Pasta | `workspace.current_dir` |
| Git branch | `git rev-parse` local |
| Contexto % | `context_window.remaining_percentage` (com buffer de auto-compact) |
| Tokens usados/total | `context_window.total_input_tokens + total_output_tokens / context_window_size` |
| Token 5h % | `rate_limits.five_hour.used_percentage` |
| Token 7D % | `rate_limits.seven_day.used_percentage` |

### Cores da barra

| Faixa | Cor |
|---|---|
| 0–49% | 🟢 Verde |
| 50–64% | 🟡 Amarelo |
| 65–79% | 🟠 Laranja |
| 80–100% | 🔴 Vermelho |

---

## Estrutura do repositório

```
claude-statusline/
├── statusline.ps1          # Script Windows (PowerShell 7)
├── install-statusline.ps1  # Instalador Windows
├── statusline.sh           # Script Linux/macOS (Bash)
├── install-linux.sh        # Instalador Linux/macOS
└── README.md
```

---

## Licença

MIT
