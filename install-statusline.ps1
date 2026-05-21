#Requires -Version 7
# install-statusline.ps1 — instala statusline customizada do Claude Code
# Uso: irm https://raw.githubusercontent.com/SEU_USER/SEU_REPO/main/install-statusline.ps1 | iex

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ── CONFIG ────────────────────────────────────────────────────────────────────
$REPO_RAW = 'https://raw.githubusercontent.com/SEU_USER/SEU_REPO/main'
$STATUSLINE_URL = "$REPO_RAW/statusline.ps1"
# ─────────────────────────────────────────────────────────────────────────────

$claudeDir  = Join-Path $env:USERPROFILE '.claude'
$targetFile = Join-Path $claudeDir 'statusline.ps1'
$settingsFile = Join-Path $claudeDir 'settings.json'

function Write-Step {
    param([string]$Msg)
    Write-Host "  → $Msg" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Msg)
    Write-Host "  ✔ $Msg" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Msg)
    Write-Host "  ⚠ $Msg" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor DarkCyan
Write-Host "║   Claude Code — Instalador de Statusline     ║" -ForegroundColor DarkCyan
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor DarkCyan
Write-Host ""

# 1. Garante diretório .claude
if (-not (Test-Path $claudeDir)) {
    Write-Step "Criando diretório $claudeDir..."
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

# 2. Baixa statusline.ps1
Write-Step "Baixando statusline.ps1..."
try {
    $content = (Invoke-WebRequest -Uri $STATUSLINE_URL -UseBasicParsing).Content
    Set-Content -LiteralPath $targetFile -Value $content -Encoding UTF8
    Write-Ok "statusline.ps1 instalado em $targetFile"
} catch {
    Write-Error "Falha ao baixar $STATUSLINE_URL`n$_"
    exit 1
}

# 3. Atualiza settings.json (merge, preserva chaves existentes)
Write-Step "Atualizando settings.json..."

$statusLineBlock = [ordered]@{
    type    = 'command'
    command = "pwsh -NoProfile -ExecutionPolicy Bypass -File `"$($targetFile.Replace('\','/'))`""
    padding = 2
}

if (Test-Path $settingsFile) {
    try {
        $raw = Get-Content $settingsFile -Raw -Encoding UTF8
        $settings = $raw | ConvertFrom-Json -Depth 20 -AsHashtable
    } catch {
        Write-Warn "settings.json inválido — criando backup e recriando."
        Copy-Item $settingsFile "$settingsFile.bak" -Force
        $settings = @{}
    }
} else {
    $settings = @{}
}

$settings['statusLine'] = $statusLineBlock

try {
    $settings | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $settingsFile -Encoding UTF8
    Write-Ok "settings.json atualizado."
} catch {
    Write-Error "Falha ao gravar settings.json: $_"
    exit 1
}

# 4. Teste rápido
Write-Step "Testando script..."
$testJson = '{"model":{"display_name":"Test"},"workspace":{"current_dir":"C:\\"},"context_window":{"total_input_tokens":10000,"total_output_tokens":200,"context_window_size":200000,"used_percentage":5,"remaining_percentage":95},"rate_limits":{"five_hour":{"used_percentage":10},"seven_day":{"used_percentage":5}}}'
$out = $testJson | & pwsh -NoProfile -ExecutionPolicy Bypass -File $targetFile 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Ok "Script funcionando:"
    Write-Host ""
    $out | ForEach-Object { Write-Host "     $_" }
    Write-Host ""
} else {
    Write-Warn "Script retornou erro — verifique manualmente: $targetFile"
}

Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor DarkGreen
Write-Host "║   Instalação concluída! Reinicie o Claude.   ║" -ForegroundColor DarkGreen
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor DarkGreen
Write-Host ""
