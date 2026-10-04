#!/bin/bash
# Pasa todas las pruebas sin ventana y dice cuántos fallos y errores da cada una.
# Uso: bash tools/run_tests.sh [prueba ...]   (sin nombres: todas)
cd "$(dirname "$0")/.."
tests=("$@")
if [ ${#tests[@]} -eq 0 ]; then
	tests=(step_up edit_blocks chest controls swim idle equipment ground_crafting craft_session sounds tree_fall save_load raft water shapes)
fi
total=0
for t in "${tests[@]}"; do
	out=$(timeout 400 ./godot.windows.editor.x86_64.exe --headless --path . --script res://tools/test_$t.gd 2>&1)
	fails=$(echo "$out" | grep -c FALLO)
	errors=$(echo "$out" | grep -ci 'SCRIPT ERROR')
	echo "$t: $fails fallos, $errors errores"
	total=$((total + fails + errors))
done
echo "TOTAL: $total"
