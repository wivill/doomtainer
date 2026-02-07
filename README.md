🛠️ Installation & Usage

    Prepare the Script Make sure the launch script is executable:

    Add your WADs Copy your legally owned DOOM2.WAD (or other IWADs) into the original_wads/ folder.

    Launch Run the helper script. This script dynamically generates the necessary environment variables (.env) for Wayland and Audio sockets before triggering Docker Compose.

    The first run will take a few minutes to compile the GZDoom engine.

🎮 Customizing Mods & Maps

To change the mods or maps you are playing, edit the command section in the docker-compose.yml file.

Example: Running Doom II with Project Brutality and a custom map pack.

Note: The internal container paths /games/iwads, /games/mods, and /games/maps are fixed. Only change the filenames.
⚙️ Configuration (Resolution & Keybinds)

After the first run, a config/ folder will be created in your project root.

    You can edit config/gzdoom.ini directly from your host machine to change resolution, keybindings, or rendering settings without restarting the container.

    Recommended Niri/Wayland Settings in gzdoom.ini:

🔧 Troubleshooting

No Audio: The run.sh script attempts to locate your PulseAudio cookie automatically. If audio fails, check if your cookie is located in a non-standard path and update the PULSE_COOKIE_PATH logic in run.sh.

Mouse capturing issues (Wayland): If the mouse drifts out of the window in your Wayland compositor, open docker-compose.yml and change:

to:
📜 License

This project setup is open source. GZDoom and Project Brutality hold their own respective licenses. DO NOT distribute commercial WAD files (DOOM.WAD, DOOM2.WAD) with this repository.