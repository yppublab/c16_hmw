#!/usr/bin/env bash

# Adjust default route via firewall
ip route del default || true
ip route add default via "$GATEWAY_IP" || true

set -euo pipefail

# Разворачиваем sshd + adm пользователя
chmod +x /usr/local/bin/adm.sh
/usr/local/bin/adm.sh
/usr/sbin/sshd

if ! id -u ${USERNAME}>/dev/null 2>&1; then
	useradd -m -s /bin/bash -p "${USER_HASH}" ${USERNAME} || true
fi


sleep infinity
