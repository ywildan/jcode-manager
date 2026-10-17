#!/usr/bin/env bash
# Acceptance test: config yang dibikin J-Code Provider Manager harus beneran
# kepakai sama binary jcode asli (bukan cuma "TOML valid").
#
# Yang dicek:
#   1. jcode bisa baca config-nya (`jcode provider current`)
#   2. default_model dari profile kepakai
#   3. chat beneran jalan lewat mock server OpenAI-compatible
#   4. API key beneran dikirim sebagai header Authorization
#   5. mode --key-store envfile juga jalan
#
# Semua dijalankan di dalam sandbox bubblewrap dengan HOME terpisah,
# jadi config asli kamu (dan daemon yang jalan) nggak disentuh.
#
#   bash tests/verify-with-jcode.sh
#
# Butuh: python3, bubblewrap (bwrap), dan binary jcode.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
MANAGER="$HERE/../jcode-manager.py"
PY="${PYTHON:-python3}"
PORT="${MOCK_PORT:-20999}"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

if ! command -v bwrap >/dev/null 2>&1; then
    echo "SKIP: bubblewrap (bwrap) nggak ada, test ini butuh sandbox."
    exit 0
fi

JCODE_BIN="$(command -v jcode || true)"
if [ -z "$JCODE_BIN" ]; then
    echo "SKIP: binary jcode nggak ketemu di PATH."
    exit 0
fi
JCODE_DIR="$(cd "$(dirname "$(readlink -f "$JCODE_BIN")")" && pwd)"

# Sandbox dir HARUS di luar HOME, karena HOME-nya kita bind-mount.
ISO="${ISO_DIR:-/var/tmp/jcm-iso-verify}"
mkdir -p "$ISO/bin" "$ISO/home/.jcode" "$ISO/xdg"
cp "$JCODE_DIR"/* "$ISO/bin/" 2>/dev/null || cp "$JCODE_DIR/jcode" "$ISO/bin/"
MOCK_LOG="$ISO/mock.log"
MOCK_OUT="$ISO/mock.out"

cleanup() {
    # Matiin daemon sandbox kalau masih nyala (socket terpisah, bukan daemon asli).
    if [ -n "${DAEMON_SOCK:-}" ] && [ -S "$DAEMON_SOCK" ]; then
        bwrap --dev-bind / / --bind "$ISO/home" "$HOME" "${UNSET_ARGS[@]:-}" "${SANDBOX_ENV[@]:-}" \
            "$ISO/bin/jcode" --socket "$DAEMON_SOCK" server stop --force >/dev/null 2>&1
    fi
    [ -n "${MOCK_PID:-}" ] && kill "$MOCK_PID" 2>/dev/null
    return 0
}
trap cleanup EXIT

echo "== acceptance test pakai binary jcode asli =="
echo "jcode : $JCODE_DIR"
echo "sandbox: $ISO (HOME terpisah, config asli nggak disentuh)"
echo

"$PY" "$HERE/mock-openai-server.py" "$PORT" "$MOCK_LOG" >"$MOCK_OUT" 2>&1 &
MOCK_PID=$!
sleep 1

if ! curl -s -m 3 "http://127.0.0.1:$PORT/v1/models" | grep -q mock-model; then
    echo "GAGAL: mock server nggak jalan di port $PORT (lihat $MOCK_OUT)"
    exit 1
fi
pass "mock server jalan di port $PORT"

SANDBOX_ENV=(--setenv JCODE_NO_TELEMETRY 1)

# Env jcode dari shell pemanggil (mis. JCODE_OPENROUTER_MODEL) bisa nimpa config,
# jadi dibersihin dulu biar test-nya beneran ngukur isi config.
UNSET_ARGS=()
while IFS='=' read -r env_name _; do
    case "$env_name" in
        JCODE_*)
            [ "$env_name" = "JCODE_NO_TELEMETRY" ] || UNSET_ARGS+=(--unsetenv "$env_name")
            ;;
    esac
done < <(env)

run_in_sandbox() { # run_in_sandbox <xdg_or_empty> <jcode args...>
    local xdg="$1"; shift
    local args=(--dev-bind / / --bind "$ISO/home" "$HOME" "${UNSET_ARGS[@]}" "${SANDBOX_ENV[@]}")
    if [ -n "$xdg" ]; then
        args+=(--setenv XDG_CONFIG_HOME "$xdg")
    fi
    bwrap "${args[@]}" "$ISO/bin/jcode" "$@"
}

inline_config() {
    "$PY" "$MANAGER" --config "$ISO/config-inline.toml" --no-color --add mockgw \
        --base-url "http://127.0.0.1:$PORT/v1" --api-key sk-mock-1234567890abcdef \
        --model mock-model --force >/dev/null 2>&1
}

echo "-- config inline --"
if inline_config; then pass "manager bikin config provider"; else fail "manager bikin config provider"; fi

cp "$ISO/config-inline.toml" "$ISO/home/.jcode/config.toml"

run_in_sandbox "" provider current -p openai-compatible --provider-profile mockgw >"$ISO/current.txt" 2>&1
if grep -q "resolved_provider" "$ISO/current.txt"; then
    pass "jcode baca config tanpa error"
else
    fail "jcode baca config tanpa error"
    sed -n '1,10p' "$ISO/current.txt"
fi
if grep -q "selected_model.*mock-model" "$ISO/current.txt"; then
    pass "default_model dari profile kepakai"
else
    fail "default_model dari profile kepakai ($(grep selected_model "$ISO/current.txt" || true))"
fi

: >"$MOCK_LOG"
run_in_sandbox "" --no-update --provider openai-compatible --provider-profile mockgw run "balas PONG" >"$ISO/run.txt" 2>&1
if grep -q "PONG" "$ISO/run.txt"; then
    pass "chat jalan lewat mock server"
else
    fail "chat jalan lewat mock server"
    sed -n '1,10p' "$ISO/run.txt"
fi
if grep -q "auth=Bearer sk-mock-1234567890abcdef" "$MOCK_LOG"; then
    pass "api_key dikirim sebagai Bearer token"
else
    fail "api_key dikirim sebagai Bearer token"
    sed -n '1,5p' "$MOCK_LOG"
fi

echo "-- config mode envfile --"
if XDG_CONFIG_HOME="$ISO/xdg" "$PY" "$MANAGER" --config "$ISO/config-envfile.toml" --no-color --add mockenv \
    --base-url "http://127.0.0.1:$PORT/v1" --api-key sk-envmode-abcdef123456 --model mock-model \
    --key-store envfile --force >/dev/null 2>&1; then
    pass "manager bikin provider mode envfile"
else
    fail "manager bikin provider mode envfile"
fi
if [ -f "$ISO/xdg/jcode/provider-mockenv.env" ]; then
    pass "env file privat kebikin"
else
    fail "env file privat kebikin"
fi
if [ "$(stat -c '%a' "$ISO/xdg/jcode/provider-mockenv.env" 2>/dev/null)" = "600" ]; then
    pass "env file mode 600"
else
    fail "env file mode 600"
fi

cp "$ISO/config-envfile.toml" "$ISO/home/.jcode/config.toml"
: >"$MOCK_LOG"
run_in_sandbox "$ISO/xdg" --no-update --provider openai-compatible --provider-profile mockenv run "balas PONG" >"$ISO/run2.txt" 2>&1
if grep -q "PONG" "$ISO/run2.txt"; then
    pass "chat jalan pakai key dari env file"
else
    fail "chat jalan pakai key dari env file"
    sed -n '1,10p' "$ISO/run2.txt"
fi
if grep -q "auth=Bearer sk-envmode-abcdef123456" "$MOCK_LOG"; then
    pass "key dari env file terkirim bener"
else
    fail "key dari env file terkirim bener"
    sed -n '1,5p' "$MOCK_LOG"
fi

echo "-- config dari engine Bash (fallback tanpa Python) --"
if JCODE_MANAGER_ENGINE=bash bash "$HERE/../jcode-manager.sh" --config "$ISO/config-bash.toml" --no-color \
    --add bashgw --base-url "http://127.0.0.1:$PORT/v1" --api-key sk-bashengine-abcdef123456 \
    --model mock-model --force >/dev/null 2>&1; then
    pass "engine Bash bikin config provider"
else
    fail "engine Bash bikin config provider"
fi
cp "$ISO/config-bash.toml" "$ISO/home/.jcode/config.toml"
run_in_sandbox "" provider current -p openai-compatible --provider-profile bashgw >"$ISO/current-bash.txt" 2>&1
if grep -q "resolved_provider" "$ISO/current-bash.txt"; then
    pass "jcode baca config hasil engine Bash"
else
    fail "jcode baca config hasil engine Bash"
    sed -n '1,10p' "$ISO/current-bash.txt"
fi
: >"$MOCK_LOG"
run_in_sandbox "" --no-update --provider openai-compatible --provider-profile bashgw run "balas PONG" >"$ISO/run-bash.txt" 2>&1
if grep -q "PONG" "$ISO/run-bash.txt"; then
    pass "chat jalan lewat config engine Bash"
else
    fail "chat jalan lewat config engine Bash"
    sed -n '1,10p' "$ISO/run-bash.txt"
fi
if grep -q "auth=Bearer sk-bashengine-abcdef123456" "$MOCK_LOG"; then
    pass "key dari engine Bash terkirim bener"
else
    fail "key dari engine Bash terkirim bener"
    sed -n '1,5p' "$MOCK_LOG"
fi

echo "-- daemon: server start + server stop --force --"
# Yang dites di sini cuma bagian yang bisa diotomasi tanpa terminal:
# flag provider nempel di proses server, dan stop --force beneran matiin + clear socket.
# Perilaku "flag diabaikan kalau daemon udah jalan" cuma kepakai sama client
# interaktif (TUI/connect), jadi nggak bisa dites headless di sini.
DAEMON_SOCK="$ISO/sock/jcode.sock"
mkdir -p "$ISO/sock"
# Config section sebelumnya udah diganti ke versi envfile, balikin ke inline dulu.
cp "$ISO/config-inline.toml" "$ISO/home/.jcode/config.toml"
bwrap --dev-bind / / --bind "$ISO/home" "$HOME" "${UNSET_ARGS[@]}" "${SANDBOX_ENV[@]}" \
    "$ISO/bin/jcode" --socket "$DAEMON_SOCK" server start -p openai-compatible \
    --provider-profile mockgw >"$ISO/server-start.txt" 2>&1
if [ -S "$DAEMON_SOCK" ]; then
    pass "daemon sandbox jalan di socket terpisah"
else
    fail "daemon sandbox jalan di socket terpisah"
    sed -n '1,10p' "$ISO/server-start.txt"
fi

DAEMON_PID="$("$PY" -c "
import json
try:
    reg = json.load(open('$ISO/home/.jcode/servers.json'))
except Exception:
    reg = {}
for entry in reg.values():
    if entry.get('socket') == '$DAEMON_SOCK':
        print(entry.get('pid', ''))
        break
" 2>/dev/null)"
if [ -n "$DAEMON_PID" ] && tr '\0' ' ' <"/proc/$DAEMON_PID/cmdline" 2>/dev/null | grep -q 'provider-profile mockgw'; then
    pass "flag provider-profile nempel di proses server (pid $DAEMON_PID)"
else
    fail "flag provider-profile nempel di proses server (pid=${DAEMON_PID:-none})"
fi

bwrap --dev-bind / / --bind "$ISO/home" "$HOME" "${UNSET_ARGS[@]}" "${SANDBOX_ENV[@]}" \
    "$ISO/bin/jcode" --socket "$DAEMON_SOCK" server stop --force >"$ISO/server-stop.txt" 2>&1
if [ ! -S "$DAEMON_SOCK" ]; then
    pass "server stop --force ngehapus socket"
else
    fail "server stop --force ngehapus socket"
fi
if [ -n "$DAEMON_PID" ] && ! ps -p "$DAEMON_PID" >/dev/null 2>&1; then
    pass "server stop --force matiin proses daemon"
else
    fail "server stop --force matiin proses daemon (pid=${DAEMON_PID:-none} masih hidup)"
fi

bwrap --dev-bind / / --bind "$ISO/home" "$HOME" "${UNSET_ARGS[@]}" "${SANDBOX_ENV[@]}" \
    "$ISO/bin/jcode" --socket "$DAEMON_SOCK" server stop --force >"$ISO/server-stop2.txt" 2>&1
if [ "$?" -eq 0 ]; then
    pass "stop pas daemon nggak jalan tetap sukses (aman buat launch)"
else
    fail "stop pas daemon nggak jalan tetap sukses (aman buat launch)"
fi

# Balikin config ke provider inline buat section berikutnya (kalau ada).
cp "$ISO/config-inline.toml" "$ISO/home/.jcode/config.toml"

echo
echo "== hasil: $PASS ok, $FAIL fail =="
[ "$FAIL" -eq 0 ]
