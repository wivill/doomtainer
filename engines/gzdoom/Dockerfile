FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Añadimos libwayland-dev, wayland-protocols y libxkbcommon-dev para soporte nativo
RUN apt-get update && apt-get install -y \
    git cmake make g++ \
    libsdl2-dev libgtk-3-dev libvpx-dev \
    zlib1g-dev libbz2-dev libjpeg-dev \
    libfluidsynth-dev libgme-dev libopenal-dev \
    libmpg123-dev libsndfile1-dev libwildmidi-dev \
    nasm tar wget \
    libwayland-dev wayland-protocols libxkbcommon-dev \
    libwebp-dev \
    && rm -rf /var/lib/apt/lists/*

# (El resto de la compilación de ZMusic y GZDoom se mantiene igual...)
WORKDIR /tmp/zmusic
RUN git clone https://github.com/coelckers/ZMusic.git . && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && make install

WORKDIR /tmp/gzdoom
RUN git clone https://github.com/coelckers/gzdoom.git . && \
    git checkout g4.11.3 && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DINCLUDE_INSTALL_DIR=/usr/include && \
    make -j$(nproc) && make install

WORKDIR /root
RUN rm -rf /tmp/gzdoom /tmp/zmusic

WORKDIR /games
ENTRYPOINT ["gzdoom"]