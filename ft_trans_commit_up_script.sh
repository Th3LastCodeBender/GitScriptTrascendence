#!/bin/bash

CALL_DIR=$(pwd)

# --- Colori ANSI ---
RED=$'\033[1;31m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[1;36m'
ORANGE=$'\033[1;38;5;208m'
LIGHT_RED=$'\033[1;91m'
RESET=$'\033[0m'

# --- Keyword primarie con colore ---
declare -A KEYWORDS
KEYWORDS=(
["PERFORMANCE"]="${CYAN}PERFORMANCE${RESET}"
["BUG"]="${RED}BUG${RESET}"
["FEATURE"]="${YELLOW}FEATURE${RESET}"
)

# --- Stati BUG ---
declare -A BUG_STATES
BUG_STATES=(
["solved"]="${GREEN}SOLVED${RESET}"
["found"]="${YELLOW}FOUND${RESET}"
["fix"]="${ORANGE}FIX IN PROGRESS${RESET}"
["fix in progress"]="${ORANGE}FIX IN PROGRESS${RESET}"
)

# --- Stati Feature ---
declare -A FEATURE_STATES
FEATURE_STATES=(
["new"]="${GREEN}NEW${RESET}"
["update"]="${CYAN}UPDATE${RESET}"
)

# --- Controllo repo git ---
if [ ! -d "$CALL_DIR/.git" ]; then
    echo "❌ Non sei in una cartella git, coglione."
    exit 1
fi

# --- Controllo se esistono file già staged ---
if ! git diff --cached --quiet; then
    echo "Guarda bischero, che se aggiungi intelligente dopo intelligente non diventi mica doppiamente intelligente, solo doppiamente scimmia"
    exit 1
fi

git pull

# --- Pulizia makefile ---
echo "🚮 Cerco Makefile ed eseguo 'make fclean'..."
find "$CALL_DIR" -type f -name "Makefile" | while read -r makefile; do
    dir=$(dirname "$makefile")
    echo "🧹 Pulizia in '$dir'"
    (cd "$dir" && make fclean)
done

# --- Controllo esistenza file (git add verrà fatto dopo) ---
if [ "$#" -gt 0 ]; then
    for file in "$@"; do
        if [ ! -e "$file" ]; then
            echo "allora allora allora, sembra che qui qualcuno stia ancora bevendo liquido per imbalsamazione al posto del tè serale, quei file che vedi esistono solo nella tua testa, SCIMMIA!"
            exit 1
        fi
    done
fi

# --- Mostra keyword disponibili ---
echo "Keyword disponibili:"
for key in "${!KEYWORDS[@]}"; do
    echo -e "- ${KEYWORDS[$key]}"
done

# --- Input keyword ---
while true; do
    read -p "Keyword commit: " keyword
    keyword=$(echo "$keyword" | tr '[:lower:]' '[:upper:]')

    if [[ -n "${KEYWORDS[$keyword]}" ]]; then
        break
    else
        read -p "Keyword '$keyword' non standard. Sei sicuro? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            break
        fi
    fi
done

HEADER="${KEYWORDS[$keyword]}"

# --- Stato BUG ---
if [[ "$keyword" == "BUG" ]]; then
    while true; do
	printf "Stato ${RED}BUG${RESET} (${GREEN}SOLVED${RESET} / ${YELLOW}FOUND${RESET} / ${ORANGE}FIX IN PROGRESS${RESET}): "
        read bugstate
        bugstate_lower=$(echo "$bugstate" | tr '[:upper:]' '[:lower:]')

        if [[ -n "${BUG_STATES[$bugstate_lower]}" ]]; then
            state="${BUG_STATES[$bugstate_lower]}"
            HEADER="${RED}BUG: $state${RESET}"
            break
        else
            echo "Se continui a digitare roba a caso finiamo domani, prova con solved, found o fix, buliccio."
        fi
    done
fi

# --- Stato FEATURE ---
if [[ "$keyword" == "FEATURE" ]]; then
    while true; do
	printf "Stato ${YELLOW}FEATURE${RESET} (${GREEN}NEW${RESET} / ${CYAN}UPDATE${RESET}): "
        read featurestate
        featurestate_lower=$(echo "$featurestate" | tr '[:upper:]' '[:lower:]')

        if [[ -n "${FEATURE_STATES[$featurestate_lower]}" ]]; then
            state="${FEATURE_STATES[$featurestate_lower]}"
            HEADER="${RED}FEATURE: $state${RESET}"
            break
        else
            echo "Se continui a digitare roba a caso finiamo domani, prova con new o update, debosciato."
        fi
    done
fi

# --- Messaggio commit ---
while true; do
    read -p "Messaggio commit: " msg
    if [[ -z "$msg" ]]; then
        echo "Ma ti droghi? Siamo mica qui a grattare il culo alle mosche, scrivi qualcosa scimmia ubriaca"
    else
        break
    fi
done

# --- File modificati (robusto) ---
changed_files=$(git diff --name-only)

file_list=""
count=0
total=$(echo "$changed_files" | wc -l)

for file in $changed_files; do
    ((count++))

    if [[ $count -le 10 ]]; then
        if [[ -z "$file_list" ]]; then
            file_list="$file"
        else
            file_list="$file_list, $file"
        fi
    fi
done

if [[ $total -gt 10 ]]; then
    file_list="$file_list..."
    echo "Edo piantala"
fi

# --- Costruzione commit ---
commit_msg="$HEADER | $msg | $file_list"

# --- Gestione git add (dopo formato commit) ---
if [ "$#" -gt 0 ]; then
    git add "$@"
else
    git add .
fi

# --- Git operations ---
git commit -m "$commit_msg"

if git push; then
    echo "✅ Push eseguito."
else
    echo "❌ Errore nel push."
    exit 1
fi
