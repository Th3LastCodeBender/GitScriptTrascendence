#!/bin/bash

# Inserisce automaticamente include guards nei file .h e .hpp
# seguendo lo stile 42, posizionandole DUE righe dopo la seconda
# riga di asterischi del blocco iniziale.

cd $PWD

generate_guard_name() {
    local filename
    filename=$(basename "$1")
    echo "${filename^^}" | sed 's/[^A-Z0-9]/_/g'
}

find . \( -name "*.h" -o -name "*.hpp" \) | while read -r file; do
    # Controllo se esiste già una guard
    if grep -qE '^[[:space:]]*#ifndef|#pragma once' "$file"; then
        echo "Il file $file ha già delle guards."
        continue
    fi

    guard=$(generate_guard_name "$file")

    # Trova la seconda riga di asterischi
    second_line=$(grep -n '^/\* ************************************************************************** \*/' "$file" | sed -n '2p' | cut -d: -f1)

    if [ -z "$second_line" ]; then
        echo "Attenzione: $file non contiene header 42 valido, saltato."
        continue
    fi

    # Calcola la riga di inserimento: due righe dopo
    insert_line=$((second_line + 2))

    tmpfile=$(mktemp)

    awk -v insert_line="$insert_line" -v guard="$guard" '
    NR == insert_line {
        print ""
        print "#ifndef " guard
        print "#define \t" guard
    }
    { print }
    END {
        print ""
        print "#endif"
    }' "$file" > "$tmpfile"

    mv "$tmpfile" "$file"

    echo "Aggiunte guards al file $file."
done
