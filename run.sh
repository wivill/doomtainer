#!/bin/bash

# 1. Get user IDs
USER_UID=$(id -u)
USER_GID=$(id -g)

# 2. Locate the PulseAudio/Pipewire Cookie
# It is usually in ~/.config/pulse/cookie, but sometimes it varies.
if [ -f "$HOME/.config/pulse/cookie" ]; then
    PULSE_COOKIE_PATH="$HOME/.config/pulse/cookie"
elif [ -f "$HOME/.pulse-cookie" ]; then
    PULSE_COOKIE_PATH="$HOME/.pulse-cookie"
else
    # If it does not exist, we generate a dummy so that docker does not fail when mounting,
    # although the audio might not work without it if security is strict.
    echo "Warning: Audio cookie not found."
    touch /tmp/dummy_pulse_cookie
    PULSE_COOKIE_PATH="/tmp/dummy_pulse_cookie"
fi

# 3. Create dynamic .env file
echo "UID=$USER_UID" > .env
echo "GID=$USER_GID" >> .env
echo "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" >> .env
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY" >> .env
echo "DISPLAY=$DISPLAY" >> .env
echo "PULSE_COOKIE_HOST=$PULSE_COOKIE_PATH" >> .env

# 4. Screen permissions (X11 Fallback)
xhost +local:root 2>/dev/null

# 5. Execute
docker compose up --build