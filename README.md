# Ubuntu Setup

Post-install optimization script for Ubuntu 24.04 LTS. Turns a stock Ubuntu + NVIDIA laptop into a fast, snap-free, Wayland-native developer workstation in one command.

## Quick Install

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/vikgmdev/ubuntu-setup/main/install.sh)"
```

This clones the repo to `~/.ubuntu-setup` and runs the optimizer. Re-running the same command will pull the latest changes and re-apply.

## What It Does

The script runs 15 steps in sequence, each idempotent (safe to re-run):

| Step | What | Why |
|------|------|-----|
| 1 | **Swappiness → 10** | Prevents aggressive swapping on machines with plenty of RAM |
| 2 | **Force Wayland with NVIDIA** | Ubuntu defaults to X11 with NVIDIA drivers. Wayland is faster, supports native fractional scaling, and reduces CPU usage |
| 3 | **Disable tracker indexer** | `tracker-miner-fs-3` constantly indexes files in the background, consuming CPU and I/O |
| 4 | **Disable unnecessary services** | Evolution (mail/calendar/contacts) and GNOME Online Accounts run even if unused |
| 5 | **Install TLP** | Laptop power and thermal management — smarter CPU frequency scaling, better battery life, quieter fans |
| 6 | **GNOME dark theme** | Sets `Yaru-dark` + `prefer-dark` color scheme for consistent app integration. Disables the `ding` desktop icons extension (saves ~3% CPU) |
| 7 | **Remove snapd** | Snaps are slower to launch, use more RAM (each mounts its own squashfs), and have slower I/O. Snapd is purged and blocked from reinstallation |
| 8 | **Install & configure Ghostty** | Installs Ghostty terminal from .deb and syncs keybinds/theme from `configs/ghostty/` |
| 9 | **Add .deb repositories** | Sets up official repos for Firefox (Mozilla), VSCode (Microsoft), Beekeeper Studio, kubectl, and GitHub CLI — then installs them all |
| 10 | **Install downloaded apps** | Interactive step: prompts you to download Slack, Proton Pass, Postman, and Android Studio, then installs each from `~/Downloads`. Press `s` to skip any |
| 11 | **SDKMAN + Gradle + Kotlin** | Installs SDKMAN and uses it to manage Gradle and Kotlin versions |
| 12 | **kubectl zsh completions** | Caches completions to a file instead of generating them on every shell start (saves ~0.5s per terminal open) |
| 13 | **Chrome multi-profile setup** | Creates separate `--user-data-dir` per Google account so each profile runs as an independent process with its own dock icon |
| 14 | **VSCode optimization** | Sets `window.titleBarStyle: custom` so VSCode draws its own title bar (integrates with dark theme) |
| 15 | **Slack title bar fix** | Sets `useSystemTitleBar: false` so Slack uses its own themed title bar |

## Repo Structure

```
ubuntu-setup/
├── install.sh              # One-liner entry point (curl | bash)
├── optimize.sh             # Main 15-step setup script
├── chrome-icons.py         # Generates Chrome-style SVG icons with profile photo badges
├── configs/
│   ├── ghostty/
│   │   ├── config          # Ghostty base config (TERM)
│   │   └── config.ghostty  # Ghostty keybinds and theme
│   └── chrome/
│       └── profiles.conf   # Chrome profile definitions (accounts, colors)
└── README.md
```

## Customization

### Ghostty

Edit `configs/ghostty/config.ghostty` to change keybinds or theme, then push. Next time you run the installer, it syncs the config.

Current keybinds:

| Shortcut | Action |
|----------|--------|
| `Alt+Shift+-` | Split down |
| `Alt+Shift+=` | Split right |
| `Ctrl+Shift+W` | Close split |
| `Alt+Arrow` | Navigate splits |
| `Ctrl+Shift+Arrow` | Resize splits |
| `Ctrl+C` / `Ctrl+V` | Copy / Paste |
| `Ctrl+L` | Clear screen |

### Chrome Profiles

On first run, the script creates `configs/chrome/profiles.conf` from the example template. Edit it with your own Google accounts:

```bash
cp configs/chrome/profiles.conf.example configs/chrome/profiles.conf
# Then edit profiles.conf with your accounts
```

```
# Format: key|original_profile_dir|email|label|color_light|color_mid|color_dark
chrome-work|Default|you@company.com|Work|#93b4f5|#4285F4|#1a56c4
chrome-personal|Profile 1|you@gmail.com|Personal|#7bc694|#34A853|#1e7a35
chrome-side|Profile 2|you@side-project.com|Side Project|#ffab66|#FF6D00|#cc5700
```

> **Note:** `profiles.conf` is gitignored since it contains personal email addresses. Only the `.example` template is tracked.

Each profile gets:
- A separate `--user-data-dir` so windows group under their own dock icon
- A `--class` flag so GNOME treats each as an independent app
- A Chrome-logo-style SVG icon tinted in the profile's color with the Google profile photo as a badge

### Refreshing Chrome Icons

After changing a Google profile photo, run:

```bash
python3 ~/.ubuntu-setup/chrome-icons.py
```

Chrome updates the photo file automatically; this regenerates the SVG icons with the new photo embedded.

## Why These Optimizations

### X11 vs Wayland
Ubuntu defaults to X11 when it detects NVIDIA proprietary drivers (historical compatibility). With modern NVIDIA drivers (550+), Wayland works well and provides native fractional scaling (X11 does it via software upscale/downscale which is CPU-heavy), lower latency, and proper per-app GPU rendering.

### Snaps vs .deb
Snap packages mount a squashfs filesystem per app, which means slower cold starts, higher RAM usage, and slower file I/O. For apps you use constantly (Firefox, Chrome, VSCode, Slack), native .deb packages from official repos are noticeably faster.

### Swappiness
The default value of 60 causes Linux to start swapping when ~40% of RAM is still free. For a workstation with 16GB+ RAM running Chrome, VSCode, and dev servers, this leads to unnecessary disk I/O and perceived sluggishness. A value of 10 keeps things in RAM until actually needed.

### Chrome Multi-Profile
By default, Chrome on Linux treats all profiles as one application — all windows share a single dock icon and process group. Using separate `--user-data-dir` per profile forces Chrome to launch independent processes, each with its own `--class` so GNOME groups them correctly under their own dock icon.

## After Running

A few things need to be done manually:

1. **Log out and select "Ubuntu on Wayland"** at the login screen (only needed once — the script makes it permanent)
2. **Enable Memory Saver** in Chrome at `chrome://settings/performance`
3. **Pin the Chrome profile icons** to the dash (search for "Chrome Personal", "Chrome Totem", "Chrome Range" in Activities)

## Updating

To pull config changes and re-run:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/vikgmdev/ubuntu-setup/main/install.sh)"
```

Or manually:

```bash
cd ~/.ubuntu-setup && git pull && bash optimize.sh
```

## Tested On

- Ubuntu 24.04.4 LTS
- Intel Core Ultra 9 185H + NVIDIA RTX 4060 Max-Q
- NVIDIA driver 580 + CUDA 13.0
- GNOME 46 on Wayland
