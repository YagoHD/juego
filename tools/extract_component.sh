#!/bin/bash
# Saca funciones de player.gd a un componente (herramienta de reorganización, no del juego).
# Uso: bash tools/extract_component.sh <archivo_salida> <cabecera.txt> <rango1> [<rango2> ...]
#   rangos "desde,hasta" (líneas de player.gd). En el código movido, lo que es del jugador
#   (variables, funciones, señales) pasa a "player.X" y sus constantes a "Player.X". Las
#   funciones movidas siguen llamándose entre sí sin prefijo. Borra los rangos de player.gd.
set -e
export LC_ALL=C.UTF-8
out=$1; header=$2; shift 2
src=scripts/player/player.gd
tmp=$(mktemp)
for r in "$@"; do sed -n "${r}p" $src >> $tmp; echo >> $tmp; done
moved=$(grep -oP '^(static )?func \K\w+' $tmp | sort -u | tr '\n' ' ')
members=$(grep -oP '^(var|signal) \K\w+' $src | sort -u)
funcs=$(grep -oP '^(static )?func \K\w+' $src | sort -u)
consts=$(grep -oP '^const \K\w+' $src | sort -u)
args=""
for m in $members $funcs; do
	if [[ " $moved " == *" $m "* ]]; then continue; fi
	args="$args s/(?<![\.\w\"])\b$m\b(?![\"])/player.$m/g;"
done
for c in $consts; do args="$args s/(?<![\.\w])\b$c\b/Player.$c/g;"; done
args="$args s/\bget_world_3d\(\)/player.get_world_3d()/g; s/\bget_rid\(\)/player.get_rid()/g; s/\bget_tree\(\)/player.get_tree()/g; s/\bget_parent\(\)/player.get_parent()/g; s/(?<![\.\w])\bglobal_position\b/player.global_position/g; s/(?<![\.\w])\brotation\b/player.rotation/g; s/(?<![\.\w])\bvelocity\b/player.velocity/g; s/(?<![\.\w])\brotate_y\(/player.rotate_y(/g;"
# Las líneas de comentario y las cadenas no se tocan.
perl -pe "next if /^\s*#/; $args" $tmp > $tmp.2
{ cat "$header"; echo; cat $tmp.2; } > $out
# Borrar de player.gd, de abajo arriba.
for r in $(printf '%s\n' "$@" | sort -t, -k1 -nr); do sed -i "${r}d" $src; done
rm -f $tmp $tmp.2
echo "movidas: $moved"
