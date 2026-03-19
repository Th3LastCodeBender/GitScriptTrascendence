#!/bin/bash

CALL_DIR=$(pwd)

# --- Colori ANSI ---
RED=$'\033[1;31m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[1;36m'
ORANGE=$'\033[1;38;5;208m'
LIGHT_RED=$'\033[1;91m'
BLUE=$'\033[1;34m'
MAGENTA=$'\033[1;35m'
WHITE=$'\033[1;97m'
GRAY=$'\033[0;90m'
RESET=$'\033[0m'

show_help() {
    local script_name
    script_name=$(resolve_help_name)
    cat <<'EOF' | sed "s/__SCRIPT__/${script_name}/g"
Uso: __SCRIPT__

    __SCRIPT__ --> git add . guidato
    [file ...] --> per git add di singoli file
    --help     --> display delle istruzioni di utilizzo
    --keys     --> display di tutte le Keywords
    --add      --> aggiunge una Keyword all'albero principale
    --remove   --> rimuove una Keyword dall'albero principale
EOF
}

show_keys() {
    local keys key last_key
    mapfile -t keys < <(printf '%s\n' "${!KEYWORDS[@]}" | sort)

    printf "\nKeyword commit:\n\n  KEYWORDS:\n  |\n"

    for key in "${keys[@]}"; do
        last_key="${keys[-1]}"

        printf "  |-- %b\n" "${KEYWORDS[$key]}"
        branch_prefix="  |"
        child_prefix="  |   "

        if [[ "$key" == "BUG" ]]; then
            printf "%s|\n" "$child_prefix"
            mapfile -t bug_keys < <(printf '%s\n' "${!BUG_STATES[@]}" | sort)
            local i=0
            local total=0
            local b val
            local -A seen_bug=()
            local bug_vals=()
            for b in "${bug_keys[@]}"; do
                val="${BUG_STATES[$b]}"
                if [[ -z "${seen_bug[$val]+x}" ]]; then
                    bug_vals+=("$val")
                    seen_bug[$val]=1
                fi
            done
            total=${#bug_vals[@]}
            for val in "${bug_vals[@]}"; do
                ((i++))
                printf "%s|--> %b\n" "$child_prefix" "$val"
            done
        fi

        if [[ "$key" == "FEATURE" ]]; then
            printf "%s|\n" "$child_prefix"
            mapfile -t feature_keys < <(printf '%s\n' "${!FEATURE_STATES[@]}" | sort)
            local i=0
            local total=0
            local f val
            local -A seen_feat=()
            local feat_vals=()
            for f in "${feature_keys[@]}"; do
                val="${FEATURE_STATES[$f]}"
                if [[ -z "${seen_feat[$val]+x}" ]]; then
                    feat_vals+=("$val")
                    seen_feat[$val]=1
                fi
            done
            total=${#feat_vals[@]}
            for val in "${feat_vals[@]}"; do
                ((i++))
                printf "%s|--> %b\n" "$child_prefix" "$val"
            done
        fi

        if [[ "$key" != "$last_key" ]]; then
            printf "%s\n" "$branch_prefix"
        fi
    done
}

resolve_help_name() {
    local script_name script_base aliases line name cmd
    script_name=$(basename "$0")
    script_base="${0##*/}"

    # 1) Se definito esplicitamente
    if [[ -n "${ALIAS_NAME:-}" ]]; then
        echo "$ALIAS_NAME"
        return 0
    fi

    # 2) Prova a cercare un alias che punti a questo script
    if command -v bash >/dev/null 2>&1; then
        aliases=$(bash -lic 'alias' 2>/dev/null)
        while IFS= read -r line; do
            [[ "$line" != alias* ]] && continue
            name="${line#alias }"
            name="${name%%=*}"
            cmd="${line#*=}"

            if [[ "$cmd" == *"$script_base"* || "$cmd" == *"$script_name"* ]]; then
                echo "$name"
                return 0
            fi
        done <<< "$aliases"
    fi

    # 3) Fallback al nome file
    echo "$script_name"
}

add_keyword() {
    local raw_name color_name kw entry script_path tmp_file repo_dir confirm
    raw_name="$1"
    color_name="${2:-}"

    if [[ -z "$raw_name" ]]; then
        read -p "Nuova keyword: " raw_name
    fi

    kw=$(echo "$raw_name" | tr '[:lower:]' '[:upper:]')
    if [[ -z "$kw" ]]; then
        echo "Keyword vuota, annullo."
        exit 1
    fi

    if [[ -z "$color_name" ]]; then
        echo "Colori disponibili: red, green, yellow, cyan, orange, light_red, blue, magenta, white, gray, giorgio"
        read -p "Colore (default: cyan): " color_name
    fi

    case "${color_name,,}" in
        red) color_name="RED" ;;
        green) color_name="GREEN" ;;
        yellow) color_name="YELLOW" ;;
        cyan|"") color_name="CYAN" ;;
        orange) color_name="ORANGE" ;;
        light_red|lightred) color_name="LIGHT_RED" ;;
        blue) color_name="BLUE" ;;
        magenta) color_name="MAGENTA" ;;
        white) color_name="WHITE" ;;
        gray|grey) color_name="GRAY" ;;
        giorgio) color_name="GIORGIO" ;;
        *)
            echo "Colore non valido, uso CYAN."
            color_name="CYAN"
            ;;
    esac

    if [[ "$color_name" == "GIORGIO" ]]; then
        local colors rainbow_expr i c color
        colors=(RED YELLOW GREEN CYAN BLUE MAGENTA)
        rainbow_expr=""
        for ((i=0; i<${#kw}; i++)); do
            c="${kw:i:1}"
            color="${colors[i % ${#colors[@]}]}"
            rainbow_expr+='${'"$color"'}'"$c"
        done
        rainbow_expr+='${RESET}'
        entry='["'"$kw"'"]='"\"$rainbow_expr\""
    else
        entry='["'"$kw"'"]="${'"$color_name"'}'"$kw"'${RESET}"'
    fi

    script_path=$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")
    if command -v rg >/dev/null 2>&1; then
        rg -q "\\[\"$kw\"\\]" "$script_path"
        exists=$?
    else
        grep -q "\\[\"$kw\"\\]" "$script_path"
        exists=$?
    fi
    if [[ $exists -eq 0 ]]; then
        echo "Keyword '$kw' già presente."
        exit 0
    fi

    tmp_file="$(mktemp)"
    if ! awk -v entry="$entry" '
        $0 ~ /KEYWORDS=\(/ {print; in_block=1; next}
        in_block && $0 ~ /^\)/ {print entry; print; in_block=0; next}
        {print}
    ' "$script_path" > "$tmp_file"; then
        echo "Errore durante l'aggiornamento del file."
        rm -f "$tmp_file"
        exit 1
    fi
    mv "$tmp_file" "$script_path"

    echo "Keyword '$kw' aggiunta."

    repo_dir=$(cd "$(dirname "$script_path")" && pwd)
    if git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        read -p "Vuoi fare add/commit/push della keyword? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            git -C "$repo_dir" add "$script_path"
            git -C "$repo_dir" commit -m "Add keyword $kw"
            git -C "$repo_dir" push
        fi
    else
        echo "Repo git non trovata, niente push."
    fi
}

remove_keyword() {
    local raw_name kw script_path tmp_file repo_dir confirm exists
    raw_name="$1"

    if [[ -z "$raw_name" ]]; then
        read -p "Keyword da rimuovere: " raw_name
    fi

    kw=$(echo "$raw_name" | tr '[:lower:]' '[:upper:]')
    if [[ -z "$kw" ]]; then
        echo "Keyword vuota, annullo."
        exit 1
    fi

    script_path=$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")

    if command -v rg >/dev/null 2>&1; then
        rg -q "\\[\"$kw\"\\]" "$script_path"
        exists=$?
    else
        grep -q "\\[\"$kw\"\\]" "$script_path"
        exists=$?
    fi
    if [[ $exists -ne 0 ]]; then
        echo "Keyword '$kw' non trovata."
        exit 1
    fi

    tmp_file="$(mktemp)"
    if ! awk -v kw="$kw" '
        $0 ~ /KEYWORDS=\(/ {print; in_block=1; next}
        in_block && $0 ~ /^\)/ {print; in_block=0; next}
        in_block && index($0, "[\"" kw "\"]") {next}
        {print}
    ' "$script_path" > "$tmp_file"; then
        echo "Errore durante l'aggiornamento del file."
        rm -f "$tmp_file"
        exit 1
    fi
    mv "$tmp_file" "$script_path"

    echo "Keyword '$kw' rimossa."

    repo_dir=$(cd "$(dirname "$script_path")" && pwd)
    if git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        read -p "Vuoi fare add/commit/push della rimozione? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            git -C "$repo_dir" add "$script_path"
            git -C "$repo_dir" commit -m "Remove keyword $kw"
            git -C "$repo_dir" push
        fi
    else
        echo "Repo git non trovata, niente push."
    fi
}

# --- Keyword primarie con colore ---
declare -A KEYWORDS
KEYWORDS=(
["PERFORMANCE"]="${CYAN}PERFORMANCE${RESET}"
["BUG"]="${RED}BUG${RESET}"
["FEATURE"]="${YELLOW}FEATURE${RESET}"
["TEST"]="${RED}T${YELLOW}E${GREEN}S${CYAN}T${RESET}"
["CLEANING"]="${MAGENTA}CLEANING${RESET}"
)

# --- Stati BUG ---
declare -A BUG_STATES
BUG_STATES=(
["solved"]="${GREEN}SOLVED${RESET}"
["found"]="${YELLOW}FOUND${RESET}"
["fix"]="${ORANGE}FIX IN PROGRESS${RESET}"
["fix in progress"]="${ORANGE}FIX IN PROGRESS${RESET}"
["fixed"]="${GREEN}SOLVED${RESET}"
["fixing"]="${ORANGE}FIX IN PROGRESS${RESET}"
)

# --- Stati Feature ---
declare -A FEATURE_STATES
FEATURE_STATES=(
["new"]="${GREEN}NEW${RESET}"
["update"]="${CYAN}UPDATE${RESET}"
)

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
fi

if [[ "$1" == "--keys" || "$1" == "-k" ]]; then
    show_keys
    exit 0
fi

if [[ "$1" == "--add" || "$1" == "-add" || "$1" == "-a" ]]; then
    add_keyword "$2" "$3"
    exit 0
fi

if [[ "$1" == "--remove" || "$1" == "-remove" || "$1" == "-r" ]]; then
    remove_keyword "$2"
    exit 0
fi

# --- Flag sconosciuta ---
if [[ -n "$1" && "$1" == -* ]]; then
    echo "Flag non riconosciuta: $1"
    show_help
    exit 1
fi

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
	printf "Stato ${RED}BUG${RESET} (${GREEN}FIXED${RESET} / ${YELLOW}FOUND${RESET} / ${ORANGE}FIX IN PROGRESS${RESET}): "
        read bugstate
        bugstate_lower=$(echo "$bugstate" | tr '[:upper:]' '[:lower:]')

        if [[ -n "${BUG_STATES[$bugstate_lower]}" ]]; then
            state="${BUG_STATES[$bugstate_lower]}"
            HEADER="${RED}BUG: $state${RESET}"
            break
        else
            echo "Se continui a digitare roba a caso finiamo domani, prova con FIXED, found o fix, buliccio."
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

# --- File modificati (robusto, include untracked e spazi) ---
files=()
while IFS= read -r -d '' entry; do
    status="${entry:0:2}"
    path="${entry:3}"

    # R/C in formato -z: status + " " + old + "\0" + new + "\0"
    if [[ "$status" == R* || "$status" == C* ]]; then
        IFS= read -r -d '' path
    fi

    files+=("$path")
done < <(git status --porcelain -z -uall)

file_list=""
count=0
total=${#files[@]}

for file in "${files[@]}"; do
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

if [[ $total -eq 0 ]]; then
    file_list="Belin quanto lavori eh, schiena di cristallo"
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
