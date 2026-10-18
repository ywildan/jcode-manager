#!/usr/bin/env bash
# Smoke test J-Code Provider Manager.
# Semua test pakai config sementara (--config), jadi config asli kamu nggak disentuh.
#
#   bash tests/smoke-test.sh
#
# Exit code 0 = semua lolos.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
MANAGER="$HERE/../jcode-manager.py"
PY="${PYTHON:-python3}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/jcm-test.XXXXXX")"
export XDG_CONFIG_HOME="$WORK/xdg"   # env file provider diarahkan ke temp
# Env var nggak ikut dikonversi otomatis oleh Git Bash/MSYS (beda dari argumen),
# jadi di Windows dikasih bentuk native-nya biar Python nunjuk folder yang sama.
APP_CONF_DIR="$XDG_CONFIG_HOME/jcode"
if command -v cygpath >/dev/null 2>&1; then
    APP_CONF_DIR="$(cygpath -w "$APP_CONF_DIR")"
fi
export JCODE_MANAGER_APP_CONFIG="$APP_CONF_DIR"
CONFIG="$WORK/config.toml"
PASS=0
FAIL=0
SKIP=0

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
skip() { SKIP=$((SKIP + 1)); printf '  skip %s\n' "$1"; }

# Git Bash/MSYS: nggak ada mode POSIX beneran, jadi cek permission dilewat.
is_windows() { case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) return 0 ;; *) return 1 ;; esac; }

file_mode() { # portabel: GNU stat (-c) vs BSD stat (-f)
    if stat -c '%a' "$1" >/dev/null 2>&1; then
        stat -c '%a' "$1"
    else
        stat -f '%Lp' "$1"
    fi
}
check() { # check <label> <command...>
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

check_not() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then fail "$label"; else pass "$label"; fi
}

contains() { grep -q -- "$2" "$1"; }
lacks() { ! grep -q -- "$2" "$1"; }

fixture() {
    cat >"$CONFIG" <<'TOML'
# komentar yang harus tetap ada
[provider]
default_provider = "legacygw"
default_model = "legacy-model-1"

[providers.legacygw]
type = "openai-compatible"
base_url = "http://localhost:8080/v1"
auth = "bearer"
api_key_env = "JCODE_PROVIDER_LEGACYGW_API_KEY"
env_file = "provider-legacygw.env"
default_model = "legacy-model-1"
requires_api_key = true

[[providers.legacygw.models]]
id = "legacy-model-1"
TOML
}

run() { "$PY" "$MANAGER" --config "$CONFIG" --no-color "$@"; }

echo "== J-Code Provider Manager smoke test =="
echo "workdir: $WORK"
echo

fixture

echo "-- launch (stub jcode, daemon asli nggak disentuh) --"
if is_windows; then
    # Engine nyari binary jcode lewat shutil.which, yang di Windows nggak
    # nemuin file tanpa ekstensi (butuh .exe/.cmd/.bat), jadi stub bash
    # nggak bisa dipakai di sini. Bagian lain tetap jalan di Windows.
    skip "launch pakai stub jcode (Windows: shutil.which butuh ekstensi)"
else
    STUB_DIR="$WORK/bin"
    mkdir -p "$STUB_DIR"
    cat >"$STUB_DIR/jcode" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$JCM_STUB_LOG"
exit 0
STUB
    chmod +x "$STUB_DIR/jcode"
    export JCM_STUB_LOG="$WORK/stub.log"
    fixture
    run --add launcher --base-url https://api.launch.example/v1 --api-key sk-launch-abcdef123456 --model launch-model >/dev/null 2>&1
    PATH="$STUB_DIR:$PATH" run --launch launcher --yes >"$WORK/launch.txt" 2>&1
    if grep -q '^server stop --force$' "$JCM_STUB_LOG" 2>/dev/null; then
        pass "launch stop daemon dulu (server stop --force)"
    else
        fail "launch stop daemon dulu (server stop --force)"
    fi
    if grep -q 'provider openai-compatible --provider-profile launcher --model launch-model' "$JCM_STUB_LOG" 2>/dev/null; then
        pass "launch pakai flag provider + profile + model"
    else
        fail "launch pakai flag provider + profile + model"
    fi
    if [ "$(head -1 "$JCM_STUB_LOG" 2>/dev/null)" = "server stop --force" ]; then
        pass "urutan: stop daemon sebelum start"
    else
        fail "urutan: stop daemon sebelum start"
    fi
fi

echo "-- portabilitas --"
# Klaim "Python 3.8+" diverifikasi di level syntax pakai ast: kalau ada syntax
# yang baru ada di 3.9/3.10+, parse-nya langsung gagal.
check "syntax kompatibel Python 3.8" "$PY" -c "
import ast, sys
src = open(sys.argv[1]).read()
ast.parse(src, feature_version=(3, 8))
" "$MANAGER"
check "test deteksi OS/path (Windows/macOS/Linux) lolos" env -u JCODE_MANAGER_APP_CONFIG "$PY" -W ignore "$HERE/test-platform-paths.py"
# Shadow python3/python/py dengan stub yang selalu gagal, jadi launcher harus
# nyimpulin nggak ada Python yang layak. PATH sengaja TIDAK dikosongin, karena
# shebang `#!/usr/bin/env bash` sendiri butuh bash di PATH.
mkdir -p "$WORK/shadow"
for n in python3 python py; do
    printf '#!/bin/sh\nexit 1\n' >"$WORK/shadow/$n"
    chmod +x "$WORK/shadow/$n"
done
if env PATH="$WORK/shadow:$PATH" JCODE_MANAGER_ENGINE="" "$HERE/../jcode-manager.sh" --version 2>&1 | grep -q 'bash engine'; then
    pass "tanpa Python launcher jatuh ke engine Bash"
else
    fail "tanpa Python launcher jatuh ke engine Bash"
fi
if env PATH="$WORK/shadow:$PATH" JCODE_MANAGER_ENGINE=python "$HERE/../jcode-manager.sh" --version 2>&1 | grep -q 'Python'; then
    pass "engine Python dipaksa tanpa Python = pesan jelas"
else
    fail "engine Python dipaksa tanpa Python = pesan jelas"
fi

fixture

echo "-- basic --"
check "--info jalan" run --info
run --info >"$WORK/info.txt" 2>&1
check "info nyebut path config" contains "$WORK/info.txt" "$CONFIG"

echo "-- add --"
check "add provider baru" run --add alpha --base-url https://api.example.com/v1 \
    --api-key sk-1234567890abcdef --model gpt-4o
run --list >"$WORK/list1.txt" 2>&1
check "section alpha ada" contains "$CONFIG" '\[providers.alpha\]'
check "base_url alpha kesimpan" contains "$CONFIG" 'https://api.example.com/v1'
check "default_model alpha kesimpan" contains "$CONFIG" 'default_model = "gpt-4o"'
check "duplikat ditolak" check_not "dup" run --add alpha --base-url https://x.example/v1 --api-key k
check_not "add nama invalid ditolak" run --add "bad name" --base-url https://x.example/v1 --api-key k
check_not "add base_url invalid ditolak" run --add badurl --base-url not-a-url --api-key k
check_not "add models[] nggak dipakai" grep -q 'models = \[' "$CONFIG"

echo "-- backup --"
ls "$WORK"/config.toml.backup.* >/dev/null 2>&1
check "backup config dibikin" test "$(ls "$WORK"/config.toml.backup.* 2>/dev/null | wc -l)" -ge 1

echo "-- list & masking --"
check "key di-mask di list" contains "$WORK/list1.txt" 'sk-1\.\.\.cdef'
check_not "key mentah nggak muncul di list" grep -q 'sk-1234567890abcdef' "$WORK/list1.txt"
check "env-file provider kebaca" contains "$WORK/list1.txt" 'provider-legacygw.env'
run --list --json >"$WORK/list.json" 2>/dev/null
check "list --json valid" "$PY" -c "import json, sys; json.load(open(sys.argv[1]))" "$WORK/list.json"
check "json punya field name" contains "$WORK/list.json" '"name": "alpha"'

echo "-- edit --"
check "edit base_url" run --edit alpha --base-url https://new.example.com/v1
run --list >"$WORK/list2.txt" 2>&1
check "base_url keupdate" contains "$CONFIG" 'https://new.example.com/v1'
check "api_key tetap ada setelah edit" contains "$CONFIG" 'sk-1234567890abcdef'
check "model nggak berubah" contains "$CONFIG" 'default_model = "gpt-4o"'
check_not "edit tanpa perubahan ditolak (nggak ngerusak apa-apa)" run --edit alpha --api-key ""
check "api_key masih sama" contains "$CONFIG" 'sk-1234567890abcdef'
check "edit model" run --edit alpha --model gpt-4o-mini
check "model keupdate" contains "$CONFIG" 'default_model = "gpt-4o-mini"'
check_not "edit provider nggak ada = error" run --edit hantu --model x
check "rename provider" run --edit alpha --new-name beta
check "section baru ada" contains "$CONFIG" '\[providers.beta\]'
check_not "section lama hilang" grep -q '\[providers.alpha\]' "$CONFIG"

echo "-- quick start --"
check "quick groq" run --quick groq --api-key gsk_testkey123456
check "base_url groq benar" contains "$CONFIG" 'https://api.groq.com/openai/v1'
check "model groq benar" contains "$CONFIG" 'llama-3.3-70b-versatile'
check_not "preset ngawur ditolak" run --quick nggak-ada --api-key k

echo "-- generate --"
run --generate beta >"$WORK/gen.txt" 2>&1
check "command pake flag yang benar" contains "$WORK/gen.txt" -- '--provider openai-compatible --provider-profile beta'
check "command pake model default" contains "$WORK/gen.txt" -- '--model gpt-4o-mini'
check_not "generate provider nggak ada = error" run --generate hantu

echo "-- env-file key store --"
check "add mode envfile" run --add envguy --base-url https://env.example/v1 --api-key sk-envkey-9876543210 --model m1 --key-store envfile
check "config pakai api_key_env" contains "$CONFIG" 'api_key_env = "JCODE_PROVIDER_ENVGUY_API_KEY"'
check "config pakai env_file" contains "$CONFIG" 'env_file = "provider-envguy.env"'
check "env file kebikin" test -f "$XDG_CONFIG_HOME/jcode/provider-envguy.env"
check "env file isinya benar" contains "$XDG_CONFIG_HOME/jcode/provider-envguy.env" 'JCODE_PROVIDER_ENVGUY_API_KEY=sk-envkey-9876543210'
if is_windows; then
    skip "env file mode 600 (Windows nggak punya mode POSIX)"
else
    check "env file mode 600" test "$(file_mode "$XDG_CONFIG_HOME/jcode/provider-envguy.env")" = "600"
fi
check_not "api key nggak ditulis ke config (mode envfile)" grep -q 'sk-envkey-9876543210' "$CONFIG"

echo "-- config validity --"
check "config hasil akhir TOML valid" "$PY" -c "
import sys, tomllib
tomllib.load(open(sys.argv[1], 'rb'))
" "$CONFIG"
check "komentar asli kepertahanin" contains "$CONFIG" '# komentar yang harus tetap ada'
check "provider lain (legacygw) utuh" contains "$CONFIG" 'api_key_env = "JCODE_PROVIDER_LEGACYGW_API_KEY"'
check "sub-table models legacygw utuh" contains "$CONFIG" '\[\[providers.legacygw.models\]\]'

echo "-- delete --"
check "delete envguy" run --delete envguy --yes
check_not "section envguy hilang" grep -q '\[providers.envguy\]' "$CONFIG"
check "legacygw masih ada" contains "$CONFIG" '\[providers.legacygw\]'
check "models legacygw masih ada" contains "$CONFIG" 'id = "legacy-model-1"'
check_not "delete provider nggak ada = error" run --delete hantu --yes
check "config masih valid setelah delete" "$PY" -c "
import sys, tomllib
tomllib.load(open(sys.argv[1], 'rb'))
" "$CONFIG"

echo "-- restore --"
BACKUP="$(ls -1 "$WORK"/config.toml.backup.* | head -1)"
check "restore dari backup" run --restore "$BACKUP"
check "config masih valid setelah restore" "$PY" -c "
import sys, tomllib
tomllib.load(open(sys.argv[1], 'rb'))
" "$CONFIG"

echo "-- menu interaktif --"
printf '2\n\n0\n' | run >"$WORK/menu.txt" 2>&1
check "menu jalan (list + keluar)" contains "$WORK/menu.txt" 'Lihat Semua Provider'
check "menu bisa keluar bersih" contains "$WORK/menu.txt" 'Sampai jumpa'

echo
echo "== hasil: $PASS ok, $FAIL fail, $SKIP skip =="
[ "$FAIL" -eq 0 ]
