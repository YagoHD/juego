#!/bin/bash
# Prepara una sesión de Claude Code en la nube (Linux, sin tarjeta gráfica): descarga el Godot de
# Zylann con godot_voxel integrado (la misma versión que el de Windows: Godot 4.7.2 + voxel v1.7),
# lo deja en ./godot y hace la primera importación del proyecto (la carpeta .godot no se sube).
# Lo lanza el gancho SessionStart de .claude/settings.json solo en la nube; a mano: bash tools/setup_cloud.sh
set -e
cd "$(dirname "$0")/.."
URL="https://github.com/Zylann/godot_voxel/releases/download/v1.7/godot.linuxbsd.editor.x86_64.zip"
DIR="$HOME/godot-voxel"
BIN="$DIR/godot.linuxbsd.editor.x86_64"
if [ ! -x "$BIN" ]; then
	echo "Descargando Godot + godot_voxel para Linux..."
	mkdir -p "$DIR"
	curl -sSL -o "$DIR/godot.zip" "$URL"
	(cd "$DIR" && unzip -oq godot.zip && rm -f godot.zip)
	BIN=$(find "$DIR" -type f -name "godot.linuxbsd.editor*" | head -1)
	chmod +x "$BIN"
fi
ln -sf "$BIN" ./godot
if [ ! -d .godot/imported ]; then
	echo "Importando el proyecto (la primera vez tarda unos minutos)..."
	timeout 1200 ./godot --headless --path . --import > /dev/null 2>&1 || true
fi
./godot --version
echo "Listo: pruebas con 'bash tools/run_tests.sh'"
