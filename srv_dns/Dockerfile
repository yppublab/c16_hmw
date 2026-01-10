FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC
ENV COREDNS_VERSION=1.14.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    iproute2 \
    sudo \
    nano \
    vim \
    curl \
    wget \
    openssh-server \
    ca-certificates

# Скачиваем и устанавливаем CoreDNS
RUN wget https://github.com/coredns/coredns/releases/download/v${COREDNS_VERSION}/coredns_${COREDNS_VERSION}_linux_amd64.tgz && \
    tar -xzf coredns_${COREDNS_VERSION}_linux_amd64.tgz && \
    mv coredns /usr/local/bin/ && \
    rm coredns_${COREDNS_VERSION}_linux_amd64.tgz && \
    chmod +x /usr/local/bin/coredns

EXPOSE 53 53/udp

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]