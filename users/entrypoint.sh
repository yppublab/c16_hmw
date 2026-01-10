#!/usr/bin/env bash

# Adjust default route via firewall
ip route del default || true
ip route add default via "$GATEWAY_IP" || true

set -euo pipefail

# Разворачиваем sshd + adm пользователя
chmod +x /usr/local/bin/adm.sh
/usr/local/bin/adm.sh
/usr/sbin/sshd

useradd -m -s /bin/bash -p "${USER_HASH}" ${USERNAME} || true

sleep infinity
