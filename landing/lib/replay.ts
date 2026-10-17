/**
 * An illustrative replay of the menu flow.
 *
 * The operations, their order and their side effects follow the README exactly
 * (backup names, TOML validation, the `provider current` check, the
 * stop-before-start launch). The exact wording of the prompts is the tool's own
 * and differs in your terminal, which is what `replayNotice` says on the page.
 */

export type ReplayLine = {
  text: string;
  tone: "cmd" | "out" | "ok" | "warn";
  /** Typed out character by character when it is a command. */
  typed?: boolean;
};

export type Replay = {
  id: string;
  menu: string;
  title: string;
  caption: string;
  lines: ReplayLine[];
};

export const replayNotice =
  "An illustrative replay. Your terminal will differ in wording and colour; the operations, their order and their side effects are what the manager guarantees.";

const opening = (choice: number): ReplayLine[] => [
  { text: "python3 jcode-manager.py", tone: "cmd", typed: true },
  { text: "J-Code Provider Manager · config: ~/.jcode/config.toml", tone: "out" },
  { text: "", tone: "out" },
  { text: "  1 Add New Provider        6 Generate Command", tone: "out" },
  { text: "  2 List All Providers      7 Launch Provider", tone: "out" },
  { text: "  3 Edit Provider           8 Info & Doctor", tone: "out" },
  { text: "  4 Delete Provider         9 Restore from Backup", tone: "out" },
  { text: "  5 Quick Start", tone: "out" },
  { text: "", tone: "out" },
  { text: `Choose [1-9]: ${choice}`, tone: "cmd" },
];

export const replays: Replay[] = [
  {
    id: "add",
    menu: "1",
    title: "Add a provider",
    caption: "A duplicate check, a backup, a TOML validation and a jcode check.",
    lines: [
      ...opening(1),
      { text: "Provider name: mygw", tone: "cmd" },
      { text: "Base URL [https://]: https://api.example.com/v1", tone: "cmd" },
      { text: "API key: sk-abc...xyz", tone: "cmd" },
      { text: "Default model: gpt-4o", tone: "cmd" },
      { text: "Key storage — 1) inline  2) envfile: 1", tone: "cmd" },
      { text: "", tone: "out" },
      { text: "backup  ~/.jcode/config.toml.backup.20261017200113", tone: "out" },
      { text: "write   temp file + atomic rename, mode 600", tone: "out" },
      { text: "check   config parses as TOML", tone: "ok" },
      { text: "check   jcode provider current --provider-profile mygw", tone: "ok" },
      { text: "[providers.mygw] is ready. Press Enter for the menu.", tone: "ok" },
    ],
  },
  {
    id: "list",
    menu: "2",
    title: "List with masked keys",
    caption: "Where each key lives, without printing it.",
    lines: [
      ...opening(2),
      { text: "", tone: "out" },
      { text: "NAME    BASE_URL                        MODEL        KEY            STORED IN", tone: "out" },
      { text: "mygw    https://api.example.com/v1      gpt-4o       sk-abc...xyz   config.toml", tone: "out" },
      { text: "groq    https://api.groq.com/openai/v1  llama-3.3-70 gsk_xxx...xx   provider-groq.env", tone: "out" },
      { text: "local   http://localhost:1234/v1        local-model  (none)         —", tone: "out" },
      { text: "", tone: "out" },
      { text: "3 providers. Keys are masked: first 4 + last 4 characters.", tone: "ok" },
    ],
  },
  {
    id: "quick",
    menu: "5",
    title: "Quick start template",
    caption: "Four providers, one key to supply.",
    lines: [
      ...opening(5),
      { text: "1) OpenAI  2) Claude  3) Groq  4) OpenRouter", tone: "out" },
      { text: "Choose [1-4]: 3", tone: "cmd" },
      { text: "Paste your Groq API key: gsk_xxx...xx", tone: "cmd" },
      { text: "Provider name [groq]:", tone: "cmd" },
      { text: "Base URL [https://api.groq.com/openai/v1]:", tone: "cmd" },
      { text: "Default model [llama-3.3-70b-versatile]:", tone: "cmd" },
      { text: "", tone: "out" },
      { text: "backup  ~/.jcode/config.toml.backup.20261017200341", tone: "out" },
      { text: "[providers.groq] added and validated.", tone: "ok" },
    ],
  },
  {
    id: "generate",
    menu: "6",
    title: "Generate the command",
    caption: "Copy-paste ready, with the daemon reminder attached.",
    lines: [
      ...opening(6),
      { text: "Profile: mygw", tone: "cmd" },
      { text: "", tone: "out" },
      {
        text: "jcode --provider openai-compatible --provider-profile mygw --model gpt-4o",
        tone: "ok",
      },
      { text: "", tone: "out" },
      {
        text: "reminder  these flags only apply when the server starts fresh.",
        tone: "warn",
      },
      { text: "          run `jcode server stop --force` first, or use menu 7.", tone: "out" },
      { text: "command copied to the clipboard", tone: "ok" },
    ],
  },
  {
    id: "launch",
    menu: "7",
    title: "Launch, daemon handled",
    caption: "Stop, wait, start — the order that actually works.",
    lines: [
      ...opening(7),
      { text: "Profile: openai-compatible / mygw · model gpt-4o", tone: "cmd" },
      { text: "", tone: "out" },
      {
        text: "This stops the running jcode daemon, including headless sessions.",
        tone: "warn",
      },
      { text: "Continue? [y/N] y", tone: "cmd" },
      { text: "jcode server stop --force", tone: "cmd", typed: true },
      { text: "waiting 0.5s for the socket to be released", tone: "out" },
      {
        text: "jcode --provider openai-compatible --provider-profile mygw --model gpt-4o",
        tone: "cmd",
        typed: true,
      },
      { text: "daemon started with the profile attached", tone: "ok" },
    ],
  },
  {
    id: "restore",
    menu: "9",
    title: "Restore from backup",
    caption: "Because you edited the TOML by hand, once.",
    lines: [
      ...opening(9),
      { text: "", tone: "out" },
      { text: "  1  config.toml.backup.20261017200113   17 Oct 20:01", tone: "out" },
      { text: "  2  config.toml.backup.20261017193004   17 Oct 19:30", tone: "out" },
      { text: "  3  config.toml.backup.20261017171245   17 Oct 17:12", tone: "out" },
      { text: "", tone: "out" },
      { text: "Restore which? [1-3] 2", tone: "cmd" },
      { text: "restored  ~/.jcode/config.toml", tone: "ok" },
      { text: "check     config parses as TOML", tone: "ok" },
    ],
  },
];
