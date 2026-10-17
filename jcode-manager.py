#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
J-Code Provider Manager
=======================

Script interaktif buat ngatur provider jcode CLI (`--provider-profile`).

Menu:
  1) Add New Provider      - tambah provider + backup config otomatis
  2) List All Providers    - lihat semua provider, API key di-mask
  3) Edit Provider         - update base_url / api_key / default_model
  4) Delete Provider       - hapus provider (konfirmasi + backup)
  5) Quick Start           - template OpenAI / Claude / Groq / OpenRouter
  6) Generate Command      - command siap copy-paste
  7) Launch Provider       - stop daemon dulu, terus start jcode pakai profile
  8) Info / Doctor         - deteksi OS, path config, lokasi binary jcode
  9) Restore Backup        - balikin config dari backup lama

Universal: Linux, macOS, Windows (PowerShell/CMD). Butuh Python 3.8+.

Tanpa argumen = mode menu interaktif. Mode non-interaktif (buat scripting):

  jcode-manager.py --list
  jcode-manager.py --add nama --base-url URL --api-key KEY --model MODEL
  jcode-manager.py --edit nama --base-url URL
  jcode-manager.py --delete nama --yes
  jcode-manager.py --quick openai --api-key KEY
  jcode-manager.py --generate nama
  jcode-manager.py --launch nama --yes
  jcode-manager.py --info
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

APP_NAME = "J-Code Provider Manager"
VERSION = "1.0.0"
BACKUP_STAMP_FMT = "%Y%m%d%H%M%S"

# Cuma tiga field ini yang perlu buat provider OpenAI-compatible.
# CATATAN: jcode nggak kenal key `model`, harus `default_model`.
# Jangan tulis `models = [...]` (butuh NamedProviderModelConfig, bikin parse error).
PROVIDER_FIELDS = ("base_url", "api_key", "default_model")


# ---------------------------------------------------------------------------
# Warna & output
# ---------------------------------------------------------------------------

class Ansi:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    CYAN = "\033[36m"
    GREEN = "\033[32m"
    MAGENTA = "\033[35m"
    YELLOW = "\033[33m"
    RED = "\033[31m"
    GRAY = "\033[90m"


def _enable_windows_ansi() -> None:
    """Windows 10+ butuh VT processing diaktifin manual buat ANSI escape."""
    if os.name != "nt":
        return
    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        for handle_id in (-11, -12):  # stdout, stderr
            handle = kernel32.GetStdHandle(handle_id)
            mode = ctypes.c_uint32()
            if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
                kernel32.SetConsoleMode(handle, mode.value | 0x0004)
    except Exception:
        pass


def _color_supported(force: bool = False) -> bool:
    if os.environ.get("NO_COLOR") or os.environ.get("JCODE_MANAGER_NO_COLOR"):
        return False
    if force:
        return True
    if os.environ.get("TERM") == "dumb":
        return False
    try:
        return bool(sys.stdout.isatty())
    except Exception:
        return False


class Palette:
    """Wrapper warna. Kalau warna dimatiin, semua jadi plain text."""

    def __init__(self, enabled: bool):
        self.enabled = enabled

    def _wrap(self, code: str, text: str) -> str:
        return code + text + Ansi.RESET if self.enabled else text

    def cyan(self, text: str) -> str:
        return self._wrap(Ansi.CYAN, text)

    def green(self, text: str) -> str:
        return self._wrap(Ansi.GREEN, text)

    def magenta(self, text: str) -> str:
        return self._wrap(Ansi.MAGENTA, text)

    def yellow(self, text: str) -> str:
        return self._wrap(Ansi.YELLOW, text)

    def red(self, text: str) -> str:
        return self._wrap(Ansi.RED, text)

    def gray(self, text: str) -> str:
        return self._wrap(Ansi.GRAY, text)

    def bold(self, text: str) -> str:
        return self._wrap(Ansi.BOLD, text)

    def dim(self, text: str) -> str:
        return self._wrap(Ansi.DIM, text)


PAL = Palette(_color_supported())


def set_color_enabled(enabled: bool) -> None:
    global PAL
    PAL = Palette(enabled)


def clear_screen() -> None:
    if not sys.stdout.isatty():
        return
    if os.name == "nt":
        os.system("cls")
    else:
        sys.stdout.write("\033[2J\033[H")
        try:
            sys.stdout.flush()
        except Exception:
            pass


def say(text: str = "") -> None:
    print(text)


def ok(text: str) -> None:
    print(PAL.green("[OK] ") + text)


def warn(text: str) -> None:
    print(PAL.yellow("[WARN] ") + text)


def err(text: str) -> None:
    print(PAL.red("[ERROR] ") + text, file=sys.stderr)


def info(text: str) -> None:
    print(PAL.gray("[INFO] ") + text)


def rule(width: int = 62) -> None:
    print(PAL.cyan("=" * width))


def header(title: str, subtitle: str = "") -> None:
    rule()
    print(PAL.cyan(PAL.bold(f"  {title}")))
    if subtitle:
        print(PAL.gray(f"  {subtitle}"))
    rule()


def ask(prompt: str, default: str = "") -> str:
    """Input biasa. EOF (stdin piped habis) -> return default."""
    label = prompt
    if default:
        label = f"{prompt} [{default}]"
    try:
        raw = input(PAL.yellow(label + ": "))
    except EOFError:
        return default
    raw = raw.strip()
    return raw if raw else default


def ask_secret(prompt: str) -> str:
    """Input API key, karakter disembunyiin kalau tty."""
    if sys.stdin.isatty():
        try:
            import getpass

            return getpass.getpass(PAL.yellow(prompt + ": ")).strip()
        except Exception:
            pass
    try:
        return input(PAL.yellow(prompt + ": ")).strip()
    except EOFError:
        return ""


def confirm(prompt: str, assume_yes: bool = False) -> bool:
    if assume_yes:
        return True
    try:
        raw = input(PAL.yellow(prompt + " [y/N]: ")).strip().lower()
    except EOFError:
        return False
    return raw in ("y", "ya", "yes")


def pause(prompt: str = "Tekan Enter buat balik ke menu...") -> None:
    try:
        input(PAL.yellow(prompt))
    except EOFError:
        pass


# ---------------------------------------------------------------------------
# Error type
# ---------------------------------------------------------------------------

class ManagerError(Exception):
    """Error yang pesannya udah ramah buat user."""


# ---------------------------------------------------------------------------
# Deteksi OS & path
# ---------------------------------------------------------------------------

class PlatformInfo:
    """Deteksi OS + path config/binary/shell yang dipakai jcode.

    Linux/macOS : ~/.jcode/config.toml, binary di PATH atau ~/.local/bin
    Windows     : %USERPROFILE%\\.jcode\\config.toml, binary di %LOCALAPPDATA%\\jcode\\bin
    """

    def __init__(self, config_override: Optional[str] = None):
        self.system = platform.system() or "Unknown"
        self.is_windows = os.name == "nt"
        self.is_macos = sys.platform == "darwin"
        self.is_linux = not self.is_windows and not self.is_macos
        self.is_wsl = self.is_linux and (
            "microsoft" in platform.release().lower()
            or bool(os.environ.get("WSL_DISTRO_NAME"))
        )
        self.home = self._resolve_home()
        self.config_path = self._resolve_config_path(config_override)
        self.app_config_dir = self._resolve_app_config_dir()
        self.jcode_bin = self._resolve_jcode_bin()
        self.shell = self._resolve_shell()

    @staticmethod
    def _resolve_home() -> Path:
        if os.name == "nt":
            cand = os.environ.get("USERPROFILE")
            if cand:
                return Path(cand)
        return Path.home()

    def _resolve_config_path(self, override: Optional[str]) -> Path:
        if override:
            return Path(override).expanduser()
        env = os.environ.get("JCODE_MANAGER_CONFIG")
        if env:
            return Path(env).expanduser()
        return self.home / ".jcode" / "config.toml"

    def _resolve_app_config_dir(self) -> Path:
        """Folder app config jcode. Ini lokasi env file provider (api_key_env)."""
        if self.is_windows:
            appdata = os.environ.get("APPDATA")
            if appdata:
                return Path(appdata) / "jcode"
            return self.home / "AppData" / "Roaming" / "jcode"
        xdg = os.environ.get("XDG_CONFIG_HOME")
        base = Path(xdg) if xdg else self.home / ".config"
        return base / "jcode"

    def _resolve_jcode_bin(self) -> str:
        found = shutil.which("jcode")
        if found:
            return found
        candidates: List[Path] = []
        if self.is_windows:
            local = os.environ.get("LOCALAPPDATA")
            if local:
                candidates.append(Path(local) / "jcode" / "bin" / "jcode.exe")
                candidates.append(Path(local) / "Programs" / "jcode" / "jcode.exe")
            candidates.append(self.home / ".local" / "bin" / "jcode.exe")
        else:
            candidates.extend(
                [
                    self.home / ".local" / "bin" / "jcode",
                    Path("/usr/local/bin/jcode"),
                    Path("/opt/homebrew/bin/jcode"),
                    self.home / ".cargo" / "bin" / "jcode",
                ]
            )
        for cand in candidates:
            try:
                if cand.is_file():
                    return str(cand)
            except OSError:
                continue
        return "jcode"

    def _resolve_shell(self) -> str:
        if self.is_windows:
            return "PowerShell"
        shell = os.environ.get("SHELL", "/bin/bash")
        return shell.rsplit("/", 1)[-1] or "bash"

    def describe(self) -> str:
        label = self.system
        if self.is_wsl:
            label += " (WSL)"
        return label

    def jcode_available(self) -> bool:
        if os.path.isabs(self.jcode_bin):
            return os.path.exists(self.jcode_bin)
        return shutil.which(self.jcode_bin) is not None


# ---------------------------------------------------------------------------
# Masking & validasi
# ---------------------------------------------------------------------------

NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")


def mask_key(key: str) -> str:
    """Mask API key: 4 char awal + ... + 4 char akhir."""
    if not key:
        return "(keyless / tanpa key)"
    if len(key) <= 8:
        return "*" * len(key)
    return key[:4] + "..." + key[-4:]


def validate_provider_name(name: str) -> Optional[str]:
    if not name:
        return "Nama provider nggak boleh kosong."
    if not NAME_RE.match(name):
        return (
            "Nama provider harus alfanumerik, boleh '-' dan '_'. "
            "Titik/spasi nggak boleh karena bikin nested table di TOML."
        )
    if len(name) > 64:
        return "Nama provider kepanjangan (maksimal 64 karakter)."
    return None


def validate_base_url(url: str) -> Optional[str]:
    if not url:
        return "Base URL nggak boleh kosong."
    if not re.match(r"^https?://", url, re.I):
        return "Base URL harus mulai dengan http:// atau https://"
    if " " in url:
        return "Base URL nggak boleh ada spasi."
    if "chat/completions" in url.lower():
        return "Base URL nggak perlu path /chat/completions, cukup sampai /v1."
    return None


def base_url_hint(url: str) -> str:
    """Warning halus (bukan error) kalau base URL keliatan ganjil."""
    if re.match(r"^https?://[^/]+/?$", url) and "localhost" not in url and "127.0.0.1" not in url:
        return "Base URL belum ada path. Provider OpenAI-compatible biasanya butuh akhiran /v1."
    return ""


def validate_model(model: str) -> Optional[str]:
    if model and (" " in model or "\t" in model):
        return "Nama model nggak boleh ada spasi."
    return None


# ---------------------------------------------------------------------------
# File config: baca, backup, tulis atomic
# ---------------------------------------------------------------------------

def read_config_text(path: Path) -> str:
    if not path.exists():
        return ""
    try:
        return path.read_text(encoding="utf-8")
    except PermissionError:
        raise ManagerError("Nggak bisa baca %s (permission denied)." % path)
    except UnicodeDecodeError:
        raise ManagerError("%s bukan text UTF-8. Config jcode harus UTF-8." % path)
    except OSError as exc:
        raise ManagerError("Gagal baca %s: %s" % (path, exc))


def backup_config(path: Path) -> Optional[Path]:
    """Bikin config.toml.backup.YYYYMMDDHHmmss sebelum tiap write."""
    if not path.exists():
        return None
    stamp = datetime.now().strftime(BACKUP_STAMP_FMT)
    dest = path.with_name(path.name + ".backup." + stamp)
    n = 1
    while dest.exists():
        dest = path.with_name(path.name + ".backup." + stamp + "." + str(n))
        n += 1
    try:
        shutil.copy2(path, dest)
    except OSError as exc:
        raise ManagerError("Gagal bikin backup %s: %s" % (dest, exc))
    return dest


def list_backups(path: Path) -> List[Path]:
    parent = path.parent
    if not parent.exists():
        return []
    try:
        found = list(parent.glob(path.name + ".backup.*"))
    except OSError:
        return []
    return sorted(found, key=lambda p: p.stat().st_mtime, reverse=True)


def atomic_write(path: Path, text: str, mode: int = 0o600) -> None:
    """Tulis config lewat temp file + os.replace, biar nggak pernah setengah jadi."""
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        raise ManagerError("Gagal bikin folder %s: %s" % (path.parent, exc))
    tmp = path.with_name("." + path.name + ".tmp" + str(os.getpid()))
    try:
        with open(tmp, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        try:
            os.chmod(tmp, mode)
        except OSError:
            pass
        os.replace(tmp, path)
    except PermissionError:
        raise ManagerError(
            "Nggak bisa nulis %s (permission denied). Cek permission folder %s." % (path, path.parent)
        )
    except OSError as exc:
        raise ManagerError("Gagal nulis %s: %s" % (path, exc))
    finally:
        if tmp.exists():
            try:
                tmp.unlink()
            except OSError:
                pass


def validate_toml_text(text: str) -> Optional[str]:
    """Cek hasil akhir config masih TOML valid. None = aman."""
    try:
        import tomllib
    except ImportError:
        return None
    try:
        tomllib.loads(text)
    except Exception as exc:
        return str(exc)
    return None


def toml_error_hint(message: str) -> str:
    if "models" in message:
        return (
            message
            + '\n  Hint: `models = [...]` nggak didukung config.toml jcode. Pakai `default_model = "..."` aja.'
        )
    return message


# ---------------------------------------------------------------------------
# Mini TOML editor
#
# Config di-parse per section, bukan full TOML parse, supaya komentar, urutan
# key, dan section lain (kayak [[providers.x.models]]) tetap utuh byte-per-byte.
# ---------------------------------------------------------------------------

_NAME_PAT = r"""(?:"(?:[^"\\]|\\.)*"|'(?:[^']|'')*'|[A-Za-z0-9_\-]+)"""

_PROVIDER_HEADER_RE = re.compile(
    r"^[ \t]*\[[ \t]*providers[ \t]*\.[ \t]*(?P<name>" + _NAME_PAT + r")[ \t]*\][ \t]*(?:#.*)?$"
)
_PROVIDER_SUB_RE = re.compile(
    r"^[ \t]*\[\[[ \t]*providers[ \t]*\.[ \t]*(?P<name>" + _NAME_PAT + r")[ \t]*\.[ \t]*(?P<sub>[A-Za-z0-9_\-]+)[ \t]*\]\][ \t]*(?:#.*)?$"
)
_KEY_LINE_RE = re.compile(
    r"^[ \t]*(?P<key>" + _NAME_PAT + r")[ \t]*=[ \t]*(?P<value>.*)$"
)

_TOML_ESCAPES = {
    "n": "\n",
    "t": "\t",
    "r": "\r",
    "b": "\b",
    "f": "\f",
    '"': '"',
    "\\": "\\",
    "/": "/",
}


def _unescape_toml(body: str) -> str:
    out: List[str] = []
    i = 0
    while i < len(body):
        ch = body[i]
        if ch == "\\" and i + 1 < len(body):
            nxt = body[i + 1]
            if nxt == "u" and i + 6 <= len(body):
                try:
                    out.append(chr(int(body[i + 2 : i + 6], 16)))
                    i += 6
                    continue
                except ValueError:
                    pass
            out.append(_TOML_ESCAPES.get(nxt, nxt))
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def _escape_toml(value: str) -> str:
    out = []
    for ch in value:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def toml_quote(value: str) -> str:
    return _escape_toml(value)


def unquote_key(raw: str) -> str:
    raw = raw.strip()
    if len(raw) >= 2 and raw[0] == '"' and raw[-1] == '"':
        return _unescape_toml(raw[1:-1])
    if len(raw) >= 2 and raw[0] == "'" and raw[-1] == "'":
        return raw[1:-1]
    return raw


def strip_inline_comment(value: str) -> str:
    """Buang komentar `# ...` yang ada di luar string."""
    out: List[str] = []
    quote = None
    i = 0
    while i < len(value):
        ch = value[i]
        if quote:
            if quote == '"' and ch == "\\" and i + 1 < len(value):
                out.append(value[i : i + 2])
                i += 2
                continue
            if ch == quote:
                quote = None
            out.append(ch)
        else:
            if ch in ('"', "'"):
                quote = ch
                out.append(ch)
            elif ch == "#":
                break
            else:
                out.append(ch)
        i += 1
    return "".join(out).strip()


def parse_value(raw: str) -> str:
    """Ambil nilai string dari `key = value`. Non-string dikembalikan apa adanya."""
    val = strip_inline_comment(raw)
    if len(val) >= 2 and val[0] == '"' and val[-1] == '"':
        return _unescape_toml(val[1:-1])
    if len(val) >= 2 and val[0] == "'" and val[-1] == "'":
        return val[1:-1]
    return val


class Segment:
    """Satu potongan config: preamble, satu provider, atau satu sub-table."""

    __slots__ = ("kind", "name", "lines")

    def __init__(self, kind: str, name: Optional[str] = None, lines: Optional[List[str]] = None):
        self.kind = kind
        self.name = name
        self.lines = list(lines) if lines else []

    def text(self) -> str:
        return "".join(self.lines)


class ProviderEntry:
    """Satu provider hasil parse, plus nilai field yang udah dibersihin."""

    def __init__(self, name: str, fields: Dict[str, str], order: List[str], extra_models: int = 0):
        self.name = name
        self.fields = fields
        self.order = order
        self.extra_models = extra_models

    @property
    def base_url(self) -> str:
        return self.fields.get("base_url", "")

    @property
    def api_key(self) -> str:
        return self.fields.get("api_key", "")

    @property
    def model(self) -> str:
        # `default_model` yang bener. `model` cuma dibaca buat nunjukin salah tulis.
        return self.fields.get("default_model", "") or self.fields.get("model", "")

    @property
    def model_key_is_wrong(self) -> bool:
        return "model" in self.fields and "default_model" not in self.fields

    @property
    def api_key_env(self) -> str:
        return self.fields.get("api_key_env", "")

    @property
    def env_file(self) -> str:
        return self.fields.get("env_file", "")

    @property
    def uses_env_file(self) -> bool:
        return bool(self.api_key_env or self.env_file)

    @property
    def key_state(self) -> str:
        """inline | envfile | keyless"""
        if "api_key" in self.fields:
            return "inline"
        if self.uses_env_file:
            return "envfile"
        return "keyless"


def split_config(text: str) -> List[Segment]:
    segments: List[Segment] = [Segment("preamble")]
    for line in text.splitlines(keepends=True):
        sub = _PROVIDER_SUB_RE.match(line)
        if sub:
            segments.append(Segment("sub", unquote_key(sub.group("name")), [line]))
            continue
        head = _PROVIDER_HEADER_RE.match(line)
        if head:
            segments.append(Segment("provider", unquote_key(head.group("name")), [line]))
            continue
        segments[-1].lines.append(line)
    return segments


def parse_provider_fields(segment: Segment) -> Tuple[Dict[str, str], List[str]]:
    fields: Dict[str, str] = {}
    order: List[str] = []
    for line in segment.lines[1:]:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        m = _KEY_LINE_RE.match(line)
        if not m:
            continue
        key = unquote_key(m.group("key"))
        if key not in order:
            order.append(key)
        fields[key] = parse_value(m.group("value"))
    return fields, order


def parse_config(text: str) -> Tuple[List[Segment], List[ProviderEntry]]:
    segments = split_config(text)
    providers: List[ProviderEntry] = []
    for idx, seg in enumerate(segments):
        if seg.kind != "provider" or seg.name is None:
            continue
        fields, order = parse_provider_fields(seg)
        model_subs = 0
        for nxt in segments[idx + 1 :]:
            if nxt.kind == "sub" and nxt.name == seg.name:
                model_subs += 1
            elif nxt.kind == "provider":
                break
        providers.append(ProviderEntry(seg.name, fields, order, model_subs))
    return segments, providers


def normalize_text(text: str) -> str:
    """Rapihin trailing newline: file TOML selalu berakhir satu newline."""
    if not text.strip():
        return ""
    return text.rstrip("\n") + "\n"


def render_provider_block(
    name: str,
    base_url: str,
    api_key: str,
    model: str,
    key_store: str = "inline",
    auth: str = "bearer",
) -> str:
    """Bikin section provider siap tulis.

    key_store="inline"  -> api_key langsung di config.toml (paling simpel)
    key_store="envfile" -> ngikutin format `jcode provider add`: api_key_env + env_file
    """
    lines = ["[providers.%s]" % name]
    if key_store == "envfile":
        lines.append('type = "openai-compatible"')
        lines.append("base_url = %s" % toml_quote(base_url))
        if auth and auth != "bearer":
            lines.append("auth = %s" % toml_quote(auth))
        elif auth:
            lines.append('auth = "bearer"')
        lines.append("api_key_env = %s" % toml_quote(env_var_name(name)))
        lines.append("env_file = %s" % toml_quote(env_file_name(name)))
        if model:
            lines.append("default_model = %s" % toml_quote(model))
        lines.append("requires_api_key = %s" % ("true" if api_key else "false"))
    else:
        lines.append("base_url = %s" % toml_quote(base_url))
        # api_key wajib ada. Kalau kosong, jcode error
        # "inline api_key not found in environment", jadi tulis string kosong.
        lines.append("api_key = %s" % toml_quote(api_key))
        if model:
            lines.append("default_model = %s" % toml_quote(model))
    return "\n".join(lines) + "\n"


def build_after_add(
    text: str,
    name: str,
    base_url: str,
    api_key: str,
    model: str,
    key_store: str = "inline",
) -> str:
    block = render_provider_block(name, base_url, api_key, model, key_store)
    body = text.rstrip("\n")
    if not body.strip():
        return block
    return body + "\n\n" + block


def build_after_update(text: str, name: str, updates: Dict[str, str]) -> str:
    """Update field provider tanpa ngerusak baris lain.

    Key yang udah ada ditimpa in-place (urutan & komentar tetep), key baru
    disisipin setelah baris key terakhir.
    """
    segments = split_config(text)
    for seg in segments:
        if seg.kind != "provider" or seg.name != name:
            continue
        new_lines = [seg.lines[0]]
        pending = dict(updates)
        last_key_at = 1
        for line in seg.lines[1:]:
            stripped = line.strip()
            m = _KEY_LINE_RE.match(line) if stripped and not stripped.startswith("#") else None
            if m:
                key = unquote_key(m.group("key"))
                if key in pending:
                    new_lines.append("%s = %s\n" % (key, toml_quote(pending.pop(key))))
                    last_key_at = len(new_lines)
                    continue
                last_key_at = len(new_lines) + 1
            new_lines.append(line)
        if pending:
            extra = ["%s = %s\n" % (k, toml_quote(v)) for k, v in pending.items()]
            new_lines[last_key_at:last_key_at] = extra
        seg.lines = new_lines
        break
    return normalize_text("".join(seg.text() for seg in segments))


def build_after_delete(text: str, name: str) -> str:
    """Hapus section provider + semua sub-table `[[providers.<name>.models]]`."""
    segments = split_config(text)
    out: List[Segment] = []
    skip_until_new_provider = False
    for seg in segments:
        if seg.kind == "provider":
            skip_until_new_provider = seg.name == name
            if skip_until_new_provider:
                continue
        if seg.kind == "sub" and seg.name == name and skip_until_new_provider:
            continue
        out.append(seg)
    merged = normalize_text("".join(seg.text() for seg in out))
    # Rapihin kalau ada 3+ newline beruntun bekas section yang dibuang.
    while "\n\n\n" in merged:
        merged = merged.replace("\n\n\n", "\n\n")
    return merged


def env_var_name(provider_name: str) -> str:
    """JCODE_PROVIDER_<NAMA>_API_KEY, sama kayak yang ditulis jcode sendiri."""
    safe = re.sub(r"[^A-Za-z0-9]+", "_", provider_name).strip("_").upper()
    return "JCODE_PROVIDER_%s_API_KEY" % safe


def env_file_name(provider_name: str) -> str:
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "-", provider_name).strip("-")
    return "provider-%s.env" % safe


def build_after_rename(text: str, old_name: str, new_name: str) -> str:
    """Ganti nama provider, termasuk sub-table `[[providers.<nama>.models]]`."""
    segments = split_config(text)
    for seg in segments:
        if seg.name != old_name:
            continue
        if seg.kind == "provider":
            seg.lines[0] = "[providers.%s]\n" % new_name
        elif seg.kind == "sub":
            m = _PROVIDER_SUB_RE.match(seg.lines[0])
            if m:
                seg.lines[0] = "[[providers.%s.%s]]\n" % (new_name, m.group("sub"))
    return normalize_text("".join(seg.text() for seg in segments))


# ---------------------------------------------------------------------------
# Env file provider (mode `jcode provider add`: api_key_env + env_file)
# ---------------------------------------------------------------------------

def env_file_path(plat: PlatformInfo, env_file: str) -> Path:
    return plat.app_config_dir / env_file


def read_env_key(plat: PlatformInfo, env_file: str, var_name: str) -> Optional[str]:
    if not env_file or not var_name:
        return None
    path = env_file_path(plat, env_file)
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        if key.strip() == var_name:
            return value.strip().strip('"').strip("'")
    return None


def write_env_key(plat: PlatformInfo, env_file: str, var_name: str, value: str) -> Path:
    """Tulis API key ke env file privat (chmod 600), terpisah dari config.toml."""
    path = env_file_path(plat, env_file)
    atomic_write(path, "%s=%s\n" % (var_name, value), mode=0o600)
    return path


# ---------------------------------------------------------------------------
# Quick Start template
# ---------------------------------------------------------------------------

PRESETS: List[Dict[str, str]] = [
    {
        "key": "openai",
        "label": "OpenAI",
        "name": "openai",
        "base_url": "https://api.openai.com/v1",
        "model": "gpt-4o",
        "note": "API key format: sk-...",
    },
    {
        "key": "anthropic",
        "label": "Anthropic / Claude",
        "name": "anthropic",
        "base_url": "https://api.anthropic.com",
        "model": "claude-3-5-sonnet-20241022",
        "note": (
            "Kalau endpoint-nya kehabisan path, coba https://api.anthropic.com/v1. "
            "jcode juga punya provider native `anthropic-api` (tanpa profile)."
        ),
    },
    {
        "key": "groq",
        "label": "Groq",
        "name": "groq",
        "base_url": "https://api.groq.com/openai/v1",
        "model": "llama-3.3-70b-versatile",
        "note": "Gratis dan ngebut buat model Llama.",
    },
    {
        "key": "openrouter",
        "label": "OpenRouter",
        "name": "openrouter",
        "base_url": "https://openrouter.ai/api/v1",
        "model": "openai/gpt-4o",
        "note": "API key format: sk-or-...",
    },
]


def find_preset(key: str) -> Optional[Dict[str, str]]:
    key = (key or "").strip().lower()
    for preset in PRESETS:
        if preset["key"] == key or preset["label"].lower() == key:
            return preset
    return None


# ---------------------------------------------------------------------------
# Command jcode
# ---------------------------------------------------------------------------

PROVIDER_KIND = "openai-compatible"


def jcode_command(plat: PlatformInfo, profile: str, model: str = "") -> List[str]:
    exe = "jcode" if shutil.which("jcode") else plat.jcode_bin
    cmd = [exe, "--provider", PROVIDER_KIND, "--provider-profile", profile]
    if model:
        cmd += ["--model", model]
    return cmd


def shell_join(args: Sequence[str]) -> str:
    if os.name == "nt":
        return subprocess.list2cmdline(list(args))
    import shlex

    return " ".join(shlex.quote(a) for a in args)


def verify_profile(plat: PlatformInfo, profile: str, timeout: int = 30) -> Tuple[Optional[bool], str]:
    """Minta jcode baca ulang config buat profile ini.

    Return (True, output) kalau jcode ngerti, (False, output) kalau error,
    (None, pesan) kalau nggak bisa dicek (jcode nggak ada / timeout).
    """
    if not plat.jcode_available():
        return None, "binary jcode nggak ketemu, verifikasi dilewat."
    cmd = [plat.jcode_bin, "provider", "current", "-p", PROVIDER_KIND, "--provider-profile", profile]
    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return None, "verifikasi timeout setelah %ss." % timeout
    except OSError as exc:
        return None, "gagal jalanin jcode: %s" % exc
    out = (proc.stdout or b"").decode("utf-8", "replace").strip()
    if proc.returncode == 0 and "resolved_provider" in out:
        return True, out
    return False, out


# ---------------------------------------------------------------------------
# Manager: semua operasi config
# ---------------------------------------------------------------------------

class Manager:
    """Operasi add/list/edit/delete/launch buat provider jcode."""

    def __init__(self, plat: PlatformInfo, assume_yes: bool = False, do_verify: bool = True):
        self.plat = plat
        self.path = plat.config_path
        self.assume_yes = assume_yes
        self.do_verify = do_verify

    # -- baca --
    def load(self) -> Tuple[str, List[ProviderEntry]]:
        text = read_config_text(self.path)
        _segments, providers = parse_config(text)
        return text, providers

    def provider_names(self) -> List[str]:
        _text, providers = self.load()
        return [p.name for p in providers]

    def find(self, name: str) -> Optional[ProviderEntry]:
        _text, providers = self.load()
        for entry in providers:
            if entry.name == name:
                return entry
        return None

    def key_for_display(self, entry: ProviderEntry) -> Tuple[str, str]:
        """Return (masked_key, sumber) buat list."""
        if entry.key_state == "inline":
            return mask_key(entry.api_key), "config.toml"
        if entry.key_state == "envfile":
            value = read_env_key(self.plat, entry.env_file, entry.api_key_env)
            if value is None:
                return "(env file belum ada)", entry.env_file or "env"
            return mask_key(value), entry.env_file
        return "(nggak ada key)", "-"

    # -- tulis --
    def commit(self, new_text: str, action: str) -> Optional[Path]:
        """Validasi TOML, backup, terus tulis atomic."""
        problem = validate_toml_text(new_text)
        if problem:
            raise ManagerError(
                "Hasil config bukan TOML valid, perubahan dibatalin.\n  " + toml_error_hint(problem)
            )
        backup = backup_config(self.path)
        atomic_write(self.path, new_text, mode=0o600)
        return backup

    def add(
        self,
        name: str,
        base_url: str,
        api_key: str,
        model: str = "",
        key_store: str = "inline",
        force: bool = False,
    ) -> List[str]:
        logs: List[str] = []
        problem = validate_provider_name(name)
        if problem:
            raise ManagerError(problem)
        problem = validate_base_url(base_url)
        if problem:
            raise ManagerError(problem)
        problem = validate_model(model)
        if problem:
            raise ManagerError(problem)
        if key_store not in ("inline", "envfile"):
            raise ManagerError("key_store harus 'inline' atau 'envfile'.")

        text, providers = self.load()
        exists = any(p.name == name for p in providers)
        if exists and not force:
            raise ManagerError(
                "Provider '%s' udah ada. Pakai menu Edit, atau hapus dulu." % name
            )
        if exists:
            text = build_after_delete(text, name)
            logs.append("Provider lama '%s' ditimpa (--force)." % name)

        if key_store == "envfile":
            var = env_var_name(name)
            env_path = write_env_key(self.plat, env_file_name(name), var, api_key)
            logs.append("API key disimpan di %s (mode 600)." % env_path)

        new_text = build_after_add(text, name, base_url, api_key, model, key_store)
        backup = self.commit(new_text, "add")
        if backup:
            logs.append("Backup config: %s" % backup.name)
        logs.append("Provider '%s' ditambahin ke %s" % (name, self.path))
        return logs

    def edit(
        self,
        name: str,
        base_url: Optional[str] = None,
        api_key: Optional[str] = None,
        model: Optional[str] = None,
        new_name: Optional[str] = None,
    ) -> List[str]:
        logs: List[str] = []
        entry = self.find(name)
        if entry is None:
            raise ManagerError("Provider '%s' nggak ada di %s." % (name, self.path))
        text, _providers = self.load()

        if new_name and new_name != name:
            problem = validate_provider_name(new_name)
            if problem:
                raise ManagerError(problem)
            if new_name in self.provider_names():
                raise ManagerError("Provider '%s' udah ada." % new_name)
            text = build_after_rename(text, name, new_name)
            logs.append("Nama provider: %s -> %s" % (name, new_name))

        updates: Dict[str, str] = {}
        if base_url:
            problem = validate_base_url(base_url)
            if problem:
                raise ManagerError(problem)
            updates["base_url"] = base_url
        if model:
            problem = validate_model(model)
            if problem:
                raise ManagerError(problem)
            updates["default_model"] = model
        if api_key is not None and api_key != "":
            if entry.key_state == "envfile":
                var = entry.api_key_env or env_var_name(new_name or name)
                env_file = entry.env_file or env_file_name(new_name or name)
                env_path = write_env_key(self.plat, env_file, var, api_key)
                logs.append("API key diupdate di %s." % env_path)
            else:
                updates["api_key"] = api_key

        if not updates and not new_name:
            raise ManagerError("Nggak ada yang diubah.")

        if updates:
            target = new_name or name
            text = build_after_update(text, target, updates)
            logs.append("Field diupdate: %s" % ", ".join(sorted(updates)))

        backup = self.commit(text, "edit")
        if backup:
            logs.append("Backup config: %s" % backup.name)
        logs.append("Provider '%s' beres diupdate." % (new_name or name))
        return logs

    def delete(self, name: str) -> List[str]:
        logs: List[str] = []
        entry = self.find(name)
        if entry is None:
            raise ManagerError("Provider '%s' nggak ada di %s." % (name, self.path))
        text, _providers = self.load()
        new_text = build_after_delete(text, name)
        if new_text == normalize_text(text):
            raise ManagerError(
                "Section [providers.%s] nggak ketemu, jadi nggak ada yang dihapus." % name
            )
        backup = self.commit(new_text, "delete")
        if backup:
            logs.append("Backup config: %s" % backup.name)
        if entry.key_state == "envfile" and entry.env_file:
            path = env_file_path(self.plat, entry.env_file)
            logs.append("Catatan: env file %s masih ada (dibiarkan, hapus manual kalau perlu)." % path)
        logs.append("Provider '%s' udah dihapus." % name)
        return logs

    def restore(self, backup: Path) -> List[str]:
        if not backup.exists():
            raise ManagerError("Backup %s nggak ketemu." % backup)
        text = read_config_text(backup)
        problem = validate_toml_text(text)
        if problem:
            raise ManagerError("Backup %s bukan TOML valid: %s" % (backup.name, problem))
        current = backup_config(self.path)
        atomic_write(self.path, text, mode=0o600)
        logs = []
        if current:
            logs.append("Config sekarang dibackup ke %s" % current.name)
        logs.append("Config dibalikin dari %s" % backup.name)
        return logs

    # -- tampilan --
    def render_list(self, as_json: bool = False):
        _text, providers = self.load()
        if as_json:
            payload = []
            for p in providers:
                masked, source = self.key_for_display(p)
                payload.append(
                    {
                        "name": p.name,
                        "base_url": p.base_url,
                        "default_model": p.model,
                        "api_key_masked": masked,
                        "key_source": source,
                        "key_state": p.key_state,
                    }
                )
            return payload

        if not providers:
            return [PAL.yellow("No providers configured."), PAL.gray("Config: %s" % self.path)]

        width = max(len(p.name) for p in providers)
        width = max(width, 8)
        lines = []
        for idx, p in enumerate(sorted(providers, key=lambda e: e.name.lower()), start=1):
            masked, source = self.key_for_display(p)
            lines.append(
                "%s %s" % (PAL.gray("%2d." % idx), PAL.green(p.name.ljust(width)))
            )
            lines.append("      %s %s" % (PAL.gray("base_url ."), p.base_url or PAL.red("(kosong)")))
            lines.append(
                "      %s %s"
                % (PAL.gray("model ....."), p.model or PAL.yellow("(belum diset)"))
            )
            lines.append("      %s %s  %s" % (PAL.gray("api_key .."), masked, PAL.gray("<- " + source)))
            notes = []
            if p.model_key_is_wrong:
                notes.append(PAL.yellow("key `model` nggak dibaca jcode, pakai `default_model`"))
            if p.key_state == "keyless":
                notes.append(PAL.yellow("tanpa api_key, jcode bakal nolak profile ini"))
            if p.extra_models:
                notes.append(PAL.gray("%d model tambahan" % p.extra_models))
            for note in notes:
                lines.append("      %s" % note)
        return lines

    def render_command(self, name: str, model: str = "") -> str:
        entry = self.find(name)
        if entry is None:
            raise ManagerError("Provider '%s' nggak ada." % name)
        use_model = model or entry.model
        return shell_join(jcode_command(self.plat, name, use_model))

    # -- daemon & launch --
    def stop_server(self) -> Tuple[int, str]:
        cmd = [self.plat.jcode_bin, "server", "stop", "--force"]
        try:
            proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
        except subprocess.TimeoutExpired:
            return -1, "timeout nunggu server stop"
        except OSError as exc:
            return -1, str(exc)
        return proc.returncode, (proc.stdout or b"").decode("utf-8", "replace").strip()

    def launch(self, name: str, model: str = "") -> int:
        entry = self.find(name)
        if entry is None:
            raise ManagerError("Provider '%s' nggak ada di %s." % (name, self.path))
        if not self.plat.jcode_available():
            raise ManagerError("Binary jcode nggak ketemu di PATH.")

        cmd = jcode_command(self.plat, name, model or entry.model)
        say()
        info("Stop background daemon dulu (flag provider cuma ngaruh pas server fresh).")
        rc, out = self.stop_server()
        if rc == 0:
            ok("Daemon dimatiin.")
        else:
            warn("Stop daemon balikin kode %s, lanjut aja." % rc)
        if out:
            for line in out.splitlines()[:4]:
                say(PAL.gray("  " + line))
        time.sleep(0.5)

        say()
        info("Jalanin: " + PAL.bold(shell_join(cmd)))
        say(PAL.gray("  Keluar dari jcode kalau udah selesai, nanti balik ke menu ini."))
        say()
        try:
            return subprocess.call(cmd)
        except OSError as exc:
            raise ManagerError("Gagal start jcode: %s" % exc)


def doctor_lines(plat: PlatformInfo, manager: Optional[Manager] = None) -> List[str]:
    lines = [
        "%s %s" % (PAL.gray("OS ........"), plat.describe()),
        "%s %s" % (PAL.gray("Python ...."), platform.python_version()),
        "%s %s" % (PAL.gray("Shell ....."), plat.shell),
        "%s %s" % (PAL.gray("Config ...."), plat.config_path),
        "%s %s" % (PAL.gray("Env dir ..."), plat.app_config_dir),
        "%s %s" % (PAL.gray("jcode bin ."), plat.jcode_bin),
    ]
    lines.append(
        "%s %s"
        % (PAL.gray("jcode ok .."), PAL.green("ya") if plat.jcode_available() else PAL.red("nggak ketemu"))
    )
    lines.append(
        "%s %s"
        % (
            PAL.gray("Config file"),
            PAL.green("ada") if plat.config_path.exists() else PAL.yellow("belum ada (bakal dibikin otomatis)"),
        )
    )
    if manager is not None:
        try:
            _text, providers = manager.load()
            lines.append("%s %d" % (PAL.gray("Provider .."), len(providers)))
        except ManagerError as exc:
            lines.append("%s %s" % (PAL.gray("Provider .."), PAL.red(str(exc))))
        backups = list_backups(plat.config_path)
        lines.append("%s %d" % (PAL.gray("Backup ...."), len(backups)))
    return lines


# ---------------------------------------------------------------------------
# Clipboard (opsional, buat menu Generate Command)
# ---------------------------------------------------------------------------

def copy_to_clipboard(text: str) -> bool:
    if os.name == "nt":
        candidates = [["clip"]]
    elif sys.platform == "darwin":
        candidates = [["pbcopy"]]
    else:
        candidates = [["wl-copy"], ["xclip", "-selection", "clipboard"], ["xsel", "--clipboard", "--input"]]
    for cmd in candidates:
        if not shutil.which(cmd[0]):
            continue
        try:
            proc = subprocess.run(cmd, input=text.encode("utf-8"), timeout=10)
            if proc.returncode == 0:
                return True
        except (OSError, subprocess.SubprocessError):
            continue
    return False


# ---------------------------------------------------------------------------
# Helper menu
# ---------------------------------------------------------------------------

def choose_provider(manager: "Manager", prompt: str = "Pilih provider") -> Optional[ProviderEntry]:
    _text, providers = manager.load()
    if not providers:
        warn("Belum ada provider. Tambah dulu lewat menu 1 atau menu 5.")
        return None
    names = sorted(p.name for p in providers)
    for idx, name in enumerate(names, start=1):
        say("  %s %s" % (PAL.gray("%2d." % idx), PAL.green(name)))
    raw = ask("%s (nomor atau nama, kosong = batal)" % prompt)
    if not raw:
        return None
    if raw.isdigit():
        pos = int(raw) - 1
        if 0 <= pos < len(names):
            return manager.find(names[pos])
        warn("Nomor di luar range.")
        return None
    entry = manager.find(raw)
    if entry is None:
        warn("Provider '%s' nggak ketemu." % raw)
    return entry


def report(manager: "Manager", name: str, logs: List[str], do_verify: bool = True) -> None:
    say()
    for line in logs:
        ok(line)
    if do_verify and manager.do_verify:
        say()
        info("Verifikasi: minta jcode baca ulang profile ini...")
        status, out = verify_profile(manager.plat, name)
        if status is True:
            ok("jcode bisa baca profile '%s' tanpa error." % name)
            for line in out.splitlines():
                say(PAL.gray("  " + line))
        elif status is False:
            err("jcode nolak profile '%s':" % name)
            for line in out.splitlines()[:8]:
                say(PAL.gray("  " + line))
            warn("Cek lagi base_url/api_key, atau balikin backup lewat menu 9.")
        else:
            info(out)


def run_menu_action(func, *args, **kwargs) -> None:
    """Jalanin aksi menu, error-nya ditangkep biar menu nggak mati."""
    try:
        func(*args, **kwargs)
    except ManagerError as exc:
        err(str(exc))
    except KeyboardInterrupt:
        say()
        warn("Dibatalin.")


# ---------------------------------------------------------------------------
# Menu: 1 s/d 9
# ---------------------------------------------------------------------------

def menu_add(manager: "Manager") -> None:
    clear_screen()
    header("1. Tambah Provider Baru", "Backup config dibikin otomatis sebelum nulis")
    say(PAL.gray("  Config target: %s" % manager.path))
    say()
    name = ask("Nama provider (contoh: mygw)")
    if not name:
        warn("Nggak ada nama, dibatalin.")
        return
    problem = validate_provider_name(name)
    if problem:
        err(problem)
        return
    if manager.find(name):
        err("Provider '%s' udah ada. Pakai menu 3 (Edit) atau paksa lewat CLI --force." % name)
        return

    base_url = ask("Base URL (contoh: https://api.example.com/v1)")
    problem = validate_base_url(base_url)
    if problem:
        err(problem)
        return
    hint = base_url_hint(base_url)
    if hint:
        warn(hint)

    model = ask("Default model (contoh: gpt-4o, boleh kosong)")
    api_key = ask_secret("API key (kosong = server lokal tanpa auth)")
    if not api_key:
        warn("API key kosong. Field api_key tetap ditulis (string kosong) karena jcode nolak profile tanpa itu.")

    choice = ask("Simpan key di: 1) config.toml inline  2) env file privat", "1")
    key_store = "envfile" if choice.strip() == "2" else "inline"

    logs = manager.add(name, base_url, api_key, model, key_store=key_store)
    report(manager, name, logs)


def menu_list(manager: "Manager") -> None:
    clear_screen()
    header("2. Semua Provider", "API key di-mask, aman buat screenshot")
    say()
    for line in manager.render_list():
        say(line)
    say()
    info("Config: %s" % manager.path)


def menu_edit(manager: "Manager") -> None:
    clear_screen()
    header("3. Edit Provider", "Kosongin input = nilai lama dipertahankan")
    say()
    entry = choose_provider(manager, "Provider yang mau diedit")
    if entry is None:
        return
    masked, source = manager.key_for_display(entry)
    say()
    say("  %s %s" % (PAL.gray("Nama ........"), PAL.green(entry.name)))
    say("  %s %s" % (PAL.gray("base_url ...."), entry.base_url))
    say("  %s %s" % (PAL.gray("model ......."), entry.model or PAL.yellow("(belum diset)")))
    say("  %s %s  %s" % (PAL.gray("api_key .....", ), masked, PAL.gray("<- " + source)))
    say()

    new_name = ask("Nama baru (kosong = tetap)", entry.name)
    base_url = ask("Base URL baru (kosong = tetap)", entry.base_url)
    model = ask("Default model baru (kosong = tetap)", entry.model)
    say(PAL.gray("  Tip: buat API key, kosongin aja kalau nggak mau ganti."))
    api_key = ask_secret("API key baru (kosong = tetap)")

    logs = manager.edit(
        entry.name,
        base_url=None if base_url == entry.base_url else base_url,
        api_key=api_key or None,
        model=None if model == entry.model else model,
        new_name=None if new_name == entry.name else new_name,
    )
    report(manager, new_name or entry.name, logs)


def menu_delete(manager: "Manager") -> None:
    clear_screen()
    header("4. Hapus Provider", "Backup dulu, baru section-nya dibuang")
    say()
    entry = choose_provider(manager, "Provider yang mau dihapus")
    if entry is None:
        return
    say()
    warn("Yang bakal dihapus: [providers.%s] (%s)" % (entry.name, entry.base_url or "base_url kosong"))
    if not confirm("Yakin hapus provider '%s'?" % entry.name, manager.assume_yes):
        warn("Dibatalin, provider aman.")
        return
    logs = manager.delete(entry.name)
    say()
    for line in logs:
        ok(line)


def menu_quick(manager: "Manager") -> None:
    clear_screen()
    header("5. Quick Start", "Template populer. Kamu cuma perlu masukin API key")
    say()
    for idx, preset in enumerate(PRESETS, start=1):
        say(
            "  %s %s"
            % (PAL.gray("%2d." % idx), PAL.green(preset["label"].ljust(20)) + PAL.gray(preset["base_url"]))
        )
    say()
    raw = ask("Pilih nomor template (kosong = batal)")
    if not raw:
        return
    if not raw.isdigit() or not (1 <= int(raw) <= len(PRESETS)):
        warn("Pilihan nggak valid.")
        return
    preset = PRESETS[int(raw) - 1]
    say()
    info(preset["note"])
    say()

    default_name = preset["name"]
    name = ask("Nama provider", default_name)
    problem = validate_provider_name(name)
    if problem:
        err(problem)
        return
    if manager.find(name):
        err("Provider '%s' udah ada. Ganti nama, atau pakai menu 3." % name)
        return

    model = ask("Model", preset["model"])
    base_url = ask("Base URL", preset["base_url"])
    problem = validate_base_url(base_url)
    if problem:
        err(problem)
        return
    api_key = ask_secret("API key")
    if not api_key:
        warn("API key kosong, provider bakal dibikin tanpa auth.")

    logs = manager.add(name, base_url, api_key, model, key_store="inline")
    report(manager, name, logs)


def menu_generate(manager: "Manager") -> None:
    clear_screen()
    header("6. Generate Command", "Copy-paste langsung ke terminal")
    say()
    entry = choose_provider(manager, "Provider")
    if entry is None:
        return
    model = ask("Model (kosong = pakai default profile: %s)" % (entry.model or "belum diset"))
    say()
    command = manager.render_command(entry.name, model)
    say(PAL.cyan("  Command:"))
    say("  " + PAL.bold(command))
    say()
    if copy_to_clipboard(command):
        ok("Command udah dicopy ke clipboard.")
    else:
        info("Clipboard nggak tersedia, copy manual aja dari atas.")
    say()
    say(PAL.gray("  Catatan: kalau daemon jcode udah jalan, flag provider diabaikan."))
    say(PAL.gray("  Pakai menu 7 (Launch) biar daemon di-stop dulu otomatis."))


def menu_launch(manager: "Manager") -> None:
    clear_screen()
    header("7. Launch Provider", "Stop daemon dulu, baru start fresh")
    say()
    entry = choose_provider(manager, "Provider yang mau dipakai")
    if entry is None:
        return
    say()
    warn("Daemon jcode bakal di-STOP. Session yang lagi jalan (termasuk headless/swarm) ikut keputus.")
    if not confirm("Lanjut launch pakai profile '%s'?" % entry.name, manager.assume_yes):
        warn("Dibatalin.")
        return
    model = ask("Model (kosong = pakai default profile: %s)" % (entry.model or "belum diset"))
    exit_code = manager.launch(entry.name, model)
    say()
    info("jcode keluar dengan kode %s." % exit_code)


def menu_info(manager: "Manager") -> None:
    clear_screen()
    header("8. Info & Doctor", "Deteksi OS, path config, dan status jcode")
    say()
    for line in doctor_lines(manager.plat, manager):
        say(line)
    say()
    say(PAL.gray("  Path penting:"))
    say(
        PAL.gray(
            "  - Config  : ~/.jcode/config.toml (Linux/macOS), %USERPROFILE%\\.jcode\\config.toml (Windows)"
        )
    )
    say(PAL.gray("  - Profile : jcode --provider openai-compatible --provider-profile <nama>"))
    say(PAL.gray("  - Daemon  : jcode server stop --force   (wajib sebelum ganti provider)"))


def menu_restore(manager: "Manager") -> None:
    clear_screen()
    header("9. Restore dari Backup", "Balikin config ke versi backup")
    say()
    backups = list_backups(manager.path)
    if not backups:
        warn("Belum ada backup di %s" % manager.path.parent)
        return
    for idx, path in enumerate(backups[:15], start=1):
        stamp = datetime.fromtimestamp(path.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S")
        say("  %s %s  %s" % (PAL.gray("%2d." % idx), PAL.green(path.name), PAL.gray(stamp)))
    say()
    raw = ask("Pilih nomor backup (kosong = batal)")
    if not raw or not raw.isdigit() or not (1 <= int(raw) <= min(len(backups), 15)):
        warn("Dibatalin.")
        return
    target = backups[int(raw) - 1]
    say()
    warn("Config sekarang bakal diganti isi %s" % target.name)
    if not confirm("Lanjut restore?", manager.assume_yes):
        warn("Dibatalin.")
        return
    for line in manager.restore(target):
        ok(line)


# ---------------------------------------------------------------------------
# Menu utama
# ---------------------------------------------------------------------------

MENU_ITEMS: List[Tuple[str, str, str]] = [
    ("1", "Tambah Provider Baru", "green"),
    ("2", "Lihat Semua Provider", "green"),
    ("3", "Edit Provider", "green"),
    ("4", "Hapus Provider", "green"),
    ("5", "Quick Start (OpenAI / Claude / Groq / OpenRouter)", "green"),
    ("6", "Generate Command", "green"),
    ("7", "Launch Provider  (stop daemon + start)", "magenta"),
    ("8", "Info & Doctor", "gray"),
    ("9", "Restore dari Backup", "gray"),
    ("0", "Keluar", "gray"),
]

MENU_HANDLERS = {
    "1": menu_add,
    "2": menu_list,
    "3": menu_edit,
    "4": menu_delete,
    "5": menu_quick,
    "6": menu_generate,
    "7": menu_launch,
    "8": menu_info,
    "9": menu_restore,
}


def paint(text: str, color: str) -> str:
    if color == "green":
        return PAL.green(text)
    if color == "magenta":
        return PAL.magenta(text)
    if color == "gray":
        return PAL.gray(text)
    return PAL.cyan(text)


def interactive_menu(manager: "Manager") -> int:
    while True:
        try:
            _text, providers = manager.load()
            count_line = "%d provider terdaftar" % len(providers)
        except ManagerError as exc:
            count_line = "config bermasalah: %s" % exc
        clear_screen()
        header(APP_NAME, "v%s | %s | %s" % (VERSION, manager.plat.describe(), manager.plat.config_path))
        say(PAL.gray("  " + count_line))
        say()
        for key, label, color in MENU_ITEMS:
            say("  " + paint("%s) %s" % (key, label), color))
        say()
        choice = ask("Pilih menu (0 = keluar)").strip()
        if choice in ("", "0", "q", "quit", "exit"):
            break
        handler = MENU_HANDLERS.get(choice)
        if handler is None:
            warn("Menu '%s' nggak ada. Coba lagi." % choice)
            pause()
            continue
        run_menu_action(handler, manager)
        pause()
    say()
    info("Sampai jumpa. Config kamu di %s" % manager.path)
    return 0


# ---------------------------------------------------------------------------
# Mode non-interaktif (CLI)
# ---------------------------------------------------------------------------

EPILOG = """contoh:
  jcode-manager.py                                  # buka menu interaktif
  jcode-manager.py --list
  jcode-manager.py --add mygw --base-url https://api.example.com/v1 \\
      --api-key sk-xxx --model gpt-4o
  jcode-manager.py --add local --base-url http://localhost:1234/v1 --api-key ""
  jcode-manager.py --edit mygw --model gpt-4o-mini
  jcode-manager.py --delete mygw --yes
  jcode-manager.py --quick groq --api-key gsk_xxx
  jcode-manager.py --generate mygw
  jcode-manager.py --launch mygw --yes
  jcode-manager.py --info

mode key store:
  inline  = api_key ditulis di config.toml (default, paling simpel)
  envfile = api_key disimpan di env file privat (chmod 600), sama kayak
            `jcode provider add`
"""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="jcode-manager",
        description="%s v%s - kelola provider jcode CLI (universal: Linux/macOS/Windows)."
        % (APP_NAME, VERSION),
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--version", action="version", version="%s %s" % (APP_NAME, VERSION))
    parser.add_argument("--config", metavar="PATH", help="override path config.toml")
    parser.add_argument("--no-color", action="store_true", help="matiin warna ANSI")
    parser.add_argument("--no-verify", action="store_true", help="skip verifikasi ke jcode")
    parser.add_argument("-y", "--yes", action="store_true", help="auto-konfirmasi prompt konfirmasi")
    parser.add_argument("--json", action="store_true", help="output JSON (buat --list)")

    actions = parser.add_argument_group("aksi")
    actions.add_argument("--list", "-l", action="store_true", help="tampilkan semua provider")
    actions.add_argument("--info", action="store_true", help="info OS, path config, status jcode")
    actions.add_argument("--add", metavar="NAMA", help="tambah provider baru")
    actions.add_argument("--edit", metavar="NAMA", help="edit provider")
    actions.add_argument("--delete", metavar="NAMA", help="hapus provider")
    actions.add_argument("--quick", metavar="PRESET", help="quick start: openai | anthropic | groq | openrouter")
    actions.add_argument("--generate", metavar="NAMA", help="print command jcode buat provider ini")
    actions.add_argument("--launch", metavar="NAMA", help="stop daemon terus start jcode pakai provider ini")

    fields = parser.add_argument_group("field provider")
    fields.add_argument("--base-url", help="base URL provider OpenAI-compatible")
    fields.add_argument("--api-key", help="API key (kosongin string buat server lokal tanpa auth)")
    fields.add_argument("--api-key-stdin", action="store_true", help="baca API key dari stdin")
    fields.add_argument("--model", help="default model")
    fields.add_argument("--name", help="nama profile buat --quick (default: nama preset)")
    fields.add_argument("--new-name", help="ganti nama provider (buat --edit)")
    fields.add_argument(
        "--key-store", choices=["inline", "envfile"], default="inline", help="lokasi simpan API key"
    )
    fields.add_argument("--force", action="store_true", help="timpa provider yang udah ada")
    actions.add_argument("--restore", metavar="PATH", help="balikin config dari file backup")
    return parser


def run_cli(args: argparse.Namespace, manager: "Manager") -> int:
    if args.info:
        for line in doctor_lines(manager.plat, manager):
            say(line)
        return 0

    if args.list:
        data = manager.render_list(as_json=args.json)
        if args.json:
            say(json.dumps(data, indent=2))
        else:
            for line in data:
                say(line)
        return 0

    if args.add:
        if not args.base_url:
            err("--add butuh --base-url.")
            return 2
        logs = manager.add(
            args.add,
            args.base_url,
            args.api_key or "",
            args.model or "",
            key_store=args.key_store,
            force=args.force,
        )
        report(manager, args.add, logs)
        return 0

    if args.quick:
        preset = find_preset(args.quick)
        if preset is None:
            err("Preset '%s' nggak ada. Pilihan: %s" % (args.quick, ", ".join(p["key"] for p in PRESETS)))
            return 2
        name = args.name or preset["name"]
        logs = manager.add(
            name,
            args.base_url or preset["base_url"],
            args.api_key or "",
            args.model or preset["model"],
            key_store=args.key_store,
            force=args.force,
        )
        report(manager, name, logs)
        return 0

    if args.edit:
        logs = manager.edit(
            args.edit,
            base_url=args.base_url,
            api_key=args.api_key,
            model=args.model,
            new_name=args.new_name,
        )
        report(manager, args.new_name or args.edit, logs)
        return 0

    if args.delete:
        name = args.delete
        if not confirm("Hapus provider '%s'?" % name, manager.assume_yes):
            warn("Dibatalin, provider aman.")
            return 0
        for line in manager.delete(name):
            ok(line)
        return 0

    if args.generate:
        say(manager.render_command(args.generate, args.model or ""))
        return 0

    if args.launch:
        if not confirm("Stop daemon terus launch '%s'?" % args.launch, manager.assume_yes):
            warn("Dibatalin.")
            return 0
        return manager.launch(args.launch, args.model or "")

    if args.restore:
        for line in manager.restore(Path(args.restore).expanduser()):
            ok(line)
        return 0

    return interactive_menu(manager)


def main(argv: Optional[Sequence[str]] = None) -> int:
    _enable_windows_ansi()
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.no_color or not _color_supported():
        set_color_enabled(False)

    if args.api_key_stdin:
        try:
            args.api_key = sys.stdin.readline().strip()
        except (OSError, KeyboardInterrupt):
            args.api_key = ""

    plat = PlatformInfo(args.config)
    do_verify = not args.no_verify
    if args.config and do_verify:
        # jcode selalu baca ~/.jcode/config.toml, jadi verifikasi bakal ngecek
        # file yang salah kalau path-nya di-override. Ditulis ke stderr biar
        # nggak ngerusak output --json.
        do_verify = False
        print(PAL.gray("[INFO] Config di-override, verifikasi ke jcode dilewat."), file=sys.stderr)
    manager = Manager(plat, assume_yes=args.yes, do_verify=do_verify)

    try:
        return run_cli(args, manager)
    except ManagerError as exc:
        err(str(exc))
        return 1
    except KeyboardInterrupt:
        say()
        warn("Dibatalin.")
        return 130


if __name__ == "__main__":
    sys.exit(main())

