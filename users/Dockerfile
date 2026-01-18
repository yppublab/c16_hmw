FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC

RUN apt-get update \
 && apt-get install -y \
    openssh-server \
    sudo \
    iproute2 \
    samba-client \
    cifs-utils \
    curl \
    gnupg \
    ca-certificates \
    xz-utils \
    cron \
    zip \
    tcpdump \
    dnsutils \
    iputils-ping\
    vim \
    nano \
    rsyslog \
    libpam-modules \
    libpam-pwquality \
 && rm -rf /var/lib/apt/lists/*

RUN wget -P /tmp/ https://products.s.kaspersky-labs.com/endpoints/keslinux10/12.3.0.1162/multilanguage-12.3.0.1162/3939393231377c44454c7c31/kesl_12.3.0-1162_amd64.deb

# Run entrypoint.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
