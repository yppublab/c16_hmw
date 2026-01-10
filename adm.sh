#!/bin/bash
echo 'running adm.sh'

#Задаём пароль root
#echo "root:${ROOT_PWD}"
echo "root:${ROOT_PWD}" | chpasswd

# Далее скрипт выполняет первичную конфиуграцию SSHD и создает пользователя для администрирования
set -euo pipefail

# SSH setup (avoid noisy errors if config dir missing)
mkdir -p /etc/ssh /run/sshd
if [ ! -f /etc/ssh/sshd_config ]; then
	cat >/etc/ssh/sshd_config <<'EOF'
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PasswordAuthentication yes
PermitRootLogin no
UsePAM yes
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
fi
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
if [[ "$(hostname)" == "ivanov-linux-003" ]]; then
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config || true
else
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config || true
fi
ssh-keygen -A >/dev/null 2>&1 || true

echo 'adding adm user'
# Add adm user
if ! id -u adm_ivanov>/dev/null 2>&1; then
	groupadd admins
	useradd -m -s /bin/bash -p "${ADM_HASH}" adm_ivanov || true
	usermod -a -G admins adm_ivanov
fi
#echo "${ADM_HASH}"

echo '%admins ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/91-admins
chmod 0440 /etc/sudoers.d/91-admins

mkdir -p /run/sshd
chmod 755 /run/sshd
