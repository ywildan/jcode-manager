/**
 * Every string the landing page renders, in one place, so the copy stays
 * honest and consistent with the project README.
 */

export const brand = {
  name: "JCODE MANAGER",
  short: "JCM",
  label: "Provider control deck",
  version: "jcode v0.98.1",
  tagline: "Every provider. One menu.",
  summary:
    "An interactive manager for jcode CLI providers. Add, list, edit, delete, quick-start, generate, launch and restore OpenAI-compatible profiles without hand-editing TOML. Universal: Linux, macOS and Windows, with Python 3.8+ or plain bash.",
};

export const heroMeta = [
  "Linux · macOS · Windows",
  "Python 3.8+ or bash",
  "Nothing to pip install",
  "MIT",
];

export const ticker = [
  "ADD PROVIDER",
  "LIST WITH MASKED KEYS",
  "EDIT IN PLACE",
  "DELETE SAFELY",
  "QUICK START TEMPLATES",
  "GENERATE COMMAND",
  "LAUNCH WITH THE DAEMON HANDLED",
  "INFO & DOCTOR",
  "RESTORE FROM BACKUP",
];

export const stats = [
  {
    value: "9",
    label: "Menu operations",
    detail: "Every provider task, from adding a profile to rolling one back.",
  },
  {
    value: "2",
    label: "Interchangeable engines",
    detail: "A Python engine, and a self-contained bash engine when Python is absent.",
  },
  {
    value: "157",
    label: "Automated checks",
    detail: "16 platform, 64 Python engine, 57 bash engine, 20 against the real binary.",
  },
  {
    value: "0",
    label: "Dependencies",
    detail: "No pip install, no package manager, no service to run.",
  },
];

/* ------------------------------------------------------------------ */
/* The config file                                                     */
/* ------------------------------------------------------------------ */

export const correctConfig = `[providers.mygw]
base_url = "https://api.example.com/v1"
api_key = "sk-xxx"
default_model = "gpt-4o"`;

export const brokenConfig = `[providers.mygw]
base_url = "https://api.example.com/v1"
api_key = "sk-xxx"
model = "gpt-4o"        # ignored, silently
models = ["gpt-4o"]     # TOML parse error`;

export const gotchas = [
  {
    index: "01",
    title: "The key is default_model, not model",
    body: "With `model`, jcode silently ignores it and falls back to the catalog default. Not an error, just the wrong model answering.",
  },
  {
    index: "02",
    title: "Never write models = [...]",
    body: "That shape expects a NamedProviderModelConfig struct and produces a TOML parse error. `default_model` is enough.",
  },
  {
    index: "03",
    title: "api_key is required",
    body: "Remove it and jcode fails with `inline api_key not found in environment`. For a local server without auth, write api_key = \"\" — empty, not omitted.",
  },
];

export const keyStoreModes = [
  {
    id: "inline",
    name: "inline",
    config: 'api_key = "sk-…"',
    location: "~/.jcode/config.toml",
    good: "Simplicity, one file",
  },
  {
    id: "envfile",
    name: "envfile",
    config: "api_key_env + env_file + type/auth",
    location: "<XDG_CONFIG_HOME>/jcode/provider-<name>.env, mode 600",
    good: "Exactly what jcode provider add writes; the key stays out of the config",
  },
];

/* ------------------------------------------------------------------ */
/* The menu                                                            */
/* ------------------------------------------------------------------ */

export const menu = [
  {
    id: "01",
    name: "Add New Provider",
    summary:
      "Name, base_url, api_key with masked input, default_model. Duplicate check plus an automatic backup first.",
    tag: "write",
  },
  {
    id: "02",
    name: "List All Providers",
    summary:
      "Name, base_url, model, masked API key and where that key actually lives.",
    tag: "read",
  },
  {
    id: "03",
    name: "Edit Provider",
    summary:
      "Empty input keeps the current value. The same screen can rename a profile.",
    tag: "write",
  },
  {
    id: "04",
    name: "Delete Provider",
    summary:
      "Confirmation plus a backup, and the matching [[providers.x.models]] block goes with it.",
    tag: "write",
  },
  {
    id: "05",
    name: "Quick Start",
    summary:
      "OpenAI, Claude, Groq and OpenRouter templates. You only supply the API key.",
    tag: "template",
  },
  {
    id: "06",
    name: "Generate Command",
    summary:
      "A copy-paste ready launch command, copied to the clipboard when one is available.",
    tag: "read",
  },
  {
    id: "07",
    name: "Launch Provider",
    summary:
      "Stops the daemon first, then starts jcode on that profile — the order that actually works.",
    tag: "run",
  },
  {
    id: "08",
    name: "Info & Doctor",
    summary:
      "OS, config path, env directory, binary location, provider and backup counts.",
    tag: "read",
  },
  {
    id: "09",
    name: "Restore from Backup",
    summary:
      "Roll the config back to any earlier backup, chosen from a numbered list.",
    tag: "write",
  },
];

/* ------------------------------------------------------------------ */
/* The launch flow                                                     */
/* ------------------------------------------------------------------ */

export const launchSteps = [
  {
    index: "01",
    command: "jcode server stop --force",
    detail:
      "Errors are ignored when no server is running. Without this, the provider flags are silently dropped.",
  },
  {
    index: "02",
    command: "sleep 0.5",
    detail:
      "The daemon needs a moment to release its socket before a new one takes over.",
  },
  {
    index: "03",
    command:
      "jcode --provider openai-compatible --provider-profile <name> [--model <model>]",
    detail:
      "Started fresh, so the profile and model flags apply as written.",
  },
  {
    index: "04",
    command: "return to the menu",
    detail:
      "Once you exit jcode, the manager is waiting where you left it.",
  },
];

export const daemonWarning =
  "server stop kills the daemon, including any running headless or swarm sessions. The manager always asks for confirmation first. If a daemon is already alive, jcode says “provider/model flags only apply when starting a new server” — that is exactly what menu 7 fixes.";

/* ------------------------------------------------------------------ */
/* Safety                                                              */
/* ------------------------------------------------------------------ */

export const safety = [
  {
    id: "01",
    title: "Keys are masked on screen",
    body: "First four and last four characters, e.g. sk-abc…xyz. Keys of eight characters or fewer are masked entirely.",
  },
  {
    id: "02",
    title: "Backed up before every write",
    body: "config.toml.backup.YYYYMMDDHHmmss. If one already exists for that second, a numeric suffix is added so nothing is lost.",
  },
  {
    id: "03",
    title: "Atomic writes only",
    body: "Written through a temp file plus an atomic rename, so a half-written config can never happen.",
  },
  {
    id: "04",
    title: "Validated as TOML first",
    body: "If the result does not parse, the change is cancelled and the old file is left untouched.",
  },
  {
    id: "05",
    title: "Everything else preserved",
    body: "Comments, key order and [[providers.x.models]] blocks survive byte for byte. Only the edited section is rewritten.",
  },
  {
    id: "06",
    title: "Config written mode 600",
    body: "It can hold an API key, so the file is not world-readable. The config directory is created when missing.",
  },
  {
    id: "07",
    title: "jcode confirms the profile",
    body: "After add or edit the manager runs jcode provider current --provider-profile <name> to prove jcode can read it.",
  },
  {
    id: "08",
    title: "Tests never touch your config",
    body: "Every test runs against a throwaway config in a temp directory.",
  },
];

/* ------------------------------------------------------------------ */
/* Install                                                             */
/* ------------------------------------------------------------------ */

export const installSteps = [
  {
    index: "01",
    title: "Clone and run",
    copy: "git clone <repo-url> jcode-manager\ncd jcode-manager\n./install.sh",
    body: "One command. It checks for jcode, Python and bash, marks the scripts executable, installs a symlink in ~/.local/bin and prints the config paths it will use.",
  },
  {
    index: "02",
    title: "Optional: a global command",
    copy: "./create-shortcut.sh --desktop\nsudo ./create-shortcut.sh --bin-dir /usr/local/bin",
    body: "Symlink into ~/.local/bin, add an application-menu entry on Linux, or install system-wide. --uninstall removes it again.",
  },
  {
    index: "03",
    title: "Open the menu",
    copy: "./jcode-manager.sh\n# or straight to the Python engine\npython3 jcode-manager.py",
    body: "The launcher picks an engine automatically. Press Enter after each operation to return to the menu.",
  },
];

export const installFlags = [
  { flag: "--no-link", body: "Run the checks only, install no symlink." },
  { flag: "--bin-dir <dir>", body: "Choose where the command is linked." },
  { flag: "--uninstall", body: "Remove the shortcut again." },
];

/* ------------------------------------------------------------------ */
/* Non-interactive CLI                                                 */
/* ------------------------------------------------------------------ */

export const cliCommands = [
  {
    group: "Inspect",
    items: [
      {
        command: "python3 jcode-manager.py --list",
        body: "Print every provider, keys masked.",
      },
      {
        command: "python3 jcode-manager.py --list --json",
        body: "Machine-readable output for scripting.",
      },
      {
        command: "python3 jcode-manager.py --info",
        body: "OS, paths, binary location, counts.",
      },
    ],
  },
  {
    group: "Write",
    items: [
      {
        command:
          'python3 jcode-manager.py --add mygw \\\n    --base-url https://api.example.com/v1 \\\n    --api-key sk-xxx --model gpt-4o',
        body: "Add a provider in one line. Backed up and validated first.",
      },
      {
        command:
          'python3 jcode-manager.py --add local --base-url http://localhost:1234/v1 --api-key ""',
        body: "A local server with no auth. Empty string, not omitted.",
      },
      {
        command:
          "python3 jcode-manager.py --edit mygw --new-name gateway",
        body: "Edit a field, or rename the profile.",
      },
      {
        command: "python3 jcode-manager.py --quick groq --api-key gsk_xxx",
        body: "Apply a provider template.",
      },
      {
        command: "python3 jcode-manager.py --delete mygw --yes",
        body: "Delete with confirmation skipped.",
      },
    ],
  },
  {
    group: "Run",
    items: [
      {
        command: "python3 jcode-manager.py --generate mygw",
        body: "Print the launch command and the daemon reminder.",
      },
      {
        command: "python3 jcode-manager.py --launch mygw --yes",
        body: "Stop the daemon, then start jcode on that profile.",
      },
      {
        command: "python3 jcode-manager.py --restore ~/.jcode/config.toml.backup.20261017200113",
        body: "Roll back to a specific backup.",
      },
    ],
  },
  {
    group: "Keys",
    items: [
      {
        command:
          'printf \'%s\' "$MY_KEY" | python3 jcode-manager.py --add mygw \\\n    --base-url https://api.example.com/v1 --api-key-stdin --model gpt-4o',
        body: "Read the key from stdin, keeping it out of your shell history.",
      },
      {
        command: "python3 jcode-manager.py --add mygw --key-store envfile",
        body: "Write the key to a separate .env file with mode 600 instead.",
      },
    ],
  },
];

export const envVars = [
  {
    name: "JCODE_MANAGER_CONFIG",
    purpose: "Override the config.toml path.",
  },
  {
    name: "JCODE_MANAGER_ENGINE",
    purpose: "auto (default) / python / bash.",
  },
  {
    name: "JCODE_MANAGER_PYTHON",
    purpose: "Force a specific interpreter in the launcher.",
  },
  {
    name: "NO_COLOR / JCODE_MANAGER_NO_COLOR",
    purpose: "Disable ANSI colours.",
  },
];

/* ------------------------------------------------------------------ */
/* Engines and platforms                                               */
/* ------------------------------------------------------------------ */

export const engines = [
  {
    name: "Python engine",
    when: "Python 3.8+ is available",
    body: "The complete implementation and the default whenever an interpreter exists.",
    list: [
      "Menu 1–9, full set",
      "Can create providers with --key-store envfile",
      "--list --json prints every field",
    ],
    tone: "primary" as const,
  },
  {
    name: "Bash engine",
    when: "No Python on the machine, or JCODE_MANAGER_ENGINE=bash",
    body: "Self-contained. Menu 1–9 still work, with the same config format and the same safety rails.",
    list: [
      "Needs only bash, awk, sed, grep, cut, date",
      "Reads and masks keys from existing env files",
      "--list --json prints a subset of fields",
    ],
    tone: "secondary" as const,
  },
];

export const pathTable = [
  {
    os: "Linux",
    config: "~/.jcode/config.toml",
    env: "$XDG_CONFIG_HOME/jcode/ (default ~/.config/jcode/)",
  },
  {
    os: "macOS",
    config: "~/.jcode/config.toml",
    env: "$XDG_CONFIG_HOME/jcode/ (default ~/.config/jcode/)",
  },
  {
    os: "Windows",
    config: "%USERPROFILE%\\.jcode\\config.toml",
    env: "%APPDATA%\\jcode\\",
  },
];

export const binaryLookup = [
  { os: "Linux", path: "jcode on PATH, then ~/.local/bin/jcode" },
  { os: "macOS", path: "/usr/local/bin/jcode, /opt/homebrew/bin/jcode" },
  { os: "Windows", path: "%LOCALAPPDATA%\\jcode\\bin\\jcode.exe" },
];

export const verification = [
  { area: "Config path & env dir detection", linux: "tested live", mac: "simulated", win: "simulated" },
  { area: "Provider CRUD + TOML (Python engine)", linux: "tested live", mac: "same code path", win: "same code path" },
  { area: "Provider CRUD + TOML (bash engine)", linux: "tested live", mac: "not yet", win: "not yet" },
  { area: "Real jcode reads the config, both engines", linux: "tested live", mac: "not yet", win: "not yet" },
  { area: "Menu, colours, clipboard", linux: "tested live", mac: "not yet", win: "not yet (clip)" },
  { area: ".sh launcher", linux: "tested live", mac: "not yet", win: "not yet (Git Bash/MSYS)" },
  { area: ".ps1 launcher", linux: "n/a", mac: "n/a", win: "not tested" },
];

export const testSuites = [
  { name: "test-platform-paths.py", engine: "Python", count: "16 tests", body: "Per-platform OS and path detection, Windows and macOS branches simulated." },
  { name: "smoke-test.sh", engine: "Python engine", count: "64 tests", body: "CRUD, masking, config integrity, envfile mode, stop-before-start ordering via a stub jcode." },
  { name: "smoke-test-fallback.sh", engine: "bash engine", count: "57 tests", body: "The same coverage plus engine delegation and the automatic fallback." },
  { name: "verify-with-jcode.sh", engine: "real binary", count: "20 tests", body: "Real jcode in a bubblewrap sandbox: chat works, the key is sent, the daemon really stops." },
];

/* ------------------------------------------------------------------ */
/* Provider studio                                                     */
/* ------------------------------------------------------------------ */

export type ProviderTemplate = {
  id: string;
  name: string;
  provider: string;
  baseUrl: string;
  model: string;
  note: string;
};

export const providerTemplates: ProviderTemplate[] = [
  {
    id: "openai",
    name: "OpenAI",
    provider: "openai",
    baseUrl: "https://api.openai.com/v1",
    model: "gpt-4o",
    note: "The quick-start template menu 5 ships for OpenAI.",
  },
  {
    id: "claude",
    name: "Claude",
    provider: "claude",
    baseUrl: "https://api.anthropic.com/v1",
    model: "claude-3-5-sonnet-latest",
    note: "The Claude entry in the quick-start templates.",
  },
  {
    id: "groq",
    name: "Groq",
    provider: "groq",
    baseUrl: "https://api.groq.com/openai/v1",
    model: "llama-3.3-70b-versatile",
    note: "Fast hosted inference over the OpenAI-compatible API.",
  },
  {
    id: "openrouter",
    name: "OpenRouter",
    provider: "openrouter",
    baseUrl: "https://openrouter.ai/api/v1",
    model: "openai/gpt-4o",
    note: "One key, many upstream models.",
  },
  {
    id: "local",
    name: "Local server",
    provider: "local",
    baseUrl: "http://localhost:1234/v1",
    model: "local-model",
    note: "LM Studio, Ollama or anything else listening on localhost. No auth key.",
  },
  {
    id: "custom",
    name: "Custom endpoint",
    provider: "mygw",
    baseUrl: "https://api.example.com/v1",
    model: "gpt-4o",
    note: "Any other OpenAI-compatible gateway, router or proxy.",
  },
];

/* ------------------------------------------------------------------ */
/* FAQ                                                                 */
/* ------------------------------------------------------------------ */

export const faq = [
  {
    q: "Is this part of jcode, or a separate project?",
    a: "A separate project. jcode ships jcode provider add / list / current for one-off changes, and this manager is built for people who do that often: a menu, masked listings, edit and delete, quick-start templates, command generation, backups with restore, and a launch flow that handles the daemon correctly.",
  },
  {
    q: "Do I need to install anything?",
    a: "No package manager is involved. There is nothing to pip install. You need jcode itself, plus either Python 3.8+ or bash. Without Python the bash engine takes over automatically; on macOS that engine wants bash 4.2+, which means brew install bash.",
  },
  {
    q: "Will it overwrite my existing config?",
    a: "No. install.sh never touches an existing jcode config — it only reports paths. Config files are written only when you pick menu 1, 5 or 9 yourself, and every one of those writes is backed up first and validated as TOML before it lands.",
  },
  {
    q: "“Server already running; provider/model flags only apply when starting a new server.”",
    a: "The daemon is still alive, so your --provider-profile was ignored. Use menu 7 or --launch, which runs jcode server stop --force first, or stop the daemon yourself before launching.",
  },
  {
    q: "“Unknown provider profile 'x'”",
    a: "The [providers.x] section does not exist in the config. Check menu 2 to list what is there, and remember the flag is --provider-profile, not just --provider.",
  },
  {
    q: "“inline api_key not found in environment”",
    a: "That provider section has no api_key field. For a server without auth, set api_key = \"\" — an empty string. The field has to be present.",
  },
  {
    q: "My config is broken after editing it by hand. Now what?",
    a: "Open menu 9 and restore an earlier backup, or look for ~/.jcode/config.toml.backup.* yourself. The most common cause is a models = [...] line, which jcode cannot parse.",
  },
  {
    q: "What language are the prompts in?",
    a: "Documentation ships in English and Indonesian. The interactive prompts inside the scripts are Indonesian and English mixed, matching the original author's style. There is no runtime language switch yet.",
  },
  {
    q: "What about “upstream connection lost” on long jobs?",
    a: "That one is not the manager and not your config. The model stream was cut upstream by a gateway or router when a generation ran too long. Check ~/.jcode/logs/jcode-*.log for phase=stream_event_error: the fix is a more stable provider or smaller steps.",
  },
  {
    q: "I already have the folder — do I have to clone it?",
    a: "No. Everything is plain files with no hardcoded paths: the script folder is resolved from the script's own location, through symlinks, so it can live anywhere. tar the folder, hand it over, extract it and run ./install.sh.",
  },
];
