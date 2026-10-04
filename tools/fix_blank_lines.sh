#!/bin/bash
# Deja dos líneas en blanco antes de cada bloque de primer nivel (función, o su comentario "##"),
# como en el resto del proyecto. Uso: bash tools/fix_blank_lines.sh <archivo.gd>
awk '
	{ lines[NR] = $0 }
	END {
		out = 0
		for (i = 1; i <= NR; i++) {
			l = lines[i]
			top = (l ~ /^(static )?func / || l ~ /^## / || l ~ /^# ---/)
			if (top && out > 0 && res[out] == "" ) {
				# subir hasta el último no vacío
				j = out; while (j > 0 && res[j] == "") j--
				prev = res[j]
				if (prev !~ /^## / && prev !~ /^# ---/) { out = j; res[++out] = ""; res[++out] = "" }
			}
			res[++out] = l
		}
		for (i = 1; i <= out; i++) print res[i]
	}' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
