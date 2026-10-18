#!/usr/bin/env bash
# J-Code Provider Manager
# =======================
# Launcher + engine Bash self-contained.
#
# Kalau Python 3.8+ ada, kerjaan langsung didelegasikan ke jcode-manager.py
# (fitur paling lengkap). Kalau Python nggak ada, script ini jalan sendiri
# pakai engine Bash murni: add, list, edit, delete, quick start, generate,
# launch, info, restore, dan menu interaktif.
#
# Pilih engine manual:
#   JCODE_MANAGER_ENGINE=bash    # paksa engine Bash
#   JCODE_MANAGER_ENGINE=python  # paksa engine Python (gagal kalau nggak ada)
#   JCODE_MANAGER_ENGINE=auto    # default: Python kalau ada
#
#   ./jcode-manager.sh           # buka menu
#   ./jcode-manager.sh --list
#   ./jcode-manager.sh --add mygw --base-url https://api.example.com/v1 \
#       --api-key sk-xxx --model gpt-4o

set -u

resolve_self() { # ikutin symlink biar folder script beneran ketemu
    local src="$1" dir
    while [ -L "$src" ]; do
        dir="$(cd "$(dirname "$src")" && pwd)"
        src="$(readlink "$src")"
        case "$src" in
            /*) ;;
            *) src="$dir/$src" ;;
        esac
    done
    printf '%s' "$src"
}

SELF_PATH="$(resolve_self "$0")"
SELF_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
PY_SCRIPT="$SELF_DIR/jcode-manager.py"
ENGINE_MODE="${JCODE_MANAGER_ENGINE:-auto}"

find_python() {
    local cand
    for cand in "${JCODE_MANAGER_PYTHON:-}" python3 python py; do
        [ -n "$cand" ] || continue
        if command -v "$cand" >/dev/null 2>&1 &&
            "$cand" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
            printf '%s\n' "$cand"
            return 0
        fi
    done
    return 1
}

if [ "$ENGINE_MODE" != "bash" ]; then
    if PY_BIN="$(find_python)" && [ -f "$PY_SCRIPT" ]; then
        exec "$PY_BIN" "$PY_SCRIPT" "$@"
    fi
    if [ "$ENGINE_MODE" = "python" ]; then
        echo "Engine Python diminta, tapi Python 3.8+ / jcode-manager.py nggak ketemu." >&2
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Engine Bash (fallback tanpa Python)
# ---------------------------------------------------------------------------

APP_NAME="J-Code Provider Manager"
VERSION="1.0.0 (bash engine)"

if [ "${JCODE_MANAGER_ENGINE:-auto}" = "auto" ]; then
    echo "Catatan: Python nggak ketemu, jalan pakai engine Bash. Fitur inti tetap jalan." >&2
fi

PROVIDER_KIND="openai-compatible"

# --- warna ---
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${JCODE_MANAGER_NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'
    C_MAGENTA=$'\033[35m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_GRAY=$'\033[90m'
else
    C_RESET=""; C_BOLD=""; C_CYAN=""; C_GREEN=""; C_MAGENTA=""; C_YELLOW=""; C_RED=""; C_GRAY=""
fi

say() { printf '%s\n' "$*"; }
ok() { printf '%s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err() { printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
info() { printf '%s[INFO]%s %s\n' "$C_GRAY" "$C_RESET" "$*"; }
rule() { printf '%s%s%s\n' "$C_CYAN" "==============================================================" "$C_RESET"; }
header() {
    rule
    printf '%s%s  %s%s\n' "$C_CYAN" "$C_BOLD" "$1" "$C_RESET"
    [ -n "${2:-}" ] && printf '%s  %s%s\n' "$C_GRAY" "$2" "$C_RESET"
    rule
}
clear_screen() {
    [ -t 1 ] || return 0
    printf '\033[2J\033[H'
}
pause_key() {
    printf '%s' "${C_YELLOW}Tekan Enter buat balik ke menu...${C_RESET}"
    read -r _ 2>/dev/null || true
}

# --- deteksi OS & path ---
detect_platform() {
    case "$(uname -s 2>/dev/null || echo unknown)" in
        MINGW*|MSYS*|CYGWIN*) PLATFORM="Windows (Git Bash/MSYS)"; IS_WINDOWS=1 ;;
        Darwin*) PLATFORM="macOS"; IS_MACOS=1 ;;
        Linux*) PLATFORM="Linux"; IS_LINUX=1 ;;
        *) PLATFORM="Unknown"; IS_LINUX=1 ;;
    esac
    if [ -n "${WSL_DISTRO_NAME:-}" ]; then PLATFORM="Linux (WSL)"; fi
    IS_WINDOWS="${IS_WINDOWS:-0}"

    if [ -n "${CONFIG_OVERRIDE:-}" ]; then
        CONFIG_PATH="$CONFIG_OVERRIDE"
    elif [ -n "${JCODE_MANAGER_CONFIG:-}" ]; then
        CONFIG_PATH="$JCODE_MANAGER_CONFIG"
    elif [ "$IS_WINDOWS" = "1" ]; then
        CONFIG_PATH="${USERPROFILE:-$HOME}/.jcode/config.toml"
    else
        CONFIG_PATH="$HOME/.jcode/config.toml"
    fi

    if [ -n "${JCODE_MANAGER_APP_CONFIG:-}" ]; then
        APP_CONFIG_DIR="$JCODE_MANAGER_APP_CONFIG"
    elif [ "$IS_WINDOWS" = "1" ]; then
        APP_CONFIG_DIR="${APPDATA:-$HOME/AppData/Roaming}/jcode"
    elif [ -n "${XDG_CONFIG_HOME:-}" ]; then
        APP_CONFIG_DIR="$XDG_CONFIG_HOME/jcode"
    else
        APP_CONFIG_DIR="$HOME/.config/jcode"
    fi

    JCODE_BIN="$(command -v jcode || true)"
    if [ -z "$JCODE_BIN" ]; then
        for cand in "$HOME/.local/bin/jcode" "/usr/local/bin/jcode" "/opt/homebrew/bin/jcode"; do
            [ -x "$cand" ] && { JCODE_BIN="$cand"; break; }
        done
    fi
    [ -n "$JCODE_BIN" ] || JCODE_BIN="jcode"
}

# --- util ---
mask_key() {
    local key="$1" n
    if [ -z "$key" ]; then printf '%s' "(keyless / tanpa key)"; return; fi
    n=${#key}
    if [ "$n" -le 8 ]; then
        printf '%*s' "$n" '' | tr ' ' '*'
    else
        # ${key: -4} butuh bash 4.2+, macOS masih bash 3.2. Pakai bentuk ini biar aman.
        printf '%s...%s' "${key:0:4}" "${key:$((${#key} - 4))}"
    fi
}

timestamp() { date +%Y%m%d%H%M%S; }

backup_config() {
    [ -f "$CONFIG_PATH" ] || return 0
    local dest stamp n=1
    stamp="$(timestamp)"
    dest="$CONFIG_PATH.backup.$stamp"
    while [ -e "$dest" ]; do dest="$CONFIG_PATH.backup.$stamp.$n"; n=$((n + 1)); done
    if ! cp "$CONFIG_PATH" "$dest" 2>/dev/null; then
        err "Gagal bikin backup $dest"
        return 1
    fi
    basename "$dest"
}

write_config() { # write_config <file-isi-baru> (file sementara di folder yang sama)
    local src="$1"
    if ! mkdir -p "$(dirname "$CONFIG_PATH")" 2>/dev/null; then
        err "Nggak bisa bikin folder $(dirname "$CONFIG_PATH")."
        return 1
    fi
    [ -f "$src" ] || { err "File sementara nggak ketemu: $src"; return 1; }
    chmod 600 "$src" 2>/dev/null || true
    # mv, bukan cp: masih satu filesystem jadi atomik, dan nggak nabrak diri sendiri
    if ! mv "$src" "$CONFIG_PATH" 2>/dev/null; then
        err "Gagal pindahin config ke $CONFIG_PATH (permission?)."
        rm -f "$src" 2>/dev/null
        return 1
    fi
    return 0
}

validate_name() {
    case "$1" in
        "") echo "Nama provider nggak boleh kosong."; return 1 ;;
        *[!A-Za-z0-9_-]*) echo "Nama provider harus alfanumerik, boleh '-' dan '_' (tanpa titik/spasi)."; return 1 ;;
    esac
    return 0
}

validate_url() {
    case "$1" in
        "") echo "Base URL nggak boleh kosong."; return 1 ;;
        http://*|https://*) ;;
        *) echo "Base URL harus mulai dengan http:// atau https://"; return 1 ;;
    esac
    case "$1" in
        *" "*) echo "Base URL nggak boleh ada spasi."; return 1 ;;
        *chat/completions*) echo "Base URL nggak perlu path /chat/completions, cukup sampai /v1."; return 1 ;;
    esac
    return 0
}

# --- TOML mini reader ---
# Output: nama|base_url|api_key|default_model|api_key_env|env_file|punya_api_key
providers_tsv() {
    [ -f "$CONFIG_PATH" ] || return 0
    awk '
        function section_name(line,   t) {
            t = line
            if (t !~ /^[ \t]*\[\[?[ \t]*providers[ \t]*\./) return ""
            sub(/^[ \t]*\[\[?[ \t]*providers[ \t]*\./, "", t)
            sub(/[.\]].*$/, "", t)
            gsub(/^[ \t]+|[ \t]+$/, "", t)
            gsub(/^"|"$/, "", t)
            return t
        }
        function val(line,   v) {
            v = line
            sub(/^[^=]*=[ \t]*/, "", v)
            if (v ~ /^"/) { sub(/^"/, "", v); sub(/"[ \t]*(#.*)?$/, "", v); return v }
            if (v ~ /^\047/) { sub(/^\047/, "", v); sub(/\047[ \t]*(#.*)?$/, "", v); return v }
            sub(/[ \t]*#.*$/, "", v)
            gsub(/[ \t]+$/, "", v)
            return v
        }
        function flush() {
            if (cur != "") print cur "|" base "|" key "|" model "|" keyenv "|" envfile "|" haskey
        }
        function reset(n) { cur = n; base = ""; key = ""; model = ""; keyenv = ""; envfile = ""; haskey = 0 }
        {
            name = section_name($0)
            if (name != "") {
                if ($0 ~ /^[ \t]*\[\[/) {           # sub-table [[providers.x.models]]
                    if (name != cur) { flush(); reset(name) }
                    next
                }
                flush(); reset(name); next
            }
            if (cur == "") next
            if ($0 ~ /^[ \t]*\[/) { flush(); cur = ""; next }
            if ($0 ~ /^[ \t]*#/ || $0 !~ /=/) next
            k = $0; sub(/[ \t]*=.*/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", k)
            v = val($0)
            if (k == "base_url") base = v
            else if (k == "api_key") { key = v; haskey = 1 }
            else if (k == "default_model") model = v
            else if (k == "model" && model == "") model = v
            else if (k == "api_key_env") keyenv = v
            else if (k == "env_file") envfile = v
        }
        END { flush() }
    ' "$CONFIG_PATH"
}

provider_names() { providers_tsv | cut -d'|' -f1; }

provider_exists() {
    provider_names | grep -qx -- "$1"
}

provider_field() { # provider_field <nama> <index 1-based field>
    providers_tsv | awk -F'|' -v n="$1" -v f="$2" '$1 == n { print $f; found = 1 } END { }'
}

env_key_for() { # env_key_for <nama> -> baca key dari env file provider
    local name="$1" envfile keyenv path line k v
    envfile="$(provider_field "$name" 6)"
    keyenv="$(provider_field "$name" 5)"
    [ -n "$envfile" ] && [ -n "$keyenv" ] || return 0
    path="$APP_CONFIG_DIR/$envfile"
    [ -f "$path" ] || return 0
    while IFS= read -r line; do
        case "$line" in ""|\#*) continue ;; esac
        k="${line%%=*}"; v="${line#*=}"
        k="$(printf '%s' "$k" | tr -d '[:space:]')"
        if [ "$k" = "$keyenv" ]; then
            v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
            printf '%s' "$v"
            return 0
        fi
    done <"$path"
}

display_key() { # display_key <nama> -> masked + sumber
    local name="$1" keyenv envfile key
    if [ "$(provider_field "$name" 7)" = "1" ]; then
        mask_key "$(provider_field "$name" 3)"
        return
    fi
    keyenv="$(provider_field "$name" 5)"
    envfile="$(provider_field "$name" 6)"
    if [ -n "$keyenv" ] || [ -n "$envfile" ]; then
        key="$(env_key_for "$name")"
        if [ -n "$key" ]; then
            printf '%s <- %s' "$(mask_key "$key")" "$envfile"
        else
            printf '(env file belum ada) <- %s' "$envfile"
        fi
        return
    fi
    printf '(nggak ada key)'
}

toml_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

strip_trailing_blanks() { # rapihin newline berlebih di akhir file
    awk '{ lines[NR] = $0 } END { last = NR; while (last > 0 && lines[last] ~ /^[ \t]*$/) last--; for (i = 1; i <= last; i++) print lines[i] }' "$1"
}

# --- operasi tulis ---
cmd_add() { # <nama> <base_url> <api_key> <model> [force]
    local name="$1" base="$2" key="$3" model="$4" force="${5:-0}" msg tmp backup
    if ! msg="$(validate_name "$name")"; then err "$msg"; return 1; fi
    if ! msg="$(validate_url "$base")"; then err "$msg"; return 1; fi

    if provider_exists "$name"; then
        if [ "$force" != "1" ]; then
            err "Provider '$name' udah ada. Pakai Edit, atau hapus dulu."
            return 1
        fi
        cmd_delete "$name" >/dev/null 2>&1 || true
        info "Provider lama '$name' ditimpa (--force)."
    fi

    backup="$(backup_config)"
    mkdir -p "$(dirname "$CONFIG_PATH")" 2>/dev/null || { err "Gagal bikin folder config."; return 1; }
    tmp="$CONFIG_PATH.tmp.$$"
    : >"$tmp" 2>/dev/null || { err "Gagal nulis file sementara."; return 1; }

    if [ -s "$CONFIG_PATH" ]; then
        strip_trailing_blanks "$CONFIG_PATH" >"$tmp"
        printf '\n' >>"$tmp"
    fi
    {
        printf '[providers.%s]\n' "$name"
        printf 'base_url = "%s"\n' "$(toml_escape "$base")"
        printf 'api_key = "%s"\n' "$(toml_escape "$key")"
        [ -n "$model" ] && printf 'default_model = "%s"\n' "$(toml_escape "$model")"
    } >>"$tmp"

    write_config "$tmp" || { rm -f "$tmp" 2>/dev/null; return 1; }
    ok "Provider '$name' ditambahin ke $CONFIG_PATH"
    [ -n "$backup" ] && ok "Backup config: $backup"
    return 0
}

cmd_edit() { # <nama> <base_url|- > <api_key|- > <model|- > [nama_baru|-]
    local name="$1" base="$2" key="$3" model="$4" newname="${5:--}" msg tmp tmp2 backup
    local has_base=0 has_key=0 has_model=0 ins_base="" ins_key="" ins_model=""
    provider_exists "$name" || { err "Provider '$name' nggak ada di $CONFIG_PATH."; return 1; }

    if [ -n "$base" ] && [ "$base" != "-" ]; then
        if ! msg="$(validate_url "$base")"; then err "$msg"; return 1; fi
    else
        base=""
    fi
    [ "$key" = "-" ] && key=""
    [ "$model" = "-" ] && model=""
    [ "$newname" = "-" ] && newname=""

    if [ -z "$base" ] && [ -z "$key" ] && [ -z "$model" ] && [ -z "$newname" ]; then
        err "Nggak ada yang diubah."
        return 1
    fi

    if [ -n "$newname" ] && [ "$newname" != "$name" ]; then
        if ! msg="$(validate_name "$newname")"; then err "$msg"; return 1; fi
        if provider_exists "$newname"; then err "Provider '$newname' udah ada."; return 1; fi
    fi

    # Key yang udah ada ditimpa in-place. Kalau belum ada, disisipin sama pass 2.
    [ -n "$(provider_field "$name" 2)" ] && has_base=1
    [ "$(provider_field "$name" 7)" = "1" ] && has_key=1
    [ -n "$(provider_field "$name" 4)" ] && has_model=1
    [ -n "$base" ] && [ "$has_base" = "0" ] && ins_base="$base"
    [ -n "$key" ] && [ "$has_key" = "0" ] && ins_key="$key"
    [ -n "$model" ] && [ "$has_model" = "0" ] && ins_model="$model"

    backup="$(backup_config)"
    tmp="$CONFIG_PATH.tmp.$$"
    tmp2="$CONFIG_PATH.tmp2.$$"

    # pass 1: timpa key yang udah ada di section target
    awk -v target="$name" -v newname="$newname" -v base="$base" -v key="$key" -v model="$model" '
        function subkey(line,   t) {
            if (line !~ /^[ \t]*\[\[/) return ""
            t = line
            sub(/^[ \t]*\[\[[ \t]*providers[ \t]*\.[ \t]*/, "", t)
            sub(/^[^.]*[ \t]*\.[ \t]*/, "", t)
            sub(/[ \t]*\]\].*$/, "", t)
            gsub(/^[ \t]+|[ \t]+$/, "", t)
            return t
        }
        function hdr(line,   t) {
            t = line
            if (t !~ /^[ \t]*\[\[?[ \t]*providers[ \t]*\./) return ""
            sub(/^[ \t]*\[\[?[ \t]*providers[ \t]*\./, "", t)
            sub(/[.\]].*$/, "", t)
            gsub(/^[ \t]+|[ \t]+$/, "", t); gsub(/^"|"$/, "", t)
            return t
        }
        {
            h = hdr($0)
            if (h != "") {
                inb = (h == target)
                if (inb && newname != "") {
                    sk = subkey($0)
                    if (sk != "") print "[[" "providers." newname "." sk "]]"
                    else print "[providers." newname "]"
                    next
                }
                print; next
            }
            if ($0 ~ /^[ \t]*\[/) { inb = 0; print; next }
            if (inb) {
                k = $0; sub(/[ \t]*=.*/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", k)
                if ($0 !~ /^[ \t]*#/ && k != "") {
                    if (k == "base_url" && base != "") { print "base_url = \"" base "\""; next }
                    if (k == "api_key" && key != "") { print "api_key = \"" key "\""; next }
                    if (k == "default_model" && model != "") { print "default_model = \"" model "\""; next }
                }
            }
            print
        }
    ' "$CONFIG_PATH" >"$tmp" || { err "Gagal nulis ulang config."; return 1; }

    # pass 2: tambahin key yang belum ada, persis setelah header section target
    awk -v target="${newname:-$name}" -v ins_base="$ins_base" -v ins_key="$ins_key" -v ins_model="$ins_model" '
        function hdr(line,   t) {
            t = line
            if (t !~ /^[ \t]*\[\[?[ \t]*providers[ \t]*\./) return ""
            sub(/^[ \t]*\[\[?[ \t]*providers[ \t]*\./, "", t)
            sub(/[.\]].*$/, "", t)
            gsub(/^[ \t]+|[ \t]+$/, "", t); gsub(/^"|"$/, "", t)
            return t
        }
        {
            h = hdr($0)
            print
            if (h == target && $0 !~ /^[ \t]*\[\[/) {
                if (ins_base != "") { print "base_url = \"" ins_base "\""; ins_base = "" }
                if (ins_key != "") { print "api_key = \"" ins_key "\""; ins_key = "" }
                if (ins_model != "") { print "default_model = \"" ins_model "\""; ins_model = "" }
            }
        }
    ' "$tmp" >"$tmp2" || { err "Gagal nulis ulang config."; rm -f "$tmp"; return 1; }
    rm -f "$tmp" 2>/dev/null

    write_config "$tmp2" || { rm -f "$tmp2" 2>/dev/null; return 1; }
    if [ -n "$newname" ] && [ "$newname" != "$name" ]; then
        ok "Nama provider: $name -> $newname"
    fi

    [ -n "$backup" ] && ok "Backup config: $backup"
    ok "Provider '${newname:-$name}' beres diupdate."
    return 0
}

cmd_delete() { # <nama>
    local name="$1" tmp backup envfile
    provider_exists "$name" || { err "Provider '$name' nggak ada di $CONFIG_PATH."; return 1; }
    envfile="$(provider_field "$name" 6)"

    backup="$(backup_config)"
    tmp="$CONFIG_PATH.tmp.$$"
    awk -v target="$name" '
        function hdr(line,   t) {
            t = line
            if (t !~ /^[ \t]*\[\[?[ \t]*providers[ \t]*\./) return ""
            sub(/^[ \t]*\[\[?[ \t]*providers[ \t]*\./, "", t)
            sub(/[.\]].*$/, "", t)
            gsub(/^[ \t]+|[ \t]+$/, "", t); gsub(/^"|"$/, "", t)
            return t
        }
        {
            h = hdr($0)
            if (h != "") { skip = (h == target); if (skip) next }
            if (skip) next
            print
        }
    ' "$CONFIG_PATH" >"$tmp" || { err "Gagal nulis ulang config."; return 1; }

    # rapihin kalau ada 2+ baris kosong beruntun
    awk 'BEGIN { blank = 0 } { if ($0 ~ /^[ \t]*$/) { blank++; if (blank > 1) next } else blank = 0; print }' "$tmp" >"$tmp.clean" \
        && mv "$tmp.clean" "$tmp"

    write_config "$tmp" || { rm -f "$tmp" 2>/dev/null; return 1; }
    [ -n "$backup" ] && ok "Backup config: $backup"
    if [ -n "$envfile" ]; then
        info "Catatan: env file $APP_CONFIG_DIR/$envfile dibiarkan, hapus manual kalau perlu."
    fi
    ok "Provider '$name' udah dihapus."
    return 0
}

# --- multi-model (sub-table [[providers.<nama>.models]]) ---
# jcode baca tiap sub-table itu sebagai satu model yang bisa dipilih di picker.
# Satu provider boleh punya banyak model; `default_model` cuma yang dipakai default.

provider_models() { # <nama> -> cetak id model, satu per baris
    [ -f "$CONFIG_PATH" ] || return 0
    awk -v target="$1" '
        function hdr(line,   t) {
            t = line
            if (t !~ /^[ \t]*\[\[?[ \t]*providers[ \t]*\./) return ""
            sub(/^[ \t]*\[\[?[ \t]*providers[ \t]*\./, "", t)
            sub(/[.\]].*$/, "", t)
            gsub(/^[ \t]+|[ \t]+$/, "", t); gsub(/^"|"$/, "", t)
            return t
        }
        function idof(line,   k, v) {
            if (line !~ /=/) return ""
            k = line; sub(/[ \t]*=.*/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", k)
            if (k != "id") return ""
            v = line; sub(/^[^=]*=[ \t]*/, "", v); gsub(/[ \t]*#.*$/, "", v)
            gsub(/^[ \t]+|[ \t]+$/, "", v); gsub(/^"|"$/, "", v)
            return v
        }
        { lines[NR] = $0 }
        END {
            for (i = 1; i <= NR; i++) {
                if (lines[i] !~ /^[ \t]*\[\[/) continue
                if (hdr(lines[i]) != target) continue
                for (j = i + 1; j <= NR; j++) {
                    if (hdr(lines[j]) != "") break
                    v = idof(lines[j])
                    if (v != "") { print v; break }
                }
            }
        }
    ' "$CONFIG_PATH"
}

provider_models_csv() { # <nama> -> id1,id2,...
    provider_models "$1" | awk 'BEGIN { ORS = "" } { print (NR > 1 ? "," : "") $0 }'
}

cmd_models() { # <nama> [json]
    local name="$1" json="${2:-0}" def n=0 m mark first=1
    provider_exists "$name" || { err "Provider '$name' nggak ada di $CONFIG_PATH."; return 1; }
    def="$(provider_field "$name" 4)"
    if [ "$json" = "1" ]; then
        printf '{\n  "name": "%s",\n  "default_model": "%s",\n  "models": [' \
            "$(toml_escape "$name")" "$(toml_escape "$def")"
        while IFS= read -r m; do
            [ -n "$m" ] || continue
            [ "$first" = "1" ] || printf ', '
            first=0
            printf '"%s"' "$(toml_escape "$m")"
        done < <(provider_models "$name")
        printf ']\n}\n'
        return 0
    fi
    printf '  %sdefault ...%s %s\n' "$C_GRAY" "$C_RESET" "${def:-(belum diset)}"
    while IFS= read -r m; do
        [ -n "$m" ] || continue
        n=$((n + 1))
        if [ "$m" = "$def" ]; then mark="${C_GRAY} (= default)${C_RESET}"; else mark=""; fi
        printf '  %s%2d.%s %s%s%s\n' "$C_GRAY" "$n" "$C_RESET" "$m" "$mark" ""
    done < <(provider_models "$name")
    if [ "$n" -eq 0 ]; then
        printf '  %s(belum ada model tambahan)%s\n' "$C_GRAY" "$C_RESET"
    fi
    return 0
}

# Ganti seluruh sub-table [[providers.<nama>.models]] dengan daftar baru.
# Blok lama dipakai ulang (biar komentar/field tambahan nggak ilang), model baru
# ditulis sebagai blok minimal berisi id. csv kosong = hapus semua sub-table.
cmd_set_models() { # <nama> <id1,id2,...> [default]
    local name="$1" csv="${2:-}" default="${3:-}" tmp backup
    provider_exists "$name" || { err "Provider '$name' nggak ada di $CONFIG_PATH."; return 1; }
    case "$csv" in
        *'"'*) err "Nama model nggak boleh ada tanda kutip."; return 1 ;;
        *" "*|*"\t"*) err "Nama model nggak boleh ada spasi."; return 1 ;;
    esac
    case "$default" in
        *'"'*|*" "*) err "Nama model nggak boleh ada tanda kutip/spasi."; return 1 ;;
    esac

    backup="$(backup_config)"
    tmp="$CONFIG_PATH.tmp.$$"
    awk -v target="$name" -v csv="$csv" '
        function hdr(line,   t) {
            t = line
            if (t !~ /^[ \t]*\[\[?[ \t]*providers[ \t]*\./) return ""
            sub(/^[ \t]*\[\[?[ \t]*providers[ \t]*\./, "", t)
            sub(/[.\]].*$/, "", t)
            gsub(/^[ \t]+|[ \t]+$/, "", t); gsub(/^"|"$/, "", t)
            return t
        }
        function idof(line,   k, v) {
            if (line !~ /=/) return ""
            k = line; sub(/[ \t]*=.*/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", k)
            if (k != "id") return ""
            v = line; sub(/^[^=]*=[ \t]*/, "", v); gsub(/[ \t]*#.*$/, "", v)
            gsub(/^[ \t]+|[ \t]+$/, "", v); gsub(/^"|"$/, "", v)
            return v
        }
        function rstrip(s) {
            while (length(s) > 0 && substr(s, length(s), 1) == "\n") s = substr(s, 1, length(s) - 1)
            return s
        }
        { lines[NR] = $0 }
        END {
            n = NR
            p = 0
            for (i = 1; i <= n; i++) {
                if (lines[i] ~ /^[ \t]*\[\[/) continue
                if (hdr(lines[i]) == target) { p = i; break }
            }
            if (p == 0) exit 1
            e = n + 1
            for (i = p + 1; i <= n; i++) if (hdr(lines[i]) != "") { e = i; break }

            nb = 0
            for (i = 1; i <= n; i++) {
                if (lines[i] !~ /^[ \t]*\[\[/) continue
                if (hdr(lines[i]) != target) continue
                j = i + 1
                while (j <= n && hdr(lines[j]) == "") j++
                txt = ""; bid = ""
                for (k = i; k < j; k++) {
                    txt = txt lines[k] "\n"
                    if (bid == "") bid = idof(lines[k])
                }
                drop[i] = j - 1
                nb++; blkid[nb] = bid; blktxt[nb] = txt
                i = j - 1
            }

            grp = ""
            m = (csv == "" ? 0 : split(csv, want, ","))
            for (w = 1; w <= m; w++) {
                id = want[w]
                gsub(/^[ \t]+|[ \t]+$/, "", id)
                if (id == "" || seen[id]) continue
                seen[id] = 1
                txt = ""
                for (b = 1; b <= nb; b++) if (blkid[b] == id) { txt = blktxt[b]; break }
                if (txt == "") txt = "[[providers." target ".models]]\nid = \"" id "\"\n"
                grp = grp (grp == "" ? "" : "\n\n") rstrip(txt)
            }
            for (b = 1; b <= nb; b++) {
                if (blkid[b] != "") continue
                grp = grp (grp == "" ? "" : "\n\n") rstrip(blktxt[b])
            }

            head = ""
            for (i = 1; i < e; i++) {
                if (i in drop) { i = drop[i]; continue }
                head = head lines[i] "\n"
            }
            head = rstrip(head)
            tail = ""
            for (i = e; i <= n; i++) {
                if (i in drop) { i = drop[i]; continue }
                tail = tail lines[i] "\n"
            }
            while (length(tail) > 0 && substr(tail, 1, 1) == "\n") tail = substr(tail, 2)
            tail = rstrip(tail)

            out = head
            if (grp != "") out = out "\n\n" grp
            if (tail != "") out = out "\n\n" tail
            print out
        }
    ' "$CONFIG_PATH" >"$tmp" || { err "Gagal nulis ulang config."; rm -f "$tmp" 2>/dev/null; return 1; }
    [ -s "$tmp" ] || { err "Hasil rewrite kosong, perubahan dibatalin."; rm -f "$tmp" 2>/dev/null; return 1; }

    write_config "$tmp" || { rm -f "$tmp" 2>/dev/null; return 1; }
    [ -n "$backup" ] && ok "Backup config: $backup"
    if [ -n "$default" ]; then
        cmd_edit "$name" "-" "-" "$default" "-" >/dev/null 2>&1 || true
        ok "default_model: $default"
    fi
    if [ -n "$csv" ]; then
        ok "Daftar model '$name' diset: $(printf '%s' "$csv" | tr ',' ' ')"
    else
        ok "Semua model tambahan provider '$name' dihapus."
    fi
    return 0
}

cmd_add_model() { # <nama> <id>
    local name="$1" id="${2:-}" existing
    provider_exists "$name" || { err "Provider '$name' nggak ada di $CONFIG_PATH."; return 1; }
    [ -n "$id" ] || { err "Nama model nggak boleh kosong."; return 1; }
    if provider_models "$name" | grep -qx -- "$id"; then
        err "Model '$id' udah kedaftar di provider '$name'."
        return 1
    fi
    existing="$(provider_models_csv "$name")"
    cmd_set_models "$name" "${existing:+$existing,}$id" || return 1
    if [ -z "$(provider_field "$name" 4)" ]; then
        cmd_edit "$name" "-" "-" "$id" "-" >/dev/null 2>&1 || true
        ok "default_model diisi '$id' karena sebelumnya belum diset."
    fi
    ok "Model '$id' ditambahin ke provider '$name'."
    return 0
}

cmd_remove_model() { # <nama> <id>
    local name="$1" id="${2:-}" csv default
    provider_exists "$name" || { err "Provider '$name' nggak ada di $CONFIG_PATH."; return 1; }
    provider_models "$name" | grep -qx -- "$id" || {
        err "Model '$id' nggak kedaftar di provider '$name'."
        return 1
    }
    csv="$(provider_models "$name" | awk -v drop="$id" '$0 != drop && $0 != "" { print (n++ ? "," : "") $0 }')"
    cmd_set_models "$name" "$csv" || return 1
    default="$(provider_field "$name" 4)"
    if [ "$default" = "$id" ]; then
        info "Catatan: default_model masih '$id'. Set default baru lewat Edit atau menu 10."
    fi
    ok "Model '$id' dihapus dari provider '$name'."
    return 0
}

cmd_models_batch() { # <baris-add> <baris-remove>
    local adds="$1" removes="$2" raw nm mid rc=0
    while IFS= read -r raw; do
        [ -n "$raw" ] || continue
        case "$raw" in
            *=*) nm="${raw%%=*}"; mid="${raw#*=}" ;;
            *) err "--add-model/--remove-model butuh format NAMA=MODEL, contoh: mygw=gpt-4o."; return 2 ;;
        esac
        [ -n "$nm" ] && [ -n "$mid" ] || { err "Format NAMA=MODEL kurang lengkap: $raw"; return 2; }
        cmd_add_model "$nm" "$mid" || rc=1
    done <<EOF
$adds
EOF
    while IFS= read -r raw; do
        [ -n "$raw" ] || continue
        case "$raw" in
            *=*) nm="${raw%%=*}"; mid="${raw#*=}" ;;
            *) err "--add-model/--remove-model butuh format NAMA=MODEL, contoh: mygw=gpt-4o."; return 2 ;;
        esac
        [ -n "$nm" ] && [ -n "$mid" ] || { err "Format NAMA=MODEL kurang lengkap: $raw"; return 2; }
        cmd_remove_model "$nm" "$mid" || rc=1
    done <<EOF
$removes
EOF
    return $rc
}

# --- jcode ---
jcode_cmd() { # <profile> [model] -> cetak command
    local profile="$1" model="${2:-}" exe="jcode"
    if [ -n "$JCODE_BIN" ] && [ "$JCODE_BIN" != "jcode" ]; then exe="$JCODE_BIN"; fi
    printf '%s --provider %s --provider-profile %s' "$exe" "$PROVIDER_KIND" "$profile"
    [ -n "$model" ] && printf ' --model %s' "$model"
}

cmd_generate() { # <nama> [model]
    local name="$1" model="${2:-}"
    provider_exists "$name" || { err "Provider '$name' nggak ada."; return 1; }
    [ -z "$model" ] && model="$(provider_field "$name" 4)"
    jcode_cmd "$name" "$model"
    printf '\n'
}

cmd_launch() { # <nama> [model]
    local name="$1" model="${2:-}"
    provider_exists "$name" || { err "Provider '$name' nggak ada."; return 1; }
    [ -z "$model" ] && model="$(provider_field "$name" 4)"

    say ""
    info "Stop background daemon dulu (flag provider cuma ngaruh pas server fresh)."
    if "$JCODE_BIN" server stop --force >/dev/null 2>&1; then
        ok "Daemon dimatiin."
    else
        warn "Stop daemon gagal atau nggak ada server, lanjut aja."
    fi
    sleep 0.5

    say ""
    info "Jalanin: $(jcode_cmd "$name" "$model")"
    say ""
    # shellcheck disable=SC2046
    "$JCODE_BIN" --provider "$PROVIDER_KIND" --provider-profile "$name" ${model:+--model "$model"}
    return $?
}

# --- backup restore ---
list_backups() {
    ls -1t "$CONFIG_PATH".backup.* 2>/dev/null
}

cmd_restore() { # <path-backup>
    local src="$1" backup
    [ -f "$src" ] || { err "Backup $src nggak ketemu."; return 1; }
    backup="$(backup_config)"
    if ! cp "$src" "$CONFIG_PATH" 2>/dev/null; then err "Gagal restore config."; return 1; fi
    [ -n "$backup" ] && ok "Config sekarang dibackup ke $backup"
    ok "Config dibalikin dari $(basename "$src")"
    return 0
}

# --- tampilan ---
cmd_list() {
    local json="${1:-0}" name base model masked first=1
    if [ "$json" = "1" ]; then
        printf '['
        while IFS='|' read -r name base key model keyenv envfile haskey; do
            [ -n "name" ] || continue
            masked="$(display_key "$name")"
            case "$masked" in *' <- '*) source="${masked##* <- }"; masked="${masked%% <- *}" ;; *) source="-" ;; esac
            [ "$first" = "1" ] || printf ','
            first=0
            printf '\n  {"name": "%s", "base_url": "%s", "default_model": "%s", "api_key_masked": "%s", "key_source": "%s"}' \
                "$name" "$base" "$model" "$masked" "$source"
        done < <(providers_tsv)
        printf '\n]\n'
        return 0
    fi

    local count=0
    while IFS='|' read -r name base key model keyenv envfile haskey; do
        [ -n "name" ] || continue
        count=$((count + 1))
        printf '  %2d. %s%s%s\n' "$count" "$C_GREEN" "$name" "$C_RESET"
        printf '      %sbase_url .%s %s\n' "$C_GRAY" "$C_RESET" "${base:-(kosong)}"
        printf '      %smodel .....%s %s\n' "$C_GRAY" "$C_RESET" "${model:-(belum diset)}"
        printf '      %sapi_key ..%s %s\n' "$C_GRAY" "$C_RESET" "$(display_key "$name")"
    done < <(providers_tsv)

    if [ "$count" -eq 0 ]; then
        say "${C_YELLOW}No providers configured.${C_RESET}"
        say "${C_GRAY}Config: $CONFIG_PATH${C_RESET}"
    fi
    return 0
}

cmd_info() {
    local nprov=0 nback=0
    nprov="$(providers_tsv | grep -c . || true)"
    nback="$(list_backups | grep -c . || true)"
    printf '%sOS ........%s %s\n' "$C_GRAY" "$C_RESET" "$PLATFORM"
    printf '%sEngine ....%s bash (tanpa Python)\n' "$C_GRAY" "$C_RESET"
    printf '%sShell .....%s %s\n' "$C_GRAY" "$C_RESET" "$(basename "${SHELL:-bash}")"
    printf '%sConfig ....%s %s\n' "$C_GRAY" "$C_RESET" "$CONFIG_PATH"
    printf '%sEnv dir ...%s %s\n' "$C_GRAY" "$C_RESET" "$APP_CONFIG_DIR"
    printf '%sjcode bin .%s %s\n' "$C_GRAY" "$C_RESET" "$JCODE_BIN"
    if command -v "$JCODE_BIN" >/dev/null 2>&1 || [ -x "$JCODE_BIN" ]; then
        printf '%sjcode ok ..%s %s\n' "$C_GRAY" "$C_RESET" "${C_GREEN}ya${C_RESET}"
    else
        printf '%sjcode ok ..%s %s\n' "$C_GRAY" "$C_RESET" "${C_RED}nggak ketemu${C_RESET}"
    fi
    printf '%sProvider ..%s %s\n' "$C_GRAY" "$C_RESET" "$nprov"
    printf '%sBackup ....%s %s\n' "$C_GRAY" "$C_RESET" "$nback"
}

# --- quick start ---
PRESET_KEYS="openai anthropic groq openrouter"
preset_field() { # <key> <field>
    case "$1:$2" in
        openai:label) printf 'OpenAI' ;; openai:base) printf 'https://api.openai.com/v1' ;; openai:model) printf 'gpt-4o' ;;
        openai:note) printf 'API key format: sk-...' ;;
        anthropic:label) printf 'Anthropic / Claude' ;; anthropic:base) printf 'https://api.anthropic.com' ;;
        anthropic:model) printf 'claude-3-5-sonnet-20241022' ;;
        anthropic:note) printf 'Varian OpenAI-compatible: https://api.anthropic.com/v1. jcode juga punya provider native anthropic-api.' ;;
        groq:label) printf 'Groq' ;; groq:base) printf 'https://api.groq.com/openai/v1' ;;
        groq:model) printf 'llama-3.3-70b-versatile' ;; groq:note) printf 'Gratis dan ngebut buat model Llama.' ;;
        openrouter:label) printf 'OpenRouter' ;; openrouter:base) printf 'https://openrouter.ai/api/v1' ;;
        openrouter:model) printf 'openai/gpt-4o' ;; openrouter:note) printf 'API key format: sk-or-...' ;;
        *) printf '' ;;
    esac
}

preset_valid() {
    case " $PRESET_KEYS " in *" $1 "*) return 0 ;; esac
    return 1
}

# --- input helper ---
ask() { # <prompt> [default] -> stdout
    local prompt="$1" def="${2:-}" reply
    if [ -n "$def" ]; then printf '%s [%s]: ' "$prompt" "$def" >&2; else printf '%s: ' "$prompt" >&2; fi
    read -r reply 2>/dev/null || reply=""
    [ -n "$reply" ] || reply="$def"
    printf '%s' "$reply"
}

ask_secret() { # <prompt> -> stdout, karakter disembunyiin kalau tty
    local prompt="$1" reply
    printf '%s: ' "$prompt" >&2
    if [ -t 0 ]; then
        stty -echo 2>/dev/null || true
        read -r reply 2>/dev/null || reply=""
        stty echo 2>/dev/null || true
        printf '\n' >&2
    else
        read -r reply 2>/dev/null || reply=""
    fi
    printf '%s' "$reply"
}

confirm() { # <prompt> [assume_yes]
    local prompt="$1" yes="${2:-0}" reply
    [ "$yes" = "1" ] && return 0
    printf '%s [y/N]: ' "$prompt" >&2
    read -r reply 2>/dev/null || return 1
    case "$reply" in y|Y|ya|Ya|iya|yes|YES) return 0 ;; *) return 1 ;; esac
}

choose_provider() { # <prompt> -> stdout nama provider
    local prompt="$1" names count=0 reply
    names="$(provider_names)"
    if [ -z "$names" ]; then
        warn "Belum ada provider. Tambah dulu lewat menu 1 atau menu 5." >&2
        return 1
    fi
    local arr=()
    while IFS= read -r n; do
        [ -n "$n" ] || continue
        arr+=("$n")
        count=$((count + 1))
        printf '  %2d. %s\n' "$count" "$n" >&2
    done <<<"$names"
    reply="$(ask "$prompt (nomor atau nama, kosong = batal)")"
    [ -n "$reply" ] || return 1
    case "$reply" in
        *[!0-9]*)
            provider_exists "$reply" || { warn "Provider '$reply' nggak ketemu." >&2; return 1; }
            printf '%s' "$reply"; return 0 ;;
        *)
            if [ "$reply" -ge 1 ] 2>/dev/null && [ "$reply" -le "${#arr[@]}" ]; then
                printf '%s' "${arr[$((reply - 1))]}"; return 0
            fi
            warn "Nomor di luar range." >&2; return 1 ;;
    esac
}

# --- menu ---
menu_add() {
    clear_screen
    header "1. Tambah Provider Baru" "Backup config dibikin otomatis sebelum nulis"
    say "${C_GRAY}  Config target: $CONFIG_PATH${C_RESET}"
    say
    local name base model key msg
    name="$(ask 'Nama provider (contoh: mygw)')"
    [ -n "$name" ] || { warn "Nggak ada nama, dibatalin."; return 0; }
    if ! msg="$(validate_name "$name")"; then err "$msg"; return 0; fi
    if provider_exists "$name"; then err "Provider '$name' udah ada. Pakai menu 3 (Edit)."; return 0; fi
    base="$(ask 'Base URL (contoh: https://api.example.com/v1)')"
    if ! msg="$(validate_url "$base")"; then err "$msg"; return 0; fi
    model="$(ask 'Default model (contoh: gpt-4o, boleh kosong)')"
    key="$(ask_secret 'API key (kosong = server lokal tanpa auth)')"
    [ -n "$key" ] || warn "API key kosong. Field api_key tetap ditulis (string kosong) karena jcode nolak profile tanpa itu."
    say
    cmd_add "$name" "$base" "$key" "$model" 0
}

menu_list() {
    clear_screen
    header "2. Semua Provider" "API key di-mask, aman buat screenshot"
    say
    cmd_list 0
    say
    info "Config: $CONFIG_PATH"
}

menu_edit() {
    clear_screen
    header "3. Edit Provider" "Kosongin input = nilai lama dipertahankan"
    say
    local name base model key newname
    name="$(choose_provider 'Provider yang mau diedit')" || return 0
    say
    say "  ${C_GRAY}Nama ........${C_RESET} ${C_GREEN}$name${C_RESET}"
    say "  ${C_GRAY}base_url ....${C_RESET} $(provider_field "$name" 2)"
    say "  ${C_GRAY}model .......${C_RESET} $(provider_field "$name" 4)"
    say "  ${C_GRAY}api_key .....${C_RESET} $(display_key "$name")"
    say
    newname="$(ask 'Nama baru (kosong = tetap)' "$name")"
    base="$(ask 'Base URL baru (kosong = tetap)' "$(provider_field "$name" 2)")"
    model="$(ask 'Default model baru (kosong = tetap)' "$(provider_field "$name" 4)")"
    say "${C_GRAY}  Tip: buat API key, kosongin aja kalau nggak mau ganti.${C_RESET}"
    key="$(ask_secret 'API key baru (kosong = tetap)')"

    [ "$name" = "$newname" ] && newname="-"
    [ "$base" = "$(provider_field "$name" 2)" ] && base="-"
    [ "$model" = "$(provider_field "$name" 4)" ] && model="-"
    [ -n "$key" ] || key="-"
    cmd_edit "$name" "$base" "$key" "$model" "$newname"
}

menu_delete() {
    clear_screen
    header "4. Hapus Provider" "Backup dulu, baru section-nya dibuang"
    say
    local name
    name="$(choose_provider 'Provider yang mau dihapus')" || return 0
    say
    warn "Yang bakal dihapus: [providers.$name] ($(provider_field "$name" 2))"
    confirm "Yakin hapus provider '$name'?" "${ASSUME_YES:-0}" || { warn "Dibatalin, provider aman."; return 0; }
    cmd_delete "$name"
}

menu_quick() {
    clear_screen
    header "5. Quick Start" "Template populer. Kamu cuma perlu masukin API key"
    say
    local i=1 key
    for key in $PRESET_KEYS; do
        printf '  %2d. %s%-20s%s%s\n' "$i" "$C_GREEN" "$(preset_field "$key" label)" "$C_RESET" "$C_GRAY$(preset_field "$key" base)$C_RESET"
        i=$((i + 1))
    done
    say
    local pick
    pick="$(ask 'Pilih nomor template (kosong = batal)')"
    [ -n "$pick" ] || return 0
    local arr=()
    for key in $PRESET_KEYS; do arr+=("$key"); done
    if ! [ "$pick" -ge 1 ] 2>/dev/null || [ "$pick" -gt "${#arr[@]}" ]; then warn "Pilihan nggak valid."; return 0; fi
    key="${arr[$((pick - 1))]}"
    say
    info "$(preset_field "$key" note)"
    say
    local name model base apikey msg
    name="$(ask 'Nama provider' "$key")"
    if ! msg="$(validate_name "$name")"; then err "$msg"; return 0; fi
    if provider_exists "$name"; then err "Provider '$name' udah ada. Ganti nama, atau pakai menu 3."; return 0; fi
    model="$(ask 'Model' "$(preset_field "$key" model)")"
    base="$(ask 'Base URL' "$(preset_field "$key" base)")"
    if ! msg="$(validate_url "$base")"; then err "$msg"; return 0; fi
    apikey="$(ask_secret 'API key')"
    [ -n "$apikey" ] || warn "API key kosong, provider bakal dibikin tanpa auth."
    say
    cmd_add "$name" "$base" "$apikey" "$model" 0
}

menu_generate() {
    clear_screen
    header "6. Generate Command" "Copy-paste langsung ke terminal"
    say
    local name model
    name="$(choose_provider 'Provider')" || return 0
    model="$(ask "Model (kosong = pakai default profile: $(provider_field "$name" 4))")"
    say
    say "${C_CYAN}  Command:${C_RESET}"
    say "  $C_BOLD$(cmd_generate "$name" "$model")$C_RESET"
    say
    if command -v xclip >/dev/null 2>&1; then
        if cmd_generate "$name" "$model" | xclip -selection clipboard 2>/dev/null; then ok "Command udah dicopy ke clipboard."; fi
    elif command -v xsel >/dev/null 2>&1; then
        if cmd_generate "$name" "$model" | xsel --clipboard --input 2>/dev/null; then ok "Command udah dicopy ke clipboard."; fi
    elif command -v pbcopy >/dev/null 2>&1; then
        if cmd_generate "$name" "$model" | pbcopy 2>/dev/null; then ok "Command udah dicopy ke clipboard."; fi
    else
        info "Clipboard nggak tersedia, copy manual aja dari atas."
    fi
    say
    say "${C_GRAY}  Catatan: kalau daemon jcode udah jalan, flag provider diabaikan.${C_RESET}"
    say "${C_GRAY}  Pakai menu 7 (Launch) biar daemon di-stop dulu otomatis.${C_RESET}"
}

menu_launch() {
    clear_screen
    header "7. Launch Provider" "Stop daemon dulu, baru start fresh"
    say
    local name model
    name="$(choose_provider 'Provider yang mau dipakai')" || return 0
    say
    warn "Daemon jcode bakal di-STOP. Session yang lagi jalan (headless/swarm) ikut keputus."
    confirm "Lanjut launch pakai profile '$name'?" "${ASSUME_YES:-0}" || { warn "Dibatalin."; return 0; }
    model="$(ask "Model (kosong = pakai default profile: $(provider_field "$name" 4))")"
    cmd_launch "$name" "$model"
    info "jcode keluar dengan kode $?."
}

menu_info() {
    clear_screen
    header "8. Info & Doctor" "Deteksi OS, path config, dan status jcode"
    say
    cmd_info
    say
    say "${C_GRAY}  - Config  : ~/.jcode/config.toml (Linux/macOS), %USERPROFILE%\\.jcode\\config.toml (Windows)${C_RESET}"
    say "${C_GRAY}  - Profile : jcode --provider openai-compatible --provider-profile <nama>${C_RESET}"
    say "${C_GRAY}  - Daemon  : jcode server stop --force   (wajib sebelum ganti provider)${C_RESET}"
}

menu_restore() {
    clear_screen
    header "9. Restore dari Backup" "Balikin config ke versi backup"
    say
    local backups count=0 pick
    backups="$(list_backups)"
    if [ -z "$backups" ]; then warn "Belum ada backup di $(dirname "$CONFIG_PATH")"; return 0; fi
    local arr=()
    while IFS= read -r b; do
        [ -n "$b" ] || continue
        arr+=("$b"); count=$((count + 1))
        printf '  %2d. %s%s%s\n' "$count" "$C_GREEN" "$(basename "$b")" "$C_RESET"
    done <<<"$backups"
    say
    pick="$(ask 'Pilih nomor backup (kosong = batal)')"
    if ! [ "$pick" -ge 1 ] 2>/dev/null || [ "$pick" -gt "${#arr[@]}" ]; then warn "Dibatalin."; return 0; fi
    say
    warn "Config sekarang bakal diganti isi $(basename "${arr[$((pick - 1))]}")"
    confirm "Lanjut restore?" "${ASSUME_YES:-0}" || { warn "Dibatalin."; return 0; }
    cmd_restore "${arr[$((pick - 1))]}"
}

menu_models() {
    clear_screen
    header "10. Kelola Model Provider" "Satu provider bisa punya banyak model"
    say
    local name def action id m pick idx=0 n=0
    name="$(choose_provider "Provider yang model-nya mau diatur")" || return 0
    [ -n "$name" ] || return 0
    def="$(provider_field "$name" 4)"
    say
    printf '  %sdefault ...%s %s\n' "$C_GRAY" "$C_RESET" "${def:-(belum diset)}"
    while IFS= read -r m; do
        [ -n "$m" ] || continue
        n=$((n + 1))
        if [ "$m" = "$def" ]; then
            printf '  %s%2d.%s %s%s (= default)%s\n' "$C_GRAY" "$n" "$C_RESET" "$C_CYAN" "$m" "$C_RESET"
        else
            printf '  %s%2d.%s %s\n' "$C_GRAY" "$n" "$C_RESET" "$m"
        fi
    done < <(provider_models "$name")
    if [ "$n" -eq 0 ]; then
        printf '  %s(belum ada model tambahan)%s\n' "$C_GRAY" "$C_RESET"
    fi
    say
    say "${C_GRAY}  1) Tambah model   2) Hapus model   3) Jadikan default   4) Ganti semua daftar${C_RESET}"
    action="$(ask 'Pilih aksi (kosong = batal)')"
    case "$action" in
        1)
            id="$(ask 'Nama model baru (contoh: gpt-4o)')"
            [ -n "$id" ] || { warn "Dibatalin."; return 0; }
            cmd_add_model "$name" "$id" ;;
        2)
            id="$(ask 'Model yang mau dihapus (nomor atau nama)')"
            [ -n "$id" ] || { warn "Dibatalin."; return 0; }
            case "$id" in
                *[!0-9]*|'') ;;
                *)
                    while IFS= read -r m; do
                        [ -n "$m" ] || continue
                        idx=$((idx + 1))
                        [ "$idx" = "$id" ] && pick="$m"
                    done < <(provider_models "$name")
                    if [ -n "${pick:-}" ]; then id="$pick"; fi ;;
            esac
            cmd_remove_model "$name" "$id" ;;
        3)
            id="$(ask 'Jadikan default model' "$def")"
            [ -n "$id" ] || { warn "Dibatalin."; return 0; }
            local existing
            existing="$(provider_models_csv "$name")"
            cmd_set_models "$name" "${existing:+$existing,}$id" "$id" ;;
        4)
            local cur
            cur="$(provider_models_csv "$name")"
            id="$(ask 'Daftar model lengkap (pisahin pakai koma)' "$cur")"
            [ -n "$id" ] || { warn "Dibatalin."; return 0; }
            cmd_set_models "$name" "$id" "$def" ;;
        *) warn "Dibatalin." ;;
    esac
}

interactive_menu() {
    local choice nprov
    while :; do
        nprov="$(provider_names | grep -c . || true)"
        clear_screen
        header "$APP_NAME" "v$VERSION | $PLATFORM | $CONFIG_PATH"
        say "${C_GRAY}  $nprov provider terdaftar${C_RESET}"
        say
        say "  ${C_GREEN}1) Tambah Provider Baru${C_RESET}"
        say "  ${C_GREEN}2) Lihat Semua Provider${C_RESET}"
        say "  ${C_GREEN}3) Edit Provider${C_RESET}"
        say "  ${C_GREEN}4) Hapus Provider${C_RESET}"
        say "  ${C_GREEN}5) Quick Start (OpenAI / Claude / Groq / OpenRouter)${C_RESET}"
        say "  ${C_GREEN}6) Generate Command${C_RESET}"
        say "  ${C_MAGENTA}7) Launch Provider  (stop daemon + start)${C_RESET}"
        say "  ${C_GRAY}8) Info & Doctor${C_RESET}"
        say "  ${C_GRAY}9) Restore dari Backup${C_RESET}"
        say "  ${C_GREEN}10) Kelola Model Provider${C_RESET}"
        say "  ${C_GRAY}0) Keluar${C_RESET}"
        say
        choice="$(ask 'Pilih menu (0 = keluar)')"
        case "$choice" in
            ""|0|q|quit|exit) break ;;
            1) menu_add ;;
            2) menu_list ;;
            3) menu_edit ;;
            4) menu_delete ;;
            5) menu_quick ;;
            6) menu_generate ;;
            7) menu_launch ;;
            8) menu_info ;;
            9) menu_restore ;;
            10) menu_models ;;
            *) warn "Menu '$choice' nggak ada. Coba lagi." ;;
        esac
        pause_key
    done
    say
    info "Sampai jumpa. Config kamu di $CONFIG_PATH"
    return 0
}

# --- argumen ---
usage() {
    cat <<'USAGE'
J-Code Provider Manager (bash engine)

  jcode-manager.sh [--config PATH] <aksi> [opsi]

Aksi:
  --list, -l             tampilkan semua provider (--json buat mesin)
  --info                 info OS, path config, status jcode
  --add NAMA             tambah provider (butuh --base-url)
  --edit NAMA            edit provider
  --delete NAMA          hapus provider (butuh --yes kalau non-interaktif)
  --quick PRESET         openai | anthropic | groq | openrouter
  --generate NAMA        cetak command jcode
  --launch NAMA          stop daemon terus start jcode
  --models NAMA          tampilkan daftar model satu provider
  --add-model NAMA=MODEL tambah model ke provider (boleh diulang)
  --remove-model NAMA=MODEL  hapus model dari provider (boleh diulang)
  --set-models NAMA=M1,M2    ganti seluruh daftar model provider
  --restore PATH         balikin config dari backup

Opsi field:
  --base-url URL   --api-key KEY   --api-key-stdin   --model MODEL
  --name NAMA      --new-name NAMA   --force   --json   --no-color   --yes

Tanpa aksi = menu interaktif.
USAGE
}

main() {
    local action="" target="" base="" key="" model="" newname="" name_opt=""
    local force=0 json=0 yes=0 apikey_stdin=0 restore_path=""
    local add_models="" remove_models=""
    CONFIG_OVERRIDE=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --config) CONFIG_OVERRIDE="${2:-}"; shift 2 ;;
            --list|-l) action="list"; shift ;;
            --info) action="info"; shift ;;
            --add) action="add"; target="${2:-}"; shift 2 ;;
            --edit) action="edit"; target="${2:-}"; shift 2 ;;
            --delete) action="delete"; target="${2:-}"; shift 2 ;;
            --quick) action="quick"; target="${2:-}"; shift 2 ;;
            --generate) action="generate"; target="${2:-}"; shift 2 ;;
            --launch) action="launch"; target="${2:-}"; shift 2 ;;
            --models) action="models"; target="${2:-}"; shift 2 ;;
            --add-model) add_models="${add_models}${2:-}"$'\n'; shift 2 ;;
            --remove-model) remove_models="${remove_models}${2:-}"$'\n'; shift 2 ;;
            --set-models) action="set-models"; target="${2:-}"; shift 2 ;;
            --restore) action="restore"; restore_path="${2:-}"; shift 2 ;;
            --base-url) base="${2:-}"; shift 2 ;;
            --api-key) key="${2:-}"; shift 2 ;;
            --api-key-stdin) apikey_stdin=1; shift ;;
            --model) model="${2:-}"; shift 2 ;;
            --name) name_opt="${2:-}"; shift 2 ;;
            --new-name) newname="${2:-}"; shift 2 ;;
            --force) force=1; shift ;;
            --json) json=1; shift ;;
            --yes|-y) yes=1; shift ;;
            --no-color) C_RESET=""; C_BOLD=""; C_CYAN=""; C_GREEN=""; C_MAGENTA=""; C_YELLOW=""; C_RED=""; C_GRAY=""; shift ;;
            --version) say "$APP_NAME $VERSION"; return 0 ;;
            -h|--help) usage; return 0 ;;
            *) err "Argumen nggak dikenal: $1"; usage >&2; return 2 ;;
        esac
    done

    if [ -z "$action" ] && { [ -n "$add_models" ] || [ -n "$remove_models" ]; }; then
        action="models-batch"
    fi

    [ "$apikey_stdin" = "1" ] && { IFS= read -r key 2>/dev/null || key=""; }

    detect_platform
    ASSUME_YES="$yes"

    case "$action" in
        list) cmd_list "$json" ;;
        info) cmd_info ;;
        add)
            [ -n "$base" ] || { err "--add butuh --base-url."; return 2; }
            cmd_add "$target" "$base" "$key" "$model" "$force" || return 1 ;;
        edit)
            cmd_edit "$target" "${base:--}" "${key:--}" "${model:--}" "${newname:--}" || return 1 ;;
        delete)
            confirm "Hapus provider '$target'?" "$yes" || { warn "Dibatalin, provider aman."; return 0; }
            cmd_delete "$target" || return 1 ;;
        quick)
            preset_valid "$target" || { err "Preset '$target' nggak ada. Pilihan: $PRESET_KEYS"; return 2; }
            local qname
            qname="${name_opt:-$target}"
            cmd_add "$qname" "${base:-$(preset_field "$target" base)}" "$key" "${model:-$(preset_field "$target" model)}" "$force" || return 1 ;;
        generate) cmd_generate "$target" "$model" || return 1 ;;
        models) cmd_models "$target" "$json" || return 1 ;;
        set-models)
            case "$target" in
                *=*) ;;
                *) err "--set-models butuh format NAMA=MODEL, contoh: mygw=gpt-4o."; return 2 ;;
            esac
            local sm_name="${target%%=*}" sm_csv="${target#*=}"
            [ -n "$sm_name" ] && [ -n "$sm_csv" ] || { err "--set-models butuh format NAMA=MODEL, contoh: mygw=gpt-4o."; return 2; }
            cmd_set_models "$sm_name" "$sm_csv" "$model" || return 1 ;;
        models-batch) cmd_models_batch "$add_models" "$remove_models" || return 1 ;;
        launch)
            confirm "Stop daemon terus launch '$target'?" "$yes" || { warn "Dibatalin."; return 0; }
            cmd_launch "$target" "$model"
            return $? ;;
        restore) cmd_restore "$restore_path" || return 1 ;;
        "") interactive_menu ;;
    esac
    return 0
}

main "$@"
exit $?
