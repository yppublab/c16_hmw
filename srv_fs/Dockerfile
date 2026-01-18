FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    samba \
    samba-common \
    samba-vfs-modules \
    supervisor \
    openssh-server \
    sudo \
    iproute2 \
    curl \
    gnupg \
    lsb-release \
    ca-certificates \
    wget \
    acl \
    vim \
    nano \
    rsyslog \
    libpam-modules \
    libpam-pwquality \
 && rm -rf /var/lib/apt/lists/*

RUN wget -P /tmp/ https://products.s.kaspersky-labs.com/endpoints/keslinux10/12.3.0.1162/multilanguage-12.3.0.1162/3939393231377c44454c7c31/kesl_12.3.0-1162_amd64.deb

EXPOSE 22 139 445
EXPOSE 137/udp 138/udp

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/share"]

CMD ["/usr/local/bin/entrypoint.sh"]
