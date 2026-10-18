# J-Code Provider Manager

**English** | [Bahasa Indonesia](README.id.md#top)

An interactive manager for jcode CLI providers. Universal: runs on **Linux**,
**macOS**, and **Windows** (PowerShell/CMD) with either Python 3.8+ or plain bash.

![engine: python + bash](https://img.shields.io/badge/engine-Python%20%2B%20Bash-blue)
[![CI](https://github.com/ywildan/jcode-manager/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ywildan/jcode-manager/actions/workflows/ci.yml)

## What it does

jcode talks to any OpenAI-compatible endpoint once you define a provider profile in
`~/.jcode/config.toml`. This tool gives you a menu for that instead of hand-editing
TOML: add, list (with API keys masked), edit, delete, one-click templates for popular
providers, copy-paste commands, and a launch flow that handles jcode's background
daemon correctly. Every write is backed up first.

```
jcode-manager/
├── jcode-manager.py        # Python engine (most complete, primary)
├── jcode-manager.sh        # launcher + Bash engine (fallback without Python)
├── jcode-manager.ps1       # Windows launcher (locates Python)
├── install.sh              # one-command setup for new users
├── create-shortcut.sh      # symlink / desktop entry helper
├── README.md               # this file (English)
├── README.id.md            # Indonesian version
├── .github/workflows/ci.yml # CI: 3-OS matrix + acceptance with the real jcode
└── tests/
    ├── test-platform-paths.py  # OS & path detection (Windows/macOS simulated, 18 tests)
    ├── smoke-test.sh           # 64 tests, Python engine
    ├── smoke-test-fallback.sh  # 57 tests, Bash engine
    ├── verify-with-jcode.sh    # acceptance tests with the real jcode binary
    └── mock-openai-server.py   # fake OpenAI-compatible server for the above
```

## Install

```bash
git clone https://github.com/<you>/jcode-manager
cd jcode-manager
./install.sh
```

`install.sh` checks for `jcode`, Python, and bash, marks the scripts executable,
installs a `jcode-manager` symlink in `~/.local/bin`, and prints the config paths it
will use. It does not modify your jcode config. Use `--no-link` to only run the checks,
or `--bin-dir /usr/local/bin` with `sudo` for a system-wide command.

No package manager required: there is nothing to `pip install`, and the Bash engine
needs only `bash`, `awk`, `sed`, `grep`, `cut`, and `date`.

## Two engines

`jcode-manager.sh` is the main entry point and picks an engine automatically:

| Condition | What runs |
| --------- | --------- |
| Python 3.8+ available | **Python engine** (`jcode-manager.py`), most complete |
| No Python | **Bash engine**, self-contained, core features still work |
| `JCODE_MANAGER_ENGINE=bash` | force the Bash engine |
| `JCODE_MANAGER_ENGINE=python` | force the Python engine, errors if missing |

The Bash engine covers menu 1-10: add/list/edit/delete/quick start/generate/launch/
restore/models, backups, key masking, and the same config format. The differences: the
Bash engine cannot create new providers with `--key-store envfile` (it can still read
and mask keys from existing env files), its `--list --json` prints a subset of fields,
and its model management rejects model ids containing a double quote (the Python engine
handles those).

Unless stated otherwise, this document describes the Python engine.

## Features

| Menu | Function |
| ---- | -------- |
| 1 | **Add New Provider** - name, base_url, api_key (masked input), default_model. Duplicate check + automatic backup |
| 2 | **List All Providers** - name, base_url, model, masked API key, where the key lives |
| 3 | **Edit Provider** - empty input keeps the current value; can also rename |
| 4 | **Delete Provider** - confirmation + backup; drops `[[providers.x.models]]` too |
| 5 | **Quick Start** - OpenAI / Claude / Groq / OpenRouter templates, you only supply the API key |
| 6 | **Generate Command** - copy-paste ready command (auto-copies to clipboard when available) |
| 7 | **Launch Provider** - runs `server stop --force` first, then starts jcode on that profile |
| 8 | **Info & Doctor** - OS, config path, env dir, binary location, provider/backup counts |
| 9 | **Restore from Backup** - roll the config back to an earlier backup |
| 10 | **Manage Models** - add/remove extra models for one provider (multi-model picker in jcode) |

## Usage

```bash
# 1. Open the menu (directly, or through the symlink)
./jcode-manager.sh              # Linux/macOS/WSL, picks the engine automatically
python3 jcode-manager.py        # straight to the Python engine
jcode-manager                   # if the symlink is installed

# 2. Pick a menu entry and follow the prompts
# 3. Press Enter after each operation to return to the menu
```

Add a shortcut so it works from anywhere:

```bash
./create-shortcut.sh                 # symlink into ~/.local/bin/jcode-manager
./create-shortcut.sh --entry python  # point straight at jcode-manager.py
./create-shortcut.sh --desktop       # also add an application-menu entry (Linux)
./create-shortcut.sh --uninstall     # remove it

sudo ./create-shortcut.sh --bin-dir /usr/local/bin   # system-wide
```

Windows:

```powershell
.\jcode-manager.ps1
.\jcode-manager.ps1 --list
# If the execution policy blocks it:
powershell -ExecutionPolicy Bypass -File .\jcode-manager.ps1
```

## Sharing it with someone else

Everything here is plain files: no dependencies, no hardcoded paths (the script folder
is resolved from the script's own location, through symlinks), so it can live anywhere.

**Simplest: hand over the folder**

```bash
# on your machine
tar -czf jcode-manager.tar.gz jcode-manager/
# send that file; on the other machine:
tar -xzf jcode-manager.tar.gz
cd jcode-manager
./install.sh
```

**Through git**

```bash
git clone <repo-url> && cd jcode-manager && ./install.sh
```

**What `install.sh` does**

1. `chmod +x` on the scripts
2. checks whether `jcode`, Python, and bash are present (and tells you how to install
   whatever is missing)
3. installs the `jcode-manager` symlink (skip with `--no-link`)
4. runs `--info` so you immediately see which config path will be used

`install.sh` **never touches** an existing jcode config. It only reports paths. Config
files are written only when the user picks menu 1/5/9 themselves.

**Requirements on their machine**

| Needed | Notes |
| ------ | ----- |
| jcode | required; the manager only manages providers. Without it the manager still runs but cannot launch jcode |
| Python 3.8+ **or** bash | either one. Without Python the Bash engine is used automatically |
| bash 3.2+ for the Bash engine | CI runs the whole Bash-engine suite on macOS' stock bash 3.2.57, so nothing here needs bash 4 |

**For anyone who wants to check before trusting**

```bash
bash tests/smoke-test.sh             # 64 tests, Python engine (temporary config, safe)
bash tests/smoke-test-fallback.sh    # 57 tests, Bash engine
python3 tests/test-platform-paths.py # 18 tests, OS/path detection
bash tests/verify-with-jcode.sh      # 20 tests against the real jcode binary, sandboxed
```

All of that also runs on every push through
[`.github/workflows/ci.yml`](.github/workflows/ci.yml): the three local suites run as a
matrix on `ubuntu-latest`, `macos-latest`, and `windows-latest`, and a separate job
downloads the latest official jcode release and runs the acceptance test (with
`JCM_REQUIRE_SANDBOX=1`, so a missing sandbox fails the job instead of silently
skipping it).

Every test uses a throwaway config in a temp directory, so your real jcode config is
never touched. The only step that needs elevated rights is `--bin-dir /usr/local/bin`.

## Non-interactive mode

Every feature is available without the menu, which is handy for scripting:

```bash
python3 jcode-manager.py --list
python3 jcode-manager.py --list --json
python3 jcode-manager.py --info

python3 jcode-manager.py --add mygw --base-url https://api.example.com/v1 \
    --api-key sk-xxx --model gpt-4o

# local server without auth (lmstudio/ollama): empty api_key string
python3 jcode-manager.py --add local --base-url http://localhost:1234/v1 --api-key ""

python3 jcode-manager.py --edit mygw --model gpt-4o-mini
python3 jcode-manager.py --edit mygw --new-name gateway
python3 jcode-manager.py --delete mygw --yes

# more than one model on the same provider
python3 jcode-manager.py --models mygw
python3 jcode-manager.py --add-model mygw=gpt-4o --add-model mygw=o3-mini
python3 jcode-manager.py --remove-model mygw=o3-mini
python3 jcode-manager.py --set-models mygw=gpt-4o,gpt-4o-mini --model gpt-4o-mini

python3 jcode-manager.py --quick groq --api-key gsk_xxx
python3 jcode-manager.py --generate mygw
python3 jcode-manager.py --launch mygw --yes
python3 jcode-manager.py --restore ~/.jcode/config.toml.backup.20261017200113
```

API key from stdin, to keep it out of your shell history:

```bash
printf '%s' "$MY_KEY" | python3 jcode-manager.py --add mygw \
    --base-url https://api.example.com/v1 --api-key-stdin --model gpt-4o
```

## Config format

The manager writes the minimal shape jcode needs (verified directly against the
jcode v0.98.1 binary):

```toml
[providers.<name>]
base_url = "https://api.example.com/v1"
api_key = "sk-xxx"
default_model = "gpt-4o"
```

Three things worth knowing:

1. The key is **`default_model`**, not `model`. With `model`, jcode silently ignores it
   and falls back to the catalog default (not an error, but the wrong model).
2. **Never** write `models = [...]`. That shape expects a `NamedProviderModelConfig`
   struct and produces a TOML parse error. `default_model` is enough for one model;
   for several, use `[[providers.<name>.models]]` sub-tables (below).
3. The `api_key` field is **required**. Remove it and jcode fails with
   `Error: inline api_key not found in environment`. For a local server without auth,
   write `api_key = ""` (empty string, do not omit it).

Everything else in your file (comments, key order, `[[providers.x.models]]`) is
preserved byte for byte. Only the provider section being changed is rewritten.

### More than one model per provider

One profile can expose several models: add one `[[providers.<name>.models]]` sub-table
per model, and `default_model` decides which one is active when jcode starts with that
profile. In jcode you switch between them with Ctrl+Tab (or `/model`):

```toml
[providers.mygw]
base_url = "https://api.example.com/v1"
api_key = "sk-xxx"
default_model = "deepseek-v4-flash"

[[providers.mygw.models]]
id = "deepseek-v4-flash"

[[providers.mygw.models]]
id = "gpt-6-luna"
```

This is verified against the real binary: every `id` shows up in
`jcode model list` for that profile, and `jcode --model <id>` really sends that model.

Menu **10 (Manage Models)** does it interactively, or use the CLI flags
`--models`, `--add-model`, `--remove-model`, and `--set-models`. When the manager
rewrites the list it reuses the existing sub-table blocks verbatim, so comments and
extra fields inside them survive; only brand-new entries are written as a minimal
`id` block.

### API key storage modes

When adding or editing, the manager offers two modes (`--key-store` on the CLI):

| Mode | Config contains | Key location | Good for |
| ---- | --------------- | ------------ | -------- |
| `inline` (default) | `api_key = "..."` | `~/.jcode/config.toml` | Simplicity, one file |
| `envfile` | `api_key_env` + `env_file` + `type`/`auth` | `<XDG_CONFIG_HOME>/jcode/provider-<name>.env`, mode `600` | Exactly what `jcode provider add` writes; key kept out of the config |

The config is written with mode `600` because it can hold an API key.

## jcode daemon: why the stop comes first

jcode runs a persistent background daemon. The `--provider` / `--provider-profile`
flags **only apply when the server is starting fresh**. If a daemon is already running,
jcode says:

> Server already running; provider/model flags only apply when starting a new server.

So menu 7 and `--launch` do this:

1. `jcode server stop --force` (errors ignored when no server is running)
2. wait 0.5 seconds
3. `jcode --provider openai-compatible --provider-profile <name> [--model <model>]`
4. return to the menu once you exit jcode

If you prefer doing it by hand, menu 6 prints the command and reminds you about the
daemon.

> Heads up: `server stop` kills the daemon, including any running headless/swarm
> sessions. The manager always asks for confirmation first.

## Safety

- API keys are masked on screen: `sk-abc...xyz` (first 4 + last 4 characters).
  Short keys (<= 8 characters) are masked entirely.
- Automatic backup before **every** write: `config.toml.backup.YYYYMMDDHHmmss`.
  If one already exists for that second, a numeric suffix is added so nothing is lost.
- Configs are written through a temp file plus an atomic rename, so a half-written file
  can never happen.
- The resulting config is validated as TOML before being written. If it is invalid the
  change is cancelled and the old file is left alone.
- After add/edit the manager runs `jcode provider current --provider-profile <name>` to
  confirm jcode can actually read the profile (skipped automatically with `--config`,
  since jcode always reads its default path).
- The config directory is created automatically when missing.

## Testing

Three layers, from cheapest to strictest:

```bash
python3 tests/test-platform-paths.py   # 18 tests: per-platform OS & path detection
bash tests/smoke-test.sh               # 88 tests, Python engine
bash tests/smoke-test-fallback.sh      # 78 tests, Bash engine
bash tests/verify-with-jcode.sh        # 23 tests against the real jcode binary (sandbox)
```

- **test-platform-paths.py** - simulates the Windows branch (`os.name == 'nt'`, with
  `USERPROFILE`/`APPDATA`/`LOCALAPPDATA`) and the macOS branch
  (`sys.platform == 'darwin'`), plus Linux/WSL and the provider env var names.
- **smoke-test.sh** - Python engine: add/list/edit/delete/quick/generate/restore/menu,
  multi-model management (menu 10 and the CLI flags), key masking, config integrity
  (comments and other providers untouched), the envfile mode, the `stop daemon`
  ordering in the launch flow (via a stub `jcode`, so the real daemon is never touched),
  Python 3.8 syntax compatibility, and engine selection.
- **smoke-test-fallback.sh** - the same for the Bash engine, plus delegation to Python
  (including through a symlink) and the automatic fallback when Python is missing.
- **verify-with-jcode.sh** - runs the real jcode binary inside a bubblewrap sandbox with
  a separate HOME and a separate daemon socket, proving:
  - `jcode provider current` accepts configs written by both engines
  - the profile's `default_model` is really used
  - every extra model added by the manager shows up in `jcode model list` for that
    profile, and selecting one sends it to the endpoint
  - a chat works (the mock server returns `PONG`)
  - the API key is actually sent as `Authorization: Bearer ...`
  - the `envfile` mode works end to end
  - `server start --provider-profile` attaches the flags to the daemon process
  - `server stop --force` kills the daemon and clears the socket

### Verification status (honest, per platform)

Everything marked "CI" runs for real on every push in `.github/workflows/ci.yml`, on a
genuine ubuntu / macOS (arm64) / Windows runner - not a simulation.

Two notes so the table is not read as more than it is: on the path rows, "tested live"
means the OS-specific branch of the path logic runs on that runner, with
`HOME`/`USERPROFILE`/`APPDATA`/`XDG_CONFIG_HOME` redirected into temp dirs and the suites
passing `--config` / `JCODE_MANAGER_APP_CONFIG`, so no real config is ever touched. The
counts come from the job logs, `skip` lines included (see the bullets below).

| Area | Linux | macOS | Windows |
| ---- | ----- | ----- | ------- |
| Config path & env dir detection | tested live | tested live (CI) | tested live (CI) |
| Provider CRUD + TOML, Python engine (64 tests) | tested live | tested live (CI) | tested live, 1 skip (CI) |
| Provider CRUD + TOML, Bash engine (57 tests) | tested live | tested live (CI) | tested live, 1 skip (CI) |
| Engine selection + `.sh` launcher | tested live | tested live (CI) | tested live (CI) |
| Launch flow, stub jcode | tested live | tested live (CI) | tested live (CI, `.cmd` stub) |
| env-file mode written as `0600` | tested live | tested live (CI) | n/a, no POSIX modes |
| Real jcode binary reads the config | tested live (CI, downloaded release) | not yet | not yet |
| `.ps1` launcher | n/a | n/a | not tested (it only locates Python) |
| Clipboard integration | not covered | not covered | not covered |

What the matrix is telling you:

- **Windows skips two assertions on purpose**: `ln -s` copies instead of linking in MSYS by
  default (so the launcher's symlink resolution is not exercised there), and Windows has no
  POSIX permission bits (so the `0600` check is meaningless). Both print `skip` in the CI log,
  so passing counts never get inflated.
- **The Windows launch test uses a `.cmd` stub** instead of the bash stub, because
  `CreateProcess` cannot start an extensionless shell script. That test already paid for
  itself: it caught a real bug where launching a jcode installed as `.cmd`/`.bat` failed,
  because the engine passed the bare name `jcode` (and `CreateProcess` only appends `.exe`).
- **The real-jcode acceptance test is Linux-only** because it needs bubblewrap to hold a
  separate `HOME` and daemon socket. On macOS/Windows the config format is asserted by the
  simulation tests, not by jcode itself.
- **Clipboard and the `.ps1` launcher need a desktop session**, so no CI job can cover them.
  The `.ps1` launcher only locates Python (there is no PowerShell engine), so Windows still
  needs Python 3.8+.

One thing that **cannot** be automated here: the "flags are ignored while the daemon is
running" behaviour, because it only affects interactive clients (the TUI / `jcode
connect`) and needs a terminal. Everything headless-verifiable (flags attached to the
server process, stop-before-start ordering, `stop --force` being safe when idle) is
covered.

Last results on this machine (jcode v0.98.1, Linux): **16 ok / 0 fail** (platform),
**64 ok / 0 fail** (Python engine), **57 ok / 0 fail** (Bash engine),
**20 ok / 0 fail** (acceptance with the real jcode binary). 157 checks total.

## Troubleshooting

**"Server already running; provider/model flags only apply when starting a new server"**
The daemon is still alive. Use menu 7 / `--launch`, or manually:
`jcode server stop --force`.

**Config unreadable / TOML parse error**
Inspect `~/.jcode/config.toml` via menu 2, or `python3 jcode-manager.py --info`.
If you edited it by hand, you probably hit `models = [...]`. Roll back with menu 9.

**Provider rejected: `Unknown provider profile 'x'`**
The `[providers.x]` section does not exist. Check menu 2. Remember the flag is
`--provider-profile`, not just `--provider`.

**Provider rejected: `inline api_key not found in environment`**
That section has no `api_key` field. For a server without auth, set `api_key = ""`.

**Restoring a config from backup**
Menu 9, or look for `~/.jcode/config.toml.backup.*` and restore manually.

**`upstream connection lost` on long jobs**
Not a manager or config problem. The model stream is being cut upstream (gateway/router)
when a generation runs too long. Check `~/.jcode/logs/jcode-*.log`: if you see
`phase=stream_event_error error="upstream connection lost"`, the turn simply ran too
long (your config is fine). Fix: switch to a more stable provider/model through this
manager, or split the work into smaller steps.

## Paths per OS

| OS | Config | Provider env files |
| -- | ------ | ------------------ |
| Linux | `~/.jcode/config.toml` | `$XDG_CONFIG_HOME/jcode/` (default `~/.config/jcode/`) |
| macOS | `~/.jcode/config.toml` | `$XDG_CONFIG_HOME/jcode/` (default `~/.config/jcode/`) |
| Windows | `%USERPROFILE%\.jcode\config.toml` | `%APPDATA%\jcode\` |

The jcode binary is looked up as: `jcode` on PATH, then `~/.local/bin/jcode` (Linux),
`/usr/local/bin/jcode` and `/opt/homebrew/bin/jcode` (macOS),
`%LOCALAPPDATA%\jcode\bin\jcode.exe` (Windows).

Override the config path (useful for testing): `--config /path/to/config.toml` or the
`JCODE_MANAGER_CONFIG` env var.

## Environment variables

| Var | Purpose |
| --- | ------- |
| `JCODE_MANAGER_CONFIG` | Override the config.toml path |
| `JCODE_MANAGER_APP_CONFIG` | Override the app config dir (where provider `env_file`s live). Mostly for tests: on Windows the default is `%APPDATA%\jcode`, which is why the suites pin this to a temp dir |
| `JCODE_MANAGER_ENGINE` | `auto` (default) / `python` / `bash` |
| `JCODE_MANAGER_PYTHON` | Force a specific Python interpreter in the launcher |
| `JCM_REQUIRE_SANDBOX` | `1` makes `verify-with-jcode.sh` fail instead of skipping when bubblewrap or jcode is missing (used by CI) |
| `NO_COLOR` / `JCODE_MANAGER_NO_COLOR` | Disable ANSI colors |

## Language note

Documentation ships in two languages: this file (English) and
[README.id.md](README.id.md#top) (Indonesian). The language switcher at the top is
deliberate, because GitHub can only render one README on the repository front page: the
Indonesian link opens that file at its first line (`#top`), and the link back to English
points at the repository root, which is the page that renders this file. The interactive
prompts and messages inside the scripts are Indonesian/English mixed, matching the original
author's style; there is no runtime language switch yet. Open an issue if you need one.

## Official jcode alternative

jcode itself ships:

```bash
jcode provider add mygw --base-url https://api.example.com/v1 --model gpt-4o
jcode provider current -p openai-compatible --provider-profile mygw
jcode provider list
```

This manager adds: an interactive menu, listing with key masking, edit/delete, quick
start templates, command generation, backup + restore, and a launch flow that handles
the daemon. If all you need is to add one provider once, `jcode provider add` is enough.

Two small differences worth knowing: `jcode provider add` writes the long form
(`type`, `auth`, `api_key_env`, `env_file`, `requires_api_key`, plus
`[[providers.x.models]]`), does not create a config backup, and leaves behind a
`[[providers.x.models]]` table that can be confusing. This manager writes the minimal
three fields by default, always backs up first, and offers `--key-store envfile` if you
want the long form.
