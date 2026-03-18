#!/bin/bash

# Salva la cartella da cui viene chiamato
CALL_DIR=$(pwd)

# Controllo se sei in una repo git
if [ ! -d "$CALL_DIR/.git" ]; then
    echo "❌ Non sei in una cartella git, coglione."
    exit 1
fi

git pull

# Cerca ricorsivamente Makefile e lancia make fclean dove lo trova
echo "🚮 Cerco Makefile ed eseguo 'make fclean' dove possibile..."
find "$CALL_DIR" -type f -name "Makefile" | while read -r makefile; do
    dir=$(dirname "$makefile")
    echo "🧹 Pulizia in '$dir'"
    (cd "$dir" && make fclean)
done

# Chiedi messaggio di commit
read -p "Inserisci messaggio di commit: " msg

# Aggiunge tutti i file (modificati, nuovi, cancellati)
git add .

# Fa il commit
git commit -m "$msg"

# Fa il push
if git push; then
    echo "✅ Push eseguito con successo, miracolosamente."
else
    echo "❌ Errore nel push. Forse non hai i permessi? O forse sei tu il problema..."
    exit 1
fi

