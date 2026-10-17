# J-Code Provider Manager

Script interaktif buat ngatur provider jcode CLI. Universal: jalan di **Linux**,
**macOS**, dan **Windows** (PowerShell/CMD) selama ada Python 3.8+.

```
jcode-manager/
├── jcode-manager.py        # engine Python (fitur paling lengkap, utama)
├── jcode-manager.sh        # launcher + engine Bash (fallback tanpa Python)
├── jcode-manager.ps1       # launcher Windows (nyari Python)
├── create-shortcut.sh      # bikin symlink / desktop entry
├── README.md
└── tests/
    ├── test-platform-paths.py  # deteksi OS & path (Windows/macOS simulasi)
    ├── smoke-test.sh           # 63 test engine Python
    ├── smoke-test-fallback.sh  # 57 test engine Bash (tanpa Python)
    ├── verify-with-jcode.sh    # acceptance test pakai binary jcode asli (sandbox)
    └── mock-openai-server.py   # server OpenAI-compatible palsu buat test di atas
```

## Dua engine

`jcode-manager.sh` itu pintu masuk utama dan dia pinter milih engine:

| Kondisi | Yang jalan |
| ------- | ---------- |
| Python 3.8+ ada | **engine Python** (`jcode-manager.py`), fitur paling lengkap |
| Python nggak ada | **engine Bash** self-contained, fitur inti tetap jalan |
| `JCODE_MANAGER_ENGINE=bash` | paksa engine Bash |
| `JCODE_MANAGER_ENGINE=python` | paksa engine Python, error kalau nggak ada |

Engine Bash nggak butuh dependency apa-apa (cuma bash + coreutils/awk): menu 1-9,
add/list/edit/delete/quick start/generate/launch/restore, backup, masking key, dan
format config yang sama. Yang beda: engine Bash nggak punya mode `--key-store envfile`
buat bikin provider baru (tapi tetap bisa baca dan mask key dari env file yang udah ada),
dan `--list --json` di engine Bash cuma nyetak subset field.

Engine Python yang nulis config di dokumen ini, kalau nggak disebut lain.

## Fitur

| Menu | Fungsi |
| ---- | ------ |
| 1 | **Add New Provider** - input nama, base_url, api_key (masked), default_model. Validasi duplikat + backup otomatis |
| 2 | **List All Providers** - nama, base_url, model, API key ter-mask, sumber key |
| 3 | **Edit Provider** - input kosong = nilai lama dipertahankan, bisa rename |
| 4 | **Delete Provider** - konfirmasi + backup, section `[[providers.x.models]]` ikut dibuang |
| 5 | **Quick Start** - template OpenAI / Claude / Groq / OpenRouter, cuma perlu API key |
| 6 | **Generate Command** - command siap copy-paste (auto-copy ke clipboard kalau ada) |
| 7 | **Launch Provider** - `server stop --force` dulu, baru start pakai profile |
| 8 | **Info & Doctor** - OS, path config, env dir, lokasi binary, jumlah provider/backup |
| 9 | **Restore dari Backup** - balikin config dari backup lama |

## Cara Pakai

```bash
# 1. Buka menu (bisa dari file langsung atau lewat symlink)
./jcode-manager.sh              # Linux/macOS/WSL, auto pilih engine
python3 jcode-manager.py        # langsung ke engine Python
jcode-manager                   # kalau symlink-nya udah dipasang

# 2. Pilih menu, ikutin instruksi
# 3. Setelah selesai, tekan Enter buat balik ke menu
```

Bikin shortcut biar bisa dipanggil dari mana aja:

```bash
./create-shortcut.sh                 # symlink ke ~/.local/bin/jcode-manager
./create-shortcut.sh --entry python  # nunjuk langsung ke jcode-manager.py
./create-shortcut.sh --desktop       # + entry menu aplikasi (Linux)
./create-shortcut.sh --uninstall     # hapus

sudo ./create-shortcut.sh --bin-dir /usr/local/bin   # kalau mau global
```

Windows:

```powershell
.\jcode-manager.ps1
.\jcode-manager.ps1 --list
# Kalau kena execution policy:
powershell -ExecutionPolicy Bypass -File .\jcode-manager.ps1
```

## Kirim ke orang lain

Tool ini cuma file biasa, nggak ada dependency dan nggak ada path yang di-hardcode
(folder-nya diresolve dari lokasi script, jadi bisa ditaruh di mana aja).

**Cara paling gampang: kirim foldernya**

```bash
# di komputer kamu
tar -czf jcode-manager.tar.gz jcode-manager/
# kirim file itu, terus di komputer penerima:
tar -xzf jcode-manager.tar.gz
cd jcode-manager
./install.sh
```

**Lewat git**

```bash
git init && git add -A && git commit -m "J-Code Provider Manager"
# push ke GitHub/GitLab, terus penerima:
git clone <url-repo> && cd jcode-manager && ./install.sh
```

**Yang dilakuin `install.sh`**

1. `chmod +x` script yang perlu
2. cek `jcode`, Python, dan bash ada atau nggak (kalau ada yang kurang, dikasih tau cara install-nya)
3. pasang symlink `jcode-manager` (bisa dilewat pakai `--no-link`)
4. jalanin `--info` biar langsung keliatan path config yang bakal dipakai

`install.sh` **nggak nyentuh** config jcode yang udah ada. Dia cuma nerangin path,
nggak nulis apa-apa. Nulis config baru terjadi kalau penerima sendiri yang pilih
menu 1/5/9.

**Yang perlu dipastiin di komputer penerima**

| Butuh | Catatan |
| ----- | ------- |
| jcode | wajib, karena manager cuma ngatur provider-nya. Kalau `jcode` nggak ada, manager tetap jalan tapi nggak bisa launch |
| Python 3.8+ **atau** bash | salah satu aja. Tanpa Python, engine Bash otomatis dipakai |
| bash 4.2+ buat engine Bash | macOS default masih bash 3.2, jadi pakai `brew install bash` kalau mau jalur non-Python di macOS |

**Buat yang mau ngecek dulu sebelum percaya**

```bash
bash tests/smoke-test.sh            # 64 test engine Python (config sementara, aman)
bash tests/smoke-test-fallback.sh   # 57 test engine Bash
python3 tests/test-platform-paths.py # 16 test deteksi OS/path
bash tests/verify-with-jcode.sh      # 20 test pakai binary jcode asli, di sandbox
```

Semua test pakai config sementara di folder temp, jadi config jcode yang beneran
nggak kesentuh. Yang perlu izin lebih cuma `--bin-dir /usr/local/bin`.

### Mode non-interaktif

Semua fitur bisa dipakai tanpa menu, cocok buat scripting:

```bash
python3 jcode-manager.py --list
python3 jcode-manager.py --list --json
python3 jcode-manager.py --info

python3 jcode-manager.py --add mygw --base-url https://api.example.com/v1 \
    --api-key sk-xxx --model gpt-4o

# server lokal tanpa auth (lmstudio/ollama): api_key string kosong
python3 jcode-manager.py --add local --base-url http://localhost:1234/v1 --api-key ""

python3 jcode-manager.py --edit mygw --model gpt-4o-mini
python3 jcode-manager.py --edit mygw --new-name gateway
python3 jcode-manager.py --delete mygw --yes

python3 jcode-manager.py --quick groq --api-key gsk_xxx
python3 jcode-manager.py --generate mygw
python3 jcode-manager.py --launch mygw --yes
python3 jcode-manager.py --restore ~/.jcode/config.toml.backup.20261017200113
```

API key dari stdin (biar nggak nyangkut di shell history):

```bash
printf '%s' "$MY_KEY" | python3 jcode-manager.py --add mygw \
    --base-url https://api.example.com/v1 --api-key-stdin --model gpt-4o
```

## Format Config

Manager nulis format paling minimal yang jcode butuh (udah dites langsung ke
binary jcode v0.98.1):

```toml
[providers.<nama>]
base_url = "https://api.example.com/v1"
api_key = "sk-xxx"
default_model = "gpt-4o"
```

Tiga catatan penting:

1. Key-nya **`default_model`**, bukan `model`. Kalau pakai `model`, jcode diam-diam
   ngabaikan dan jatuh ke model default katalog (bukan error, tapi salah model).
2. **Jangan** tulis `models = [...]`. Bentuk itu butuh struct `NamedProviderModelConfig`
   dan bikin TOML parse error. Cukup `default_model`.
3. Field `api_key` **wajib ada**. Kalau dihapus, jcode gagal dengan
   `Error: inline api_key not found in environment`. Buat server lokal tanpa auth,
   tulis `api_key = ""` (string kosong, bukan dihilangkan).

Config lain di file kamu (komentar, urutan key, `[[providers.x.models]]`) dipertahankan
byte-per-byte. Hanya section provider yang disentuh yang berubah.

### Mode penyimpanan API key

Saat add/edit, manager nawarin dua mode (`--key-store` di CLI):

| Mode | Isi config | Lokasi key | Cocok buat |
| ---- | ---------- | ---------- | ---------- |
| `inline` (default) | `api_key = "..."` | `~/.jcode/config.toml` | Simpel, satu file |
| `envfile` | `api_key_env` + `env_file` + `type`/`auth` | `<XDG_CONFIG_HOME>/jcode/provider-<nama>.env`, mode `600` | Sama persis kayak `jcode provider add`, key kepisah dari config |

Config ditulis dengan mode `600` karena bisa nongkrongin API key di dalamnya.

## Daemon jcode: kenapa harus stop dulu

jcode punya background daemon yang persisten. Flag `--provider` /
`--provider-profile` **cuma berlaku pas server pertama kali start**. Kalau daemon
udah jalan, jcode bilang:

> Server already running; provider/model flags only apply when starting a new server.

Jadi menu 7 dan `--launch` jalanin urutan ini:

1. `jcode server stop --force` (error diabaikan kalau server nggak jalan)
2. tunggu 0.5 detik
3. `jcode --provider openai-compatible --provider-profile <nama> [--model <model>]`
4. setelah keluar dari jcode, balik ke menu

Kalau kamu prefer manual, menu 6 ngasih command-nya dan ingetin soal daemon ini.

> Perhatian: `server stop` itu mematikan daemon, termasuk session headless/swarm
> yang lagi jalan. Manager selalu minta konfirmasi dulu.

## Keamanan

- API key ditampilkan ter-mask: `sk-abc...xyz` (4 karakter awal + 4 akhir).
  Key pendek (<= 8 karakter) di-mask total.
- Backup otomatis sebelum **setiap** penulisan: `config.toml.backup.YYYYMMDDHHmmss`.
  Kalau dalam detik yang sama udah ada, dikasih suffix angka biar nggak ketimpa.
- Tulis config pakai temp file + `os.replace`, jadi nggak ada kondisi file setengah jadi.
- Hasil config divalidasi TOML sebelum ditulis. Kalau invalid, perubahan dibatalkan
  dan file lama nggak disentuh.
- Setelah add/edit, manager jalanin `jcode provider current --provider-profile <nama>`
  buat mastiin jcode beneran bisa baca profile-nya (skip otomatis kalau `--config`
  dipakai, karena jcode selalu baca path default).
- Folder config dibikin otomatis kalau belum ada.

## Testing

Tiga lapis test, dari yang paling murah sampai paling keras:

```bash
python3 tests/test-platform-paths.py   # 16 test: deteksi OS & path per platform
bash tests/smoke-test.sh               # 64 test engine Python
bash tests/smoke-test-fallback.sh      # 57 test engine Bash
bash tests/verify-with-jcode.sh        # 20 test pakai binary jcode asli (sandbox)
```

- **test-platform-paths.py** - nyimulasiin cabang Windows (`os.name == 'nt'`, env
  `USERPROFILE`/`APPDATA`/`LOCALAPPDATA`) dan macOS (`sys.platform == 'darwin'`),
  plus Linux/WSL dan nama env var provider.
- **smoke-test.sh** - engine Python: add/list/edit/delete/quick/generate/restore/menu,
  masking key, integritas config (komentar + provider lain nggak keganggu), mode envfile,
  urutan `stop daemon` di fitur launch (pakai stub `jcode`, daemon asli aman),
  kompatibilitas syntax Python 3.8, dan pemilihan engine.
- **smoke-test-fallback.sh** - hal yang sama buat engine Bash, plus cek delegasi ke
  Python (termasuk lewat symlink) dan fallback otomatis kalau Python nggak ada.
- **verify-with-jcode.sh** - jalanin binary jcode asli di sandbox bubblewrap dengan
  HOME terpisah dan socket daemon terpisah, lalu ngebuktiin:
  - `jcode provider current` bisa baca config hasil manager (engine Python **dan** Bash)
  - `default_model` dari profile beneran kepakai
  - chat beneran jalan (`run` balikin `PONG` dari mock server)
  - API key beneran dikirim sebagai `Authorization: Bearer ...`
  - mode `envfile` juga jalan
  - `server start --provider-profile` nempel di proses daemon
  - `server stop --force` matiin daemon dan ngosongin socket

### Status verifikasi (jujur, per platform)

| Bagian | Linux | macOS | Windows |
| ------ | ----- | ----- | ------- |
| Deteksi path config & env dir | dites langsung | simulasi | simulasi |
| CRUD provider + config TOML (engine Python) | dites langsung | sama (kode shared) | sama (kode shared) |
| CRUD provider + config TOML (engine Bash) | dites langsung | belum | belum |
| Config dibaca jcode asli (kedua engine) | dites langsung | belum | belum |
| Menu, warna, clipboard | dites langsung | belum | belum (clip pakai `clip`) |
| Launcher `.sh` | dites langsung | belum | belum (Git Bash/MSYS) |
| Launcher `.ps1` | n/a | n/a | **belum dites** (nggak ada PowerShell di mesin test) |

"simulasi" artinya patch `os.name`/`sys.platform` + env var khas platform lalu cek
path yang dihasilkan, bukan jalan di OS aslinya. Yang belum dites di macOS/Windows:
rendering backslash, PowerShell launcher, dan clipboard integration. Launcher `.ps1`
cuma nyari Python (nggak ada engine PowerShell), jadi di Windows tetap butuh Python 3.8+.

Satu bagian yang **nggak bisa** diotomasi di sini: perilaku "flag provider diabaikan
kalau daemon udah jalan", karena itu cuma kepakai sama client interaktif (TUI /
`jcode connect`) dan butuh terminal. Yang bisa diverifikasi headless (flag nempel di
proses server, urutan stop sebelum start, `stop --force` aman kalau server mati)
sudah masuk test.

Hasil terakhir di mesin ini (jcode v0.98.1, Linux): **16 ok / 0 fail** (platform),
**64 ok / 0 fail** (engine Python), **57 ok / 0 fail** (engine Bash),
**20 ok / 0 fail** (acceptance pakai binary jcode asli). Total 157 check.

## Troubleshooting

**"Server already running; provider/model flags only apply when starting a new server"**
Daemon masih hidup. Pakai menu 7 / `--launch`, atau manual: `jcode server stop --force`.

**Config nggak kebaca / TOML parse error**
Cek `~/.jcode/config.toml` lewat menu 2, atau `python3 jcode-manager.py --info`.
Kalau abis nulis manual, kemungkinan kena `models = [...]`. Balikin lewat menu 9.

**Provider ditolak: `Unknown provider profile 'x'`**
Section `[providers.x]` belum ada. Cek menu 2. Ingat flag-nya
`--provider-profile`, bukan `--provider` doang.

**Provider ditolak: `inline api_key not found in environment`**
Field `api_key` nggak ada di section itu. Buat server tanpa auth, isi `api_key = ""`.

**Restore config dari backup**
Menu 9, atau lihat file `~/.jcode/config.toml.backup.*` terus restore manual.

**`upstream connection lost` pas kerjaan panjang**
Ini bukan masalah manager atau config. Ini stream model yang diputus upstream
(gateway/router) kalau generasi kepanjangan. Cek `~/.jcode/logs/jcode-*.log`:
kalau ketemu `phase=stream_event_error error="upstream connection lost"`, artinya
turn yang jalan terlalu lama (bukan config kamu yang salah). Solusinya: pindah ke
provider/model yang lebih stabil lewat manager ini, atau pecah kerjaannya.

## Path per OS

| OS | Config | Env file provider |
| -- | ------ | ----------------- |
| Linux | `~/.jcode/config.toml` | `$XDG_CONFIG_HOME/jcode/` (default `~/.config/jcode/`) |
| macOS | `~/.jcode/config.toml` | `$XDG_CONFIG_HOME/jcode/` (default `~/.config/jcode/`) |
| Windows | `%USERPROFILE%\.jcode\config.toml` | `%APPDATA%\jcode\` |

Binary jcode yang dicari: `jcode` di PATH, lalu `~/.local/bin/jcode` (Linux),
`/usr/local/bin/jcode` + `/opt/homebrew/bin/jcode` (macOS),
`%LOCALAPPDATA%\jcode\bin\jcode.exe` (Windows).

Override path config (berguna buat testing): `--config /path/ke/config.toml`
atau env `JCODE_MANAGER_CONFIG`.

## Env var yang dipakai

| Var | Fungsi |
| --- | ------ |
| `JCODE_MANAGER_CONFIG` | Override path config.toml |
| `JCODE_MANAGER_ENGINE` | `auto` (default) / `python` / `bash` |
| `JCODE_MANAGER_PYTHON` | Paksa interpreter Python tertentu di launcher |
| `NO_COLOR` / `JCODE_MANAGER_NO_COLOR` | Matiin warna ANSI |

## Alternatif resmi dari jcode

jcode sendiri punya:

```bash
jcode provider add mygw --base-url https://api.example.com/v1 --model gpt-4o
jcode provider current -p openai-compatible --provider-profile mygw
jcode provider list
```

Manager ini nambahin: menu interaktif, list + masking key, edit/hapus, quick start,
generate command, backup + restore, dan launch yang otomatis ngurus daemon.
Kalau kamu cuma butuh nambah provider sekali, `jcode provider add` udah cukup.

Beda kecil yang perlu kamu tau: `jcode provider add` nulis format lengkap
(`type`, `auth`, `api_key_env`, `env_file`, `requires_api_key`, plus `[[providers.x.models]]`)
tanpa bikin backup config, dan ninggalin `[[providers.x.models]]` yang bisa
bikin bingung. Manager ini default-nya nulis 3 field minimal + selalu bikin
backup dulu, dan punya mode `--key-store envfile` kalau kamu mau format lengkap
kayak jcode.
