#!/usr/bin/env bash
# Smoke test engine Bash (jalur fallback kalau Python nggak ada).
#
# Fokus: fitur inti yang dijanjiin spec harus tetap jalan tanpa Python.
# Semua pakai config sementara (--config), config asli kamu nggak disentuh.
#
#   bash tests/smoke-test-fallback.sh

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
MANAGER="$HERE/../jcode-manager.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/jcm-bash-test.XXXXXX")"
export XDG_CONFIG_HOME="$WORK/xdg"
export JCODE_MANAGER_ENGINE=bash
CONFIG="$WORK/config.toml"
PASS=0
FAIL=0

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
check() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}
check_not() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then fail "$label"; else pass "$label"; fi
}
contains() { grep -q -- "$2" "$1"; }

fixture() {
    cat >"$CONFIG" <<'TOML'
# komentar yang harus tetap ada
[provider]
default_provider = "legacygw"

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

run() { bash "$MANAGER" --config "$CONFIG" --no-color "$@"; }
toml_ok() { python3 -c "import tomllib; tomllib.load(open('$CONFIG','rb'))"; }

mkdir -p "$XDG_CONFIG_HOME/jcode"
printf 'JCODE_PROVIDER_LEGACYGW_API_KEY=sk-envfilerouter-abcdef123456\n' >"$XDG_CONFIG_HOME/jcode/provider-legacygw.env"

echo "== smoke test engine Bash (fallback tanpa Python) =="
echo "workdir: $WORK"
echo

fixture

echo "-- basic --"
check "--info jalan" run --info
run --info >"$WORK/info.txt" 2>&1
check "info nyebut engine bash" contains "$WORK/info.txt" 'bash'
check "info nyebut path config" contains "$WORK/info.txt" "$CONFIG"
check "--version jalan" run --version

echo "-- add --"
check "add provider baru" run --add alpha --base-url https://api.example.com/v1 \
    --api-key sk-1234567890abcdef --model gpt-4o
check "section alpha ada" contains "$CONFIG" '\[providers.alpha\]'
check "base_url kesimpan" contains "$CONFIG" 'https://api.example.com/v1'
check "default_model kesimpan" contains "$CONFIG" 'default_model = "gpt-4o"'
check "config tetap TOML valid" toml_ok
check_not "duplikat ditolak" run --add alpha --base-url https://x.example/v1 --api-key k
check_not "nama invalid ditolak" run --add "bad name" --base-url https://x.example/v1 --api-key k
check_not "base_url invalid ditolak" run --add badurl --base-url not-a-url --api-key k
check_not "add nggak nulis models[]" grep -q 'models = \[' "$CONFIG"

echo "-- backup --"
check "backup config dibikin" test "$(ls "$WORK"/config.toml.backup.* 2>/dev/null | wc -l)" -ge 1

echo "-- list & masking --"
run --list >"$WORK/list.txt" 2>&1
check "key di-mask" contains "$WORK/list.txt" 'sk-1\.\.\.cdef'
check_not "key mentah nggak muncul" grep -q 'sk-1234567890abcdef' "$WORK/list.txt"
check "key dari env file dibaca" contains "$WORK/list.txt" 'provider-legacygw.env'
check_not "key env file mentah nggak muncul" grep -q 'sk-envfilerouter-abcdef123456' "$WORK/list.txt"
run --list --json >"$WORK/list.json" 2>/dev/null
check "list --json valid" python3 -c "import json; json.load(open('$WORK/list.json'))"
check "json punya field name" contains "$WORK/list.json" '"name": "alpha"'

echo "-- edit --"
check "edit base_url" run --edit alpha --base-url https://new.example.com/v1
check "base_url keupdate" contains "$CONFIG" 'https://new.example.com/v1'
check "api_key tetap ada" contains "$CONFIG" 'sk-1234567890abcdef'
check_not "base_url nggak dobel" test "$(grep -c 'base_url = "https://new.example.com/v1"' "$CONFIG")" -gt 1
check "config masih valid setelah edit" toml_ok
check "edit model" run --edit alpha --model gpt-4o-mini
check "model keupdate" contains "$CONFIG" 'default_model = "gpt-4o-mini"'
check_not "edit tanpa perubahan ditolak" run --edit alpha --api-key ""
check_not "edit provider nggak ada = error" run --edit hantu --model x
check "rename provider" run --edit alpha --new-name beta
check "section baru ada" contains "$CONFIG" '\[providers.beta\]'
check_not "section lama hilang" grep -q '\[providers.alpha\]' "$CONFIG"
check "config masih valid setelah rename" toml_ok

echo "-- quick start --"
check "quick groq" run --quick groq --api-key gsk_testkey123456
check "base_url groq benar" contains "$CONFIG" 'https://api.groq.com/openai/v1'
check "model groq benar" contains "$CONFIG" 'llama-3.3-70b-versatile'
check_not "preset ngawur ditolak" run --quick nggak-ada --api-key k

echo "-- generate --"
run --generate beta >"$WORK/gen.txt" 2>&1
check "command pakai flag benar" contains "$WORK/gen.txt" -- '--provider openai-compatible --provider-profile beta'
check "command pakai model default" contains "$WORK/gen.txt" -- '--model gpt-4o-mini'
check_not "generate provider nggak ada = error" run --generate hantu

echo "-- launch (stub jcode) --"
STUB_DIR="$WORK/bin"
mkdir -p "$STUB_DIR"
cat >"$STUB_DIR/jcode" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$JCM_STUB_LOG"
exit 0
STUB
chmod +x "$STUB_DIR/jcode"
export JCM_STUB_LOG="$WORK/stub.log"
PATH="$STUB_DIR:$PATH" run --launch beta --yes >"$WORK/launch.txt" 2>&1
check "launch stop daemon dulu" grep -q '^server stop --force$' "$JCM_STUB_LOG"
check "launch pakai flag provider + profile" grep -q 'provider openai-compatible --provider-profile beta' "$JCM_STUB_LOG"
check "urutan stop sebelum start" test "$(head -1 "$JCM_STUB_LOG")" = "server stop --force"

echo "-- delete --"
check "delete groq" run --delete groq --yes
check_not "section groq hilang" grep -q '\[providers.groq\]' "$CONFIG"
check "legacygw masih ada" contains "$CONFIG" '\[providers.legacygw\]'
check "sub-table models masih ada" contains "$CONFIG" '\[\[providers.legacygw.models\]\]'
check "komentar asli kepertahanin" contains "$CONFIG" '# komentar yang harus tetap ada'
check_not "delete provider nggak ada = error" run --delete hantu --yes
check "config masih valid setelah delete" toml_ok

echo "-- restore --"
BACKUP="$(ls -1t "$WORK"/config.toml.backup.* | head -1)"
check "restore dari backup" run --restore "$BACKUP"
check "config masih valid setelah restore" toml_ok

echo "-- menu interaktif --"
printf '2\n\n0\n' | run >"$WORK/menu.txt" 2>&1
check "menu jalan" contains "$WORK/menu.txt" 'Lihat Semua Provider'
check "menu bisa keluar bersih" contains "$WORK/menu.txt" 'Sampai jumpa'

echo "-- delegasi ke Python --"
if command -v python3 >/dev/null 2>&1; then
    JCODE_MANAGER_ENGINE=auto bash "$MANAGER" --config "$CONFIG" --no-color --info >"$WORK/auto.txt" 2>&1
    if grep -q 'bash (tanpa Python)' "$WORK/auto.txt"; then
        fail "mode auto harus delegasi ke Python"
    else
        pass "mode auto delegasi ke Python"
    fi
    # Lewat symlink (kayak di PATH) folder script harus tetap ketemu.
    ln -sfn "$MANAGER" "$WORK/bin/jcode-manager"
    if JCODE_MANAGER_ENGINE=auto "$WORK/bin/jcode-manager" --version 2>&1 | grep -q 'bash engine'; then
        fail "lewat symlink tetap delegasi ke Python"
    else
        pass "lewat symlink tetap delegasi ke Python"
    fi
    # Python dipaksa nggak ada -> harus jatuh ke engine Bash
    mkdir -p "$WORK/shadow"
    for n in python3 python py; do
        printf '#!/bin/sh\nexit 1\n' >"$WORK/shadow/$n"
        chmod +x "$WORK/shadow/$n"
    done
    if env PATH="$WORK/shadow:$PATH" JCODE_MANAGER_ENGINE=auto bash "$MANAGER" --config "$CONFIG" --no-color --info 2>/dev/null | grep -q 'bash (tanpa Python)'; then
        pass "tanpa Python otomatis jatuh ke engine Bash"
    else
        fail "tanpa Python otomatis jatuh ke engine Bash"
    fi
fi

echo
echo "== hasil: $PASS ok, $FAIL fail =="
[ "$FAIL" -eq 0 ]
