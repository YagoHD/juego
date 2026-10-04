#!/bin/bash
# En un componente sacado de otro script, pasa a "<var>.X" lo que es del dueño (variables,
# funciones, señales) y a "<Clase>.X" sus constantes; las funciones del propio componente no se
# tocan. Uso: bash tools/prefix_owner.sh <componente.gd> <dueño.gd> <var> <Clase>
export LC_ALL=C.UTF-8
f=$1; src=$2; var=$3; cls=$4
own=$(grep -oP '^(static )?func \K\w+' $f | sort -u | tr '\n' ' ')
args=""
for m in $(grep -oP '^(var|signal) \K\w+' $src) $(grep -oP '^(static )?func \K\w+' $src); do
	if [[ " $own " == *" $m "* ]]; then continue; fi
	args="$args s/(?<![\.\w\"])\b$m\b(?![\"\w])/$var.$m/g;"
done
for c in $(grep -oP '^const \K\w+' $src); do args="$args s/(?<![\.\w])\b$c\b/$cls.$c/g;"; done
args="$args s/(?<![\.\w])get_viewport\(\)/$var.get_viewport()/g; s/(?<![\.\w])get_node\(/$var.get_node(/g; s/(?<![\.\w])add_child\(/$var.add_child(/g; s/(?<![\.\w])get_tree\(\)/$var.get_tree()/g;"
perl -i -pe "next if /^\s*#/; $args" $f
