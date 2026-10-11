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
*   Generate a `.env` file with your user's UID/GID and display server information.
*   Generate a `docker-compose.override.yml` that adds your host's `video`, `render` and `audio` group IDs to the container. These IDs differ between distros, so the file is gitignored.
*   Grant display access to your user (X11 fallback).
*   Build and run the Docker container using `docker compose`.

The container runs as your user, not root, so `config/` and your saves stay owned by you. The first run will take a few minutes to build the engine.

> **Upgrading from an older version?** Earlier versions ran the container as root, which left `config/` (including `config/savegames/`) owned by root. `run.sh` checks for this and stops with the fix, which you only need to run once:
> ```bash
> sudo chown -R "$(id -u):$(id -g)" config original_wads map_wads mods
> ```

## macOS (native, Apple Silicon)

The container setup doesn't work on macOS: Docker there runs inside a Linux VM with no GPU, Wayland/X11 or PulseAudio passthrough. Instead, `run-macos.sh` runs the engine natively and uses the same `original_wads/`, `map_wads/` and `mods/` folders. It also reads the same launch arguments from the `command:` block in `docker-compose.yml`, so you only maintain the mod list in one place.

1.  **Install UZDoom** (the actively maintained GZDoom fork, with a native ARM64 build). Download `MacOS-UZDoom-Release-ARM64.dmg` from the [UZDoom releases](https://github.com/UZDoom/UZDoom/releases) and drag `UZDoom.app` into `/Applications`. Each release includes a `_release.json` file with the SHA-256 checksum of every asset:
    ```bash
    shasum -a 256 MacOS-UZDoom-Release-ARM64.dmg
    ```
    The app is code-signed but not notarized. If you downloaded it with a browser, macOS will block the first launch. Allow it once under *System Settings → Privacy & Security → Open Anyway*.

2.  **Add your WADs and mods** to the same folders described above.

3.  **Run:**
    ```bash
    ./run-macos.sh            # any extra arguments are passed to the engine, e.g. +map E1M1
    ```
    The script checks that every referenced file exists before it launches.

    **Renderer:** on macOS, UZDoom defaults to OpenGL (Apple's OpenGL 4.1 implementation running on Metal). The app also ships MoltenVK, so you can switch to Vulkan by setting `vid_preferbackend 1` in the console, or `vid_preferbackend=1` in `config/uzdoom-macos.ini` (`0` = OpenGL), and restarting. A quick `bench` at the start of E1M1 with Project Brutality on an M5 Pro gave OpenGL about 266 fps and Vulkan about 239 fps, but Vulkan used about 30% less CPU and about 500 MB less memory. Both are well above the display refresh rate, so the main difference is efficiency. Settings are stored in `config/uzdoom-macos.ini`, separate from the container's `uzdoom.ini` so each machine keeps its own video, mouse and key settings. Saves go in `savegames/`. To use a different engine binary, set `UZDOOM_BIN`.

## Configuration

*   **Mods and Maps:** To change which mods and maps are loaded, edit the `command` section in the `docker-compose.yml` file.

*   **Engine Settings:** Settings are stored in `config/uzdoom.ini` and saves in `config/savegames/`. The container passes both paths to the engine explicitly. Edit `uzdoom.ini` to change video, audio, and keybinding settings.

## Troubleshooting

*   **No Audio:** The `run.sh` script attempts to locate your PulseAudio/PipeWire cookie. If you have no audio, check the `PULSE_COOKIE_PATH` in `run.sh` and adjust it to your system's configuration.

*   **Mouse issues on Wayland:** If your mouse is not captured correctly, you can try switching the `SDL_VIDEODRIVER` environment variable in `docker-compose.yml` from `wayland` to `x11`.
