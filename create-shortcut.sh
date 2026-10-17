#!/usr/bin/env bash
# Bikin shortcut / symlink buat J-Code Provider Manager.
#
#   ./create-shortcut.sh                  # symlink ke ~/.local/bin/jcode-manager
#   ./create-shortcut.sh --bin-dir /usr/local/bin
#   ./create-shortcut.sh --entry python  # nunjuk ke jcode-manager.py langsung
#   ./create-shortcut.sh --desktop        # + entry menu aplikasi (Linux)
#   ./create-shortcut.sh --uninstall      # hapus symlink & desktop entry
#
# Windows: script ini nggak bikin .lnk (beda format). Lihat pesan di akhir
# atau pakai perintah PowerShell yang ditampilin.

set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
# Default: launcher .sh, karena dia jalan dengan atau tanpa Python.
# Pakai --entry python kalau mau langsung nunjuk ke jcode-manager.py.
ENTRY="sh"
TARGET="$HERE/jcode-manager.sh"
NAME="jcode-manager"
BIN_DIR=""
DO_DESKTOP=0
DO_UNINSTALL=0

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --bin-dir)
            BIN_DIR="${2:-}"
            [ -n "$BIN_DIR" ] || { echo "--bin-dir butuh argumen" >&2; exit 2; }
            shift 2
            ;;
        --name)
            NAME="${2:-}"
            [ -n "$NAME" ] || { echo "--name butuh argumen" >&2; exit 2; }
            shift 2
            ;;
        --entry)
            ENTRY="${2:-}"
            case "$ENTRY" in
                sh|bash) TARGET="$HERE/jcode-manager.sh" ;;
                python|py) TARGET="$HERE/jcode-manager.py" ;;
                *) echo "--entry harus 'sh' atau 'python'" >&2; exit 2 ;;
            esac
            shift 2
            ;;
        --desktop) DO_DESKTOP=1; shift ;;
        --uninstall) DO_UNINSTALL=1; shift ;;
        -h|--help) usage 0 ;;
        *) echo "Argumen nggak dikenal: $1" >&2; usage 2 ;;
    esac
done

[ -f "$TARGET" ] || { echo "Nggak ketemu: $TARGET" >&2; exit 1; }
chmod +x "$TARGET" 2>/dev/null || true

# Pilih folder bin default.
if [ -z "$BIN_DIR" ]; then
    if [ -d "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then
        BIN_DIR="$HOME/.local/bin"
    else
        BIN_DIR="/usr/local/bin"
    fi
fi

LINK="$BIN_DIR/$NAME"
DESKTOP_FILE="$HOME/.local/share/applications/$NAME.desktop"

if [ "$DO_UNINSTALL" -eq 1 ]; then
    if [ -L "$LINK" ] || [ -f "$LINK" ]; then
        rm -f "$LINK"
        echo "Dihapus: $LINK"
    else
        echo "Nggak ada symlink di $LINK"
    fi
    if [ -f "$DESKTOP_FILE" ]; then
        rm -f "$DESKTOP_FILE"
        echo "Dihapus: $DESKTOP_FILE"
    fi
    exit 0
fi

# Bikin symlink. Kalau folder sistem butuh sudo, kasih tau aja.
if ! mkdir -p "$BIN_DIR" 2>/dev/null; then
    echo "Nggak bisa bikin $BIN_DIR, coba: sudo $0 --bin-dir $BIN_DIR" >&2
    exit 1
fi

if [ -e "$LINK" ] && [ ! -L "$LINK" ]; then
    echo "$LINK udah ada dan bukan symlink. Pindahin dulu biar nggak ketimpa." >&2
    exit 1
fi

if ! ln -sfn "$TARGET" "$LINK" 2>/dev/null; then
    echo "Gagal bikin symlink di $BIN_DIR (permission). Coba: sudo $0 --bin-dir $BIN_DIR" >&2
    exit 1
fi
chmod +x "$TARGET" 2>/dev/null || true
echo "Symlink dibuat: $LINK -> $TARGET"

# Desktop entry (Linux) biar muncul di menu aplikasi.
if [ "$DO_DESKTOP" -eq 1 ] && [ "$(uname -s)" = "Linux" ]; then
    mkdir -p "$(dirname "$DESKTOP_FILE")"
    cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=J-Code Provider Manager
Comment=Kelola provider jcode CLI (add/list/edit/delete/launch)
Exec=$TARGET
Terminal=true
Categories=Development;Utility;
EOF
    echo "Desktop entry dibuat: $DESKTOP_FILE"
fi

# Cek PATH.
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo
        echo "Catatan: $BIN_DIR belum ada di PATH."
        echo "Tambahin baris ini ke ~/.bashrc atau ~/.zshrc:"
        echo "  export PATH=\"$BIN_DIR:\$PATH\""
        ;;
esac

# Verifikasi cepat.
if command -v "$NAME" >/dev/null 2>&1; then
    echo
    echo "Tes jalan: $NAME --version"
    "$NAME" --version || true
else
    echo
    echo "Belum bisa dipanggil dari PATH. Tes manual: $LINK --version"
fi

cat <<'EOF'

Windows (PowerShell), bikin shortcut desktop manual:

  $mgr = "C:\path\ke\jcode-manager"
  $ws  = New-Object -ComObject WScript.Shell
  $lnk = $ws.CreateShortcut("$env:USERPROFILE\Desktop\J-Code Provider Manager.lnk")
  $lnk.TargetPath = "powershell.exe"
  $lnk.Arguments  = "-NoExit -ExecutionPolicy Bypass -File `"$mgr\jcode-manager.ps1`""
  $lnk.WorkingDirectory = $mgr
  $lnk.Save()

EOF
