#!/bin/bash

# 1. Obtener IDs de usuario
USER_UID=$(id -u)
USER_GID=$(id -g)

# 2. Localizar la Cookie de PulseAudio/Pipewire
# Generalmente está en ~/.config/pulse/cookie, pero a veces varía.
if [ -f "$HOME/.config/pulse/cookie" ]; then
    PULSE_COOKIE_PATH="$HOME/.config/pulse/cookie"
elif [ -f "$HOME/.pulse-cookie" ]; then
    PULSE_COOKIE_PATH="$HOME/.pulse-cookie"
else
    # Si no existe, generamos una dummy para que docker no falle al montar, 
    # aunque el audio podría no ir sin ella si la seguridad es estricta.
    echo "Advertencia: No se encontró cookie de audio."
    touch /tmp/dummy_pulse_cookie
    PULSE_COOKIE_PATH="/tmp/dummy_pulse_cookie"
fi

# 3. Crear archivo .env dinámico
echo "UID=$USER_UID" > .env
echo "GID=$USER_GID" >> .env
echo "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" >> .env
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY" >> .env
echo "DISPLAY=$DISPLAY" >> .env
echo "PULSE_COOKIE_HOST=$PULSE_COOKIE_PATH" >> .env

# 4. Permisos de pantalla (Fallback X11)
xhost +local:root 2>/dev/null

# 5. Ejecutar
docker compose up --build