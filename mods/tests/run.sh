#!/usr/bin/env bash
# Roda o teste dos mods e falha também se o Godot logar algum ERROR durante o teste
# (os vazamentos de memória do quit() no fim não contam). Uso: mods/tests/run.sh
cd "$(dirname "$0")/../.." || exit 1
log=$(mktemp)
flatpak run org.godotengine.Godot --headless --path . -s res://mods/tests/mods_test.gd >"$log" 2>&1
code=$?
grep -E '^\s+(ok|FAIL)|FALHAS' "$log"
errors=$(sed '/FIM DO TESTE/q' "$log" | grep -E 'SCRIPT ERROR|^ERROR' | grep -v 'UID duplicate')
if [ -n "$errors" ]; then
	echo "ERROS NO LOG:"; echo "$errors" | sort | uniq -c | head -20
	code=1
fi
rm -f "$log"
exit $code
