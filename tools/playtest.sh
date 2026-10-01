#!/usr/bin/env bash
# Lanza una sesion de playtest automatico completa:
#   bot de reglas (o agente LLM) + informe.
# Uso:
#   ./playtest.sh                 # bot 120s
#   ./playtest.sh 60              # bot 60s
#   ./playtest.sh 120 llm         # agente LLM (DeepSeek) 120s
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SECONDS_RUN="${1:-120}"
MODE="${2:-bot}"
PORT="${BRIDGE_PORT:-9099}"
GODOT="${GODOT:-/opt/server/tools/godot/godot}"
PROJECT="$(cd "$HERE/.." && pwd)"

cleanup() { [ -n "${GPID:-}" ] && kill "$GPID" 2>/dev/null; }
trap cleanup EXIT

"$GODOT" --headless --path "$PROJECT" -- --debug-bridge >/tmp/costa3d-bridge.log 2>&1 &
GPID=$!
sleep 5

if [ "$MODE" = "llm" ]; then
	node "$HERE/llm-agent.mjs" --seconds "$SECONDS_RUN" --out "$HERE/out/llm"
	OUT="$HERE/out/llm"
else
	node "$HERE/bot.mjs" --seconds "$SECONDS_RUN" --out "$HERE/out/bot"
	OUT="$HERE/out/bot"
fi

node "$HERE/analyze.mjs" --out "$OUT"
