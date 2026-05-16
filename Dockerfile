# retropangui-c5 Dockerfile
# Buildroot 빌드 환경 컨테이너

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Buildroot 빌드에 필요한 패키지 설치
RUN apt-get update && apt-get install -y \
    build-essential git libncurses-dev bison flex \
    libssl-dev bc u-boot-tools device-tree-compiler \
    wget ca-certificates cpio rsync unzip file python3 python3-pip python3-dev \
    mtools dosfstools parted fdisk \
    qemu-user-static debootstrap \
    libarchive-zip-perl xxd \
    pkg-config libfl-dev libacl1-dev libarchive-dev \
    locales \
    default-jre-headless && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8

# 비root 유저 생성 (Buildroot 요구사항)
RUN useradd -m -u 1000 -s /bin/bash builder
USER builder
WORKDIR /home/builder

# 볼륨 마운트 포인트
VOLUME ["/home/builder/buildroot", "/home/builder/dl", "/home/builder/output"]

# 기본 실행 명령
CMD ["bash"]
