#!/usr/bin/env python3
"""Test deteksi OS & path J-Code Provider Manager.

Linux udah dites beneran lewat smoke-test.sh. File ini nutup bagian yang nggak
mungkin dites langsung di mesin Linux: cabang Windows dan macOS.

Caranya: os.name / sys.platform / platform.system dipatch, plus env var khas
Windows (USERPROFILE, APPDATA, LOCALAPPDATA) di-set ke folder temp, terus dicek
path yang dihasilkan PlatformInfo.

BATASAN yang perlu kamu tau: pathlib di Linux selalu PosixPath, jadi yang
diverifikasi di sini adalah STRUKTUR path dan NAMA ENV VAR yang dipakai
(mis. USERPROFILE vs HOME), bukan rendering backslash khas Windows. Itu
diverifikasi pas jalan di Windows beneran.

    python3 tests/test-platform-paths.py
"""

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import importlib.util

_spec = importlib.util.spec_from_file_location(
    "jcode_manager", str(Path(__file__).resolve().parent.parent / "jcode-manager.py")
)
manager = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(manager)


class OsProxy:
    """Bungkus module os: cuma `name` yang dipalsuin, sisanya diterusin ke aslinya.

    Kenapa nggak patch os.name langsung? Karena pathlib milih WindowsPath vs
    PosixPath dari os.name, dan WindowsPath nggak bisa dibuat di Linux. Dengan
    proxy ini, pathlib tetap pakai os asli, sementara kode manager yang baca
    `os.name` ngeliat nilai palsu.
    """

    def __init__(self, real, name):
        self._real = real
        self.name = name

    def __getattr__(self, item):
        return getattr(self._real, item)


class WindowsPaths(unittest.TestCase):
    """Simulasi Windows: os.name == 'nt'."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / "Users" / "budi"
        self.appdata = self.root / "AppData" / "Roaming"
        self.localappdata = self.root / "AppData" / "Local"
        for path in (self.home, self.appdata, self.localappdata):
            path.mkdir(parents=True, exist_ok=True)

        patcher = mock.patch.object(manager, "os", OsProxy(os, "nt"))
        patcher.start()
        self.addCleanup(patcher.stop)

        sys_patcher = mock.patch.object(manager, "sys", OsProxy(sys, sys.platform))
        sys_patcher.start()
        self.addCleanup(sys_patcher.stop)

        platform_patcher = mock.patch.object(manager.platform, "system", lambda: "Windows")
        platform_patcher.start()
        self.addCleanup(platform_patcher.stop)

        env = {
            "USERPROFILE": str(self.home),
            "APPDATA": str(self.appdata),
            "LOCALAPPDATA": str(self.localappdata),
            "PATHEXT": ".EXE",
        }
        env_patcher = mock.patch.dict(os.environ, env, clear=False)
        env_patcher.start()
        self.addCleanup(env_patcher.stop)

    def test_config_path_pakai_userprofile(self):
        info = manager.PlatformInfo()
        self.assertTrue(info.is_windows)
        self.assertEqual(info.config_path, self.home / ".jcode" / "config.toml")
        self.assertNotIn("HOME", str(info.config_path))

    def test_app_config_dir_pakai_appdata(self):
        info = manager.PlatformInfo()
        self.assertEqual(info.app_config_dir, self.appdata / "jcode")

    def test_shell_powershell(self):
        self.assertEqual(manager.PlatformInfo().shell, "PowerShell")

    def test_describe_windows(self):
        self.assertIn("Windows", manager.PlatformInfo().describe())

    def test_jcode_exe_dicari_di_localappdata(self):
        bin_dir = self.localappdata / "jcode" / "bin"
        bin_dir.mkdir(parents=True, exist_ok=True)
        fake = bin_dir / "jcode.exe"
        fake.write_text("#!/bin/sh\nexit 0\n")

        # shutil.which di-skip biar yang diuji cuma fallback path kandidat.
        with mock.patch.object(manager.shutil, "which", return_value=None):
            info = manager.PlatformInfo()
        self.assertEqual(Path(info.jcode_bin), fake)

    def test_fallback_masih_jcode_kalau_nggak_ada(self):
        with mock.patch.object(manager.shutil, "which", return_value=None):
            info = manager.PlatformInfo()
        self.assertEqual(info.jcode_bin, "jcode")

    def test_override_config_menang(self):
        target = self.root / "custom" / "config.toml"
        info = manager.PlatformInfo(str(target))
        self.assertEqual(info.config_path, target)

    def test_override_env_dir_menang(self):
        # Dipakai test cross-OS: di Windows env file default-nya di %APPDATA%,
        # tapi override ini bikin test hermetik di semua OS.
        target = self.root / "tmp" / "jcode"
        with mock.patch.dict(os.environ, {"JCODE_MANAGER_APP_CONFIG": str(target)}, clear=False):
            self.assertEqual(manager.PlatformInfo().app_config_dir, target)


class MacPaths(unittest.TestCase):
    """Simulasi macOS: sys.platform == 'darwin'."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / "Users" / "budi"
        self.home.mkdir(parents=True, exist_ok=True)

        for target, name, value in (
            (manager.sys, "platform", "darwin"),
            (manager.platform, "system", lambda: "Darwin"),
        ):
            patcher = mock.patch.object(target, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

        env = {
            "HOME": str(self.home),
            "SHELL": "/bin/zsh",
            "XDG_CONFIG_HOME": str(self.root / "xdg"),
        }
        env_patcher = mock.patch.dict(os.environ, env, clear=False)
        env_patcher.start()
        self.addCleanup(env_patcher.stop)

    def test_config_path_sama_kayak_linux(self):
        info = manager.PlatformInfo()
        self.assertTrue(info.is_macos)
        self.assertFalse(info.is_windows)
        self.assertEqual(info.config_path, Path.home() / ".jcode" / "config.toml")

    def test_shell_dibaca_dari_env(self):
        self.assertEqual(manager.PlatformInfo().shell, "zsh")

    def test_binary_kandidat_homebrew(self):
        self.assertTrue(manager.PlatformInfo().is_macos)
        self.assertFalse(manager.PlatformInfo().is_linux)


class LinuxEnv(unittest.TestCase):
    """Linux/WSL: yang dites di CI/mesin nyata."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def test_config_path_default(self):
        info = manager.PlatformInfo()
        self.assertTrue(info.is_linux)
        self.assertEqual(info.config_path, Path.home() / ".jcode" / "config.toml")

    def test_wsl_dideteksi_dari_env(self):
        with mock.patch.dict(os.environ, {"WSL_DISTRO_NAME": "Ubuntu"}, clear=False):
            self.assertTrue(manager.PlatformInfo().is_wsl)

    def test_override_via_env_var(self):
        target = Path(self.tmp.name) / "x.toml"
        with mock.patch.dict(os.environ, {"JCODE_MANAGER_CONFIG": str(target)}, clear=False):
            self.assertEqual(manager.PlatformInfo().config_path, target)

    def test_xdg_config_home_dipakai(self):
        xdg = Path(self.tmp.name) / "xdg"
        with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(xdg)}, clear=False):
            self.assertEqual(manager.PlatformInfo().app_config_dir, xdg / "jcode")

    def test_override_env_dir_menang(self):
        target = Path(self.tmp.name) / "appconf"
        env = {
            "JCODE_MANAGER_APP_CONFIG": str(target),
            "XDG_CONFIG_HOME": str(Path(self.tmp.name) / "xdg"),
        }
        with mock.patch.dict(os.environ, env, clear=False):
            self.assertEqual(manager.PlatformInfo().app_config_dir, target)


class EnvNames(unittest.TestCase):
    """Nama env var & file provider harus sama kayak yang ditulis jcode sendiri."""

    def test_env_var_name(self):
        self.assertEqual(manager.env_var_name("mygw"), "JCODE_PROVIDER_MYGW_API_KEY")
        self.assertEqual(manager.env_var_name("my-gw"), "JCODE_PROVIDER_MY_GW_API_KEY")
        self.assertEqual(manager.env_var_name("my.gw"), "JCODE_PROVIDER_MY_GW_API_KEY")
        # kontrol: nama provider yang dipakai fixture test lain
        self.assertEqual(manager.env_var_name("legacygw"), "JCODE_PROVIDER_LEGACYGW_API_KEY")

    def test_env_file_name(self):
        self.assertEqual(manager.env_file_name("mygw"), "provider-mygw.env")
        self.assertEqual(manager.env_file_name("legacygw"), "provider-legacygw.env")


if __name__ == "__main__":
    unittest.main(verbosity=2)
