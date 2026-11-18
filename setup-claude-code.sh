#!/usr/bin/env bash
# Setup global do Claude Code (~/.claude)
# Roda em macOS, Linux e Windows (Git Bash ou WSL). Cada passo e isolado:
# se um falhar, o resto continua e o resumo final mostra o que precisa de atencao.

set -u

OK=()
FAIL=()
SKIP=()

case "$(uname -s)" in
  Darwin) OS="mac" ;;
  Linux) OS="linux" ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
  *) OS="desconhecido" ;;
esac
echo "Sistema detectado: $OS"

has() { command -v "$1" >/dev/null 2>&1; }

step() {
  local name="$1"; shift
  echo ""
  echo ">>> $name"
  if "$@"; then OK+=("$name"); else FAIL+=("$name"); fi
}

# ---------- Dependencias base ----------
if ! has claude; then
  echo "Claude Code nao encontrado. Instale primeiro: https://docs.claude.com/en/docs/claude-code/setup"
  exit 1
fi

if ! has node || ! has npx; then
  echo "Node.js/npx nao encontrado. Instale o Node LTS (https://nodejs.org) e rode de novo."
  exit 1
fi

if [ "$OS" = "mac" ] && ! has brew; then
  echo "Aviso: Homebrew nao encontrado. A instalacao do RTK no Mac vai usar o script oficial."
fi

# ---------- 1. Plugins e skills ----------
step "Plugin HyperFrames" bash -c 'claude plugin marketplace add heygen-com/hyperframes && claude plugin install hyperframes@hyperframes'
step "Plugin Remotion" bash -c 'claude plugin marketplace add remotion-dev/claude-code-plugin && claude plugin install remotion@remotion'
step "Plugin Impeccable" bash -c 'claude plugin marketplace add pbakaus/impeccable && claude plugin install impeccable'
step "Skill Taste-Skill" npx --yes skills add Leonxlnx/taste-skill -g -a claude-code
step "Plugin Context Mode" bash -c 'claude plugin marketplace add mksglu/context-mode && claude plugin install context-mode@context-mode'
step "Skill Whisper (clawdis)" npx --yes skills add steipete/clawdis -a claude-code

# ---------- 2. RTK ----------
install_rtk() {
  if has rtk; then echo "RTK ja instalado."; return 0; fi
  case "$OS" in
    mac)
      if has brew; then brew install rtk; else curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh; fi ;;
    linux)
      if has brew; then brew install rtk; else curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh; fi ;;
    windows)
      winget install rtk-ai.rtk ;;
    *) return 1 ;;
  esac
}
# ATENCAO: o ID do winget e a URL do install.sh acima nao foram confirmados.
# Se falharem, veja o README em https://github.com/rtk-ai/rtk e ajuste.
step "RTK (binario)" install_rtk
if has rtk; then
  step "RTK hook global" rtk init -g --auto-patch
else
  SKIP+=("RTK hook global (binario ausente)")
fi

# ---------- 2b. Headroom ----------
install_headroom() {
  if has headroom; then echo "Headroom ja instalado."; return 0; fi
  if ! has uv && ! has pipx; then
    case "$OS" in
      mac) if has brew; then brew install uv; else curl -LsSf https://astral.sh/uv/install.sh | sh; fi ;;
      linux) curl -LsSf https://astral.sh/uv/install.sh | sh ;;
      windows) powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex" ;;
    esac
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  fi
  if has uv; then
    uv tool install --python 3.13 "headroom-ai[all]"
  elif has pipx; then
    pipx install "headroom-ai[all]"
  else
    return 1
  fi
}
# Nao altera proxy nem variaveis do Claude. Uso sob demanda: headroom wrap claude
step "Headroom CLI" install_headroom

# ---------- 3. Validacao ----------
echo ""
echo "=================== DIAGNOSTICOS ==================="
echo "--- hyperframes doctor ---"
npx --yes hyperframes doctor || FAIL+=("Diagnostico hyperframes")
echo "--- rtk init --show ---"
if has rtk; then rtk init --show || FAIL+=("Diagnostico rtk"); else echo "rtk ausente"; fi
echo "--- claude plugin list ---"
claude plugin list || FAIL+=("Diagnostico claude plugin list")
echo "--- headroom ---"
if has headroom; then headroom --version || FAIL+=("Diagnostico headroom"); else echo "headroom ausente (talvez precise reabrir o terminal para atualizar o PATH)"; fi

echo ""
echo "===================== RESUMO ======================"
echo "Sucesso (${#OK[@]}):"
for i in "${OK[@]:-}"; do [ -n "$i" ] && echo "  OK    $i"; done
echo "Falhou, precisa de atencao (${#FAIL[@]}):"
for i in "${FAIL[@]:-}"; do [ -n "$i" ] && echo "  FALHA $i"; done
echo "Pulado (${#SKIP[@]}):"
for i in "${SKIP[@]:-}"; do [ -n "$i" ] && echo "  SKIP  $i"; done
echo ""
echo "Reinicie o Claude Code para carregar plugins e skills novos."
