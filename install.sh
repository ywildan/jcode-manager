#!/usr/bin/env bash
# Install J-Code Provider Manager buat kamu yang baru nerima folder ini.
#
#   ./install.sh                 # cek dependency + pasang symlink di ~/.local/bin
#   ./install.sh --no-link       # cuma cek, nggak ngubah apa-apa
#   ./install.sh --bin-dir /usr/local/bin
#
# Script ini nggak nyentuh config jcode kamu. Yang dilakuin cuma:
#   1. chmod +x script yang perlu
#   2. cek jcode, Python, dan bash ada atau nggak
#   3. bikin symlink (opsional)
#   4. jalanin --info biar kamu liat path yang bakal dipakai

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
DO_LINK=1
BIN_DIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --no-link) DO_LINK=0; shift ;;
        --bin-dir)
            BIN_DIR="${2:-}"
            [ -n "$BIN_DIR" ] || { echo "--bin-dir butuh argumen" >&2; exit 2; }
            shift 2
            ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Argumen nggak dikenal: $1" >&2; exit 2 ;;
    esac
done

echo "== J-Code Provider Manager: install =="
echo "folder: $HERE"
echo

# 1. permission
chmod +x "$HERE/jcode-manager.py" "$HERE/jcode-manager.sh" "$HERE/create-shortcut.sh" 2>/dev/null || true
for f in "$HERE"/tests/*.sh; do
    [ -f "$f" ] && chmod +x "$f" 2>/dev/null
done
echo "[1/4] script ditandai executable"

# 2. dependency
HAS_JCODE=0
if command -v jcode >/dev/null 2>&1; then
    HAS_JCODE=1
    echo "[2/4] jcode ketemu: $(command -v jcode)"
else
    echo "[2/4] jcode NGGAK ketemu di PATH"
    echo "      install dulu: https://github.com/1jehuang/jcode"
    echo "      manager tetap bisa dipakai buat nulis config, tapi nggak bisa nge-launch jcode"
fi

HAS_PY=0
for cand in "${JCODE_MANAGER_PYTHON:-}" python3 python py; do
    [ -n "$cand" ] || continue
    if command -v "$cand" >/dev/null 2>&1 &&
        "$cand" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
        HAS_PY=1
        echo "      Python: $cand ($("$cand" -c 'import sys;print(".".join(map(str,sys.version_info[:3])))'))"
        break
    fi
done
if [ "$HAS_PY" = "0" ]; then
    echo "      Python 3.8+ nggak ada, bakal jalan pakai engine Bash (fitur inti tetap jalan)"
fi
if command -v bash >/dev/null 2>&1; then
    echo "      bash: $(bash --version | head -1)"
fi
echo

# 3. symlink
if [ "$DO_LINK" = "1" ]; then
    if [ -n "$BIN_DIR" ]; then
        "$HERE/create-shortcut.sh" --bin-dir "$BIN_DIR"
    else
        "$HERE/create-shortcut.sh"
    fi
else
    echo "[3/4] symlink dilewat (--no-link)"
fi
echo

# 4. verifikasi
echo "[4/4] cek jalan:"
if [ "$HAS_PY" = "1" ]; then
    INFO_OUT="$(python3 "$HERE/jcode-manager.py" --info 2>/dev/null)"
else
    INFO_OUT="$(bash "$HERE/jcode-manager.sh" --info 2>/dev/null)"
fi
printf '%s\n' "$INFO_OUT"

CONFIG_SHOWN="$(printf '%s\n' "$INFO_OUT" | awk '/^Config/ && !/^Config file/ { sub(/^Config[.[:space:]]*/, ""); print; exit }')"

echo
echo "== beres =="
echo
echo "Langkah berikutnya:"
echo "  1. Buka terminal, ketik: jcode-manager"
echo "     (kalau belum masuk PATH, jalanin: $HERE/jcode-manager.sh)"
echo "  2. Menu 5 = Quick Start (OpenAI / Claude / Groq / OpenRouter), cuma perlu API key"
echo "  3. Menu 1 = tambah provider custom (butuh base_url + API key + model)"
echo "  4. Menu 7 = launch jcode pakai provider itu (daemon di-stop dulu otomatis)"
echo
if [ -n "$CONFIG_SHOWN" ]; then
    echo "Config kamu ada di: $CONFIG_SHOWN"
else
    echo "Config kamu ada di path default jcode (lihat baris 'Config' di atas)"
fi
