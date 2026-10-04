#!/bin/bash
# En un componente del jugador, pasa a "player.X" lo que es del jugador (variables, funciones,
# señales) y a "Player.X" sus constantes; las funciones del propio componente no se tocan.
# Uso: bash tools/prefix_player.sh <componente.gd>
export LC_ALL=C.UTF-8
f=$1
src=scripts/player/player.gd
own=$(grep -oP '^(static )?func \K\w+' $f | sort -u | tr '\n' ' ')
args=""
for m in $(grep -oP '^(var|signal) \K\w+' $src) $(grep -oP '^(static )?func \K\w+' $src); do
	if [[ " $own " == *" $m "* ]]; then continue; fi
	args="$args s/(?<![\.\w\"])\b$m\b(?![\"\w])/player.$m/g;"
done
for c in $(grep -oP '^const \K\w+' $src); do args="$args s/(?<![\.\w])\b$c\b/Player.$c/g;"; done
args="$args s/(?<![\.\w])get_world_3d\(\)/player.get_world_3d()/g; s/(?<![\.\w])get_rid\(\)/player.get_rid()/g; s/(?<![\.\w])get_parent\(\)/player.get_parent()/g; s/(?<![\.\w])global_position\b/player.global_position/g; s/(?<![\.\w])rotation\b/player.rotation/g; s/(?<![\.\w])velocity\b/player.velocity/g; s/(?<![\.\w])rotate_y\(/player.rotate_y(/g;"
perl -i -pe "next if /^\s*#/; $args" $f
