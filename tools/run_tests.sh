#!/bin/bash
# Pasa todas las pruebas sin ventana y dice cuántos fallos y errores da cada una.
# Uso: bash tools/run_tests.sh [prueba ...]   (sin nombres: todas)
cd "$(dirname "$0")/.."
tests=("$@")
if [ ${#tests[@]} -eq 0 ]; then
	tests=(step_up edit_blocks chest controls swim idle equipment ground_crafting craft_session sounds tree_fall save_load raft water shapes leaves creatures inventory_interactions stealth squads player_combat mage navigation_tower sleep skills village gold)
fi
# Godot con godot_voxel: el de Windows en el PC de Yago, ./godot en la nube (tools/setup_cloud.sh).
if [ -z "$GODOT" ]; then
	if [ -x ./godot.windows.editor.x86_64.exe ]; then GODOT=./godot.windows.editor.x86_64.exe
	elif [ -x "$HOME/Desktop/godot.windows.editor.x86_64.exe" ]; then GODOT="$HOME/Desktop/godot.windows.editor.x86_64.exe"
	else GODOT=./godot; fi
fi
total=0
for t in "${tests[@]}"; do
	out=$(timeout 400 "$GODOT" --headless --path . --script res://tools/test_$t.gd 2>&1)
	fails=$(echo "$out" | grep -c FALLO)
	errors=$(echo "$out" | grep -ci 'SCRIPT ERROR')
	# Una prueba que se cuelga o se corta no imprime nada: eso también es un fallo.
	if ! echo "$out" | grep -q -e OK -e FALLO; then
		echo "$t: SIN RESULTADOS (se colgó o no terminó)"
		total=$((total + 1))
		continue
	fi
	echo "$t: $fails fallos, $errors errores"
	total=$((total + fails + errors))
done
echo "TOTAL: $total"
