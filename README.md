# Doomtainer

Run [UZDoom](https://github.com/UZDoom/UZDoom) (the maintained GZDoom fork) in a Docker container with GPU acceleration. This setup is optimized for Wayland and includes support for Nvidia, AMD, and Intel GPUs.

## Disclaimer

This project does not include any commercial WAD files. You must provide your own legally owned WAD files (e.g., `DOOM.WAD`, `DOOM2.WAD`) in the `original_wads` directory.

## Prerequisites

### 1. General Prerequisites

*   **Docker**: [Install Docker](https://docs.docker.com/engine/install/)
*   **Docker Compose**: [Install Docker Compose](https://docs.docker.com/compose/install/)

### 2. GPU Drivers and Container Runtime

This setup was tested on an NVIDIA GPU with the Niri compositor on Wayland.

#### NVIDIA

You need to install the NVIDIA Container Toolkit.

*   **Arch-based (Manjaro, EndeavourOS, etc.):**
    ```bash
    sudo pacman -S nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    ```

*   **Debian-based (Ubuntu, Pop!_OS, etc.):**
    ```bash
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    ```

*   **Fedora-based:**
    ```bash
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
    sudo dnf clean expire-cache
    sudo dnf install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    ```

#### AMD & Intel

For AMD and Intel GPUs, the setup relies on passing the `/dev/dri` device to the container, which is already configured in the `docker-compose.yml` file. Ensure your user has the necessary permissions to access the render nodes. Adding your user to the `render` group is usually sufficient.

*   **Check if you are in the `render` group:**
    ```bash
    groups $(whoami)
    ```

*   **If not, add yourself to the `render` group:**
    ```bash
    sudo usermod -aG render $(whoami)
    ```
    You will need to log out and log back in for this change to take effect.

## Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/wivill/doomtainer.git
    cd doomtainer
    ```

2.  **Add your WADs:**
    Copy your legally owned WAD files (e.g., `DOOM.WAD`, `DOOM2.WAD`) into the `original_wads` directory.

## How to Run

Simply execute the `run.sh` script:

```bash
./run.sh
```

This script will:
*   Check that your WAD/mod files match `mods.sha256` and pull the latest saves (see [Continuing a game on another machine](#continuing-a-game-on-another-machine)).
*   Generate a `.env` file with your user's UID/GID and display server information.
*   Generate a `docker-compose.override.yml` that adds your host's `video`, `render` and `audio` group IDs to the container. These IDs differ between distros, so the file is gitignored.
*   Grant display access to your user (X11 fallback).
*   Build and run the Docker container using `docker compose`.
*   Commit and push the session's saves when the game exits.

The container runs as your user, not root, so `config/` and your saves stay owned by you. The first run will take a few minutes to build the engine.

> **Upgrading from an older version?** Earlier versions ran the container as root, which left `config/` (including `config/savegames/`) owned by root. `run.sh` checks for this and stops with the fix, which you only need to run once:
> ```bash
> sudo chown -R "$(id -u):$(id -g)" config saves original_wads map_wads mods
> ```

## Native: macOS, Windows (MSI Claw) and Linux without Docker

The container setup doesn't work on macOS: Docker there runs inside a Linux VM with no GPU, Wayland/X11 or PulseAudio passthrough. On Windows there's no reason to add Docker at all. Instead, `run-native.sh` runs the engine natively and uses the same `original_wads/`, `map_wads/` and `mods/` folders. It also reads the same launch arguments from the `command:` block in `docker-compose.yml`, so you only maintain the mod list in one place. It does the same mod, engine-version and save-sync steps as `run.sh`.

Each OS keeps its own engine settings file: `config/uzdoom-macos.ini`, `config/uzdoom-windows.ini` or `config/uzdoom-linux.ini` (the container uses `config/uzdoom.ini`). The engine creates a missing one on first launch; commit it once it's tuned. Set `UZDOOM_INI` (repo-relative) to use another, and `UZDOOM_BIN` to use a different engine binary.

### macOS (Apple Silicon)

1.  **Install UZDoom** (the actively maintained GZDoom fork, with a native ARM64 build), the **same version** the container pins (`UZDOOM_VERSION` in `engines/uzdoom/Dockerfile`). Download `MacOS-UZDoom-Release-ARM64.dmg` from the [UZDoom releases](https://github.com/UZDoom/UZDoom/releases) and drag `UZDoom.app` into `/Applications`. Each release includes a `_release.json` file with the SHA-256 checksum of every asset:
    ```bash
    shasum -a 256 MacOS-UZDoom-Release-ARM64.dmg
    ```
    The app is code-signed but not notarized. If you downloaded it with a browser, macOS will block the first launch. Allow it once under *System Settings → Privacy & Security → Open Anyway*.

2.  **Add your WADs and mods** to the same folders described above.

3.  **Run:**
    ```bash
    ./run-native.sh           # any extra arguments are passed to the engine, e.g. +map E1M1
    ```
    `./run-macos.sh` still works and does the same.

    **Renderer:** on macOS, UZDoom defaults to OpenGL (Apple's OpenGL 4.1 implementation running on Metal). The app also ships MoltenVK, so you can switch to Vulkan by setting `vid_preferbackend 1` in the console, or `vid_preferbackend=1` in `config/uzdoom-macos.ini` (`0` = OpenGL), and restarting. A quick `bench` at the start of E1M1 with Project Brutality on an M5 Pro gave OpenGL about 266 fps and Vulkan about 239 fps, but Vulkan used about 30% less CPU and about 500 MB less memory. Both are well above the display refresh rate, so the main difference is efficiency.

### Windows (e.g. MSI Claw)

1.  **Install [Git for Windows](https://git-scm.com/download/win)**. The launcher runs in its Git Bash, and the repo's `.gitattributes` keeps the scripts LF so bash can run them even with Git's default `core.autocrlf=true`.
2.  **Install UZDoom**, the same version the container pins: download the Windows build from the [UZDoom releases](https://github.com/UZDoom/UZDoom/releases) and extract it to `%LOCALAPPDATA%\Programs\UZDoom\`, `C:\Program Files\UZDoom\` or `C:\Games\UZDoom\` (or put it on `PATH`, or set `UZDOOM_BIN`).
3.  **Add your WADs and mods** to the same folders described above.
4.  **Run** `run-windows.cmd` by double-clicking it, or `./run-native.sh` from Git Bash. On a handheld, `run-windows.cmd` also works as the target of a non-Steam game shortcut, so the game can be launched from Steam's controller UI.

The Windows path is covered by CI (the launcher tests run in Git Bash on a Windows runner), but it hasn't been played on real hardware yet.

## Continuing a game on another machine

Saves live in `saves/`, a clone of a separate **private** repo ([`wivill/doomtainer-saves`](https://github.com/wivill/doomtainer-saves); this repo is public). Every launcher pulls it before the game starts and commits + pushes after the game exits, so you can stop on one machine and continue on another. Set it up once per machine:

```bash
git clone git@github.com:wivill/doomtainer-saves.git saves
```

Without that clone the launchers still work, with a warning, and saves stay on that machine.

**Moving from the old save folders:** saves used to go in `config/savegames/` (container) and `savegames/` (macOS). Those folders are no longer used and the launchers don't touch them. Copy any save you want to keep into `saves/` before deleting them. Slot files from different machines can have the same name (`save00.zds`), so give one an unused slot number: the engine lists every `.zds` in the folder and shows the title stored inside it.

A save only loads on another machine if both run the same engine with the same mod files, so the launchers check these first:

*   **Mod files** must match `mods.sha256`. After changing the mod list in `docker-compose.yml` or updating a mod, run `scripts/update-mods-manifest.sh`, commit `mods.sha256`, and copy the new files to every machine. Hashes are cached by size and mtime in the gitignored `.mods-verified`, so only changed files are re-hashed.
*   **Engine version** must match `UZDOOM_VERSION` in `engines/uzdoom/Dockerfile`. The native launcher reads it from the macOS app bundle or the Windows exe. When a build doesn't report it, the launcher only warns.

`DOOMTAINER_SKIP_CHECKS=1` skips both checks, e.g. to try a new mod. Saves made that way may not load elsewhere.

**Edge cases the launchers handle:**

*   **Offline:** the pull is skipped with a warning, and the push happens on the next launch that can reach GitHub.
*   **Played on two machines without syncing** (e.g. offline on the Claw and at home): saves are binary and can't be merged, so the launcher stops and tells you how to inspect both sides (`git -C saves log --oneline --graph --all`) and keep one (`git -C saves reset --hard origin/main` takes the remote's).
*   **Autosaves** rotate through `auto00`–`auto03` using a counter (`autosavenum`) kept in each machine's ini, so a machine can overwrite the other's most recent autosave. Use a manual save slot as the save you continue from.

### Shared settings

Engine settings that should be the same everywhere (keybinds, gameplay options) go in `config/shared.cfg` as console commands, one per line. Every launcher runs it at startup after the machine's own ini (`-exec`), so it wins over the ini. Video, renderer, mouse sensitivity and gamepad layouts stay per machine in the ini files, because the machines' screens and controllers differ.

## Configuration

*   **Mods and Maps:** To change which mods and maps are loaded, edit the `command` section in the `docker-compose.yml` file.

*   **Engine Settings:** Per-machine settings are stored in `config/uzdoom*.ini` (see above), shared ones in `config/shared.cfg`, and saves in `saves/`. The launchers pass all three paths to the engine explicitly.

## Troubleshooting

*   **No Audio:** The `run.sh` script attempts to locate your PulseAudio/PipeWire cookie. If you have no audio, check the `PULSE_COOKIE_PATH` in `run.sh` and adjust it to your system's configuration.

*   **Mouse issues on Wayland:** If your mouse is not captured correctly, run with X11 instead: `SDL_VIDEODRIVER=x11 ./run.sh`. On niri the game then opens as a normal tiled window, not fullscreen.

*   **Error dialogs on Wayland (NVIDIA):** inside the container NVIDIA's EGL can't allocate Wayland window buffers (`EGL_BAD_ALLOC`). The engine's SDL-drawn dialogs used to crash with `Unable to create renderer: Couldn't find matching render driver`, losing the real error. `docker-compose.yml` now routes EGL to Mesa (`__EGL_VENDOR_LIBRARY_FILENAMES`), which draws those dialogs on the CPU. The game is unaffected because it renders with Vulkan on the GPU. Keep `vid_preferbackend 1` (Vulkan): the OpenGL backend would fall back to Mesa's CPU renderer. If you ever see that `Unable to create renderer` message again, `SDL_VIDEODRIVER=x11 ./run.sh` shows the real error.

*   **Old savegames:** saves only load with the same mods (and compatible mod versions) they were made with. Saves from the GZDoom 4.11.3 + December 2024 Project Brutality + Ultimate DoomVisor setup fail on the current setup with `Unknown object class 'PB_PlayerPawn' … Failed to load savegame`. To load a save from the command line, give `-loadgame` a path relative to `saves/`, e.g. `-loadgame save00.zds`, not `/saves/…`. The old saves are kept in `saves/doom.id.doom1.ultimate/` for history.
