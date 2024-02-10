FROM golang:1.21 AS charles-go-build-stage

ENV DEBIAN_FRONTEND=noninteractive

ARG GITLAB_TOKEN_NAME
ARG GITLAB_TOKEN
ARG CHARLES_GO_ENV_FILE

RUN --mount=type=cache,target=/var/lib/apt,sharing=locked \
        --mount=type=cache,target=/var/cache/apt,sharing=locked \
        apt update && \
        apt install -y --no-install-recommends --no-install-suggests \
        git \
        ca-certificates

RUN git clone https://$GITLAB_TOKEN_NAME:$GITLAB_TOKEN@gitlab.com/gabriel-technologia/iot/charlesgo.git --branch v0.0.1 --depth 1
WORKDIR charlesgo
#COPY .env.charles_go.stag .env
COPY $CHARLES_GO_ENV_FILE .env

RUN --mount=type=cache,target=/root/.cache/go-build \
        --mount=type=cache,target=/go/pkg/mod \
        ./build.sh

FROM ubuntu:20.04 AS build-stage

ENV DEBIAN_FRONTEND=noninteractive

# Configure timezone 
ENV TZ=America/Sao_Paulo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install build dependencies
RUN --mount=type=cache,target=/var/lib/apt,sharing=locked \
        --mount=type=cache,target=/var/cache/apt,sharing=locked \
        apt update && \
        apt install -y --no-install-recommends --no-install-suggests \
        ca-certificates \
        git \
        gawk \
        make \
        build-essential \
        clang \
        flex \
        bison \
        g++ \
        gcc-multilib \
        g++-multilib \
        gettext \
        libncurses-dev \
        libssl-dev \
        python3-distutils \
        rsync \
        unzip \
        zlib1g-dev \
        file \
        wget \
        time \
        locales

# Configure build env
RUN locale-gen en_US.UTF-8

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Add user 'cause using root is not allowed during build
RUN groupadd -g 1001 gabriel && useradd -g 1001 -m -s /bin/bash -u 1001 gabriel
USER gabriel

# Clone OpenWRT
WORKDIR /home/gabriel/openwrt
RUN git clone https://git.openwrt.org/openwrt/openwrt.git --branch v22.03.6 --depth 1 .

# Copy Gabriel files to final destination on OpenWRT build
COPY --chown=gabriel:gabriel mt7628an_hilink_hlk-7628n.dts ./target/linux/ramips/dts/mt7628an_hilink_hlk-7628n.dts

# Update and install OpenWRT packages
RUN ./scripts/feeds update -a
RUN ./scripts/feeds install libpam liblzma libnetsnmp && \
        ./scripts/feeds install -a

# Expand .config file
COPY --chown=gabriel:gabriel diffconfig .config
RUN make defconfig

# Download all dependecies
RUN make -j $(($(nproc)+1)) download
# Build
RUN time make -j $(($(nproc)+1)) V=s

# Image to build ChalinhOS
FROM ubuntu:20.04 AS export-stage

ENV DEBIAN_FRONTEND=noninteractive

ENV TZ=America/Sao_Paulo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN --mount=type=cache,target=/var/lib/apt,sharing=locked \
        --mount=type=cache,target=/var/cache/apt,sharing=locked \
        apt update && \
        apt install -y --no-install-recommends --no-install-suggests \
        build-essential \
        libncurses-dev \
        zlib1g-dev \
        gawk \
        git \
        gettext \
        libssl-dev \
        xsltproc \
        rsync \
        wget \
        unzip \
        file \
        python3

# image builder
COPY --from=build-stage /home/gabriel/openwrt/bin/targets/ramips/mt76x8/*imagebuilder*.tar.xz .
ENTRYPOINT []
