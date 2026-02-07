# Doomtainer

Run GZDoom in a Docker container with GPU acceleration. This setup is optimized for Wayland and includes support for Nvidia, AMD, and Intel GPUs.

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
*   Grant display access to the container.
*   Build and run the Docker container using `docker compose`.

The first run will take a few minutes to build the GZDoom engine.

## Configuration

*   **Mods and Maps:** To change which mods and maps are loaded, edit the `command` section in the `docker-compose.yml` file.

*   **GZDoom Settings:** After the first run, a `config` directory will be created. You can edit the `gzdoom.ini` file in this directory to change video, audio, and keybinding settings.

## Troubleshooting

*   **No Audio:** The `run.sh` script attempts to locate your PulseAudio/PipeWire cookie. If you have no audio, check the `PULSE_COOKIE_PATH` in `run.sh` and adjust it to your system's configuration.

*   **Mouse issues on Wayland:** If your mouse is not captured correctly, you can try switching the `SDL_VIDEODRIVER` environment variable in `docker-compose.yml` from `wayland` to `x11`.
