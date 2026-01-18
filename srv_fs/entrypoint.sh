#!/usr/bin/env bash
set -euo pipefail
echo "Текущий shell: $SHELL"

# Defaults
SAMBA_USER=${SAMBA_USER}
SAMBA_PASSWORD=${SAMBA_PASSWORD}
SAMBA_SHARE_NAME=${SAMBA_SHARE_NAME:-share}
SAMBA_SHARE_PATH=${SAMBA_SHARE_PATH:-/share}
WORKGROUP=${WORKGROUP:-WORKGROUP}

# Default route via firewall (optional)
ip route del default || true
ip route add default via "$GATEWAY_IP" || true


##### CONFIGURING SYSCTL.CONF #####
echo "Начинаем настройку /etc/sysctl.conf ..."

CONFIG_FILE="/etc/sysctl.conf"

SETTINGS=(
    "net.ipv4.conf.default.send_redirects=0"
    "net.ipv4.conf.all.accept_redirects=0"
    "net.ipv4.conf.default.accept_redirects=0"
    "net.ipv4.conf.all.secure_redirects=0"
    "net.ipv4.conf.default.secure_redirects=0"
    "net.ipv4.conf.all.accept_source_route=0"
    "net.ipv4.conf.default.accept_source_route=0"
    "net.ipv4.tcp_syncookies=1"
)

for SETTING in "${SETTINGS[@]}"; do
    KEY="${SETTING%=*}"
    VALUE="${SETTING#*=}"

    # Проверяем, есть ли закомментированная строка с этим ключом
    if grep -q "^[[:space:]]*#[[:space:]]*$KEY[[:space:]]*=" "$CONFIG_FILE"; then
        # Раскомментируем и обновляем значение
        sed -i "s/^[[:space:]]*#[[:space:]]*$KEY[[:space:]]*=.*/$SETTING/" "$CONFIG_FILE"
        echo "Раскомментировано и обновлено: $SETTING"
    # Проверяем, есть ли активная строка с этим ключом
    elif grep -q "^[[:space:]]*$KEY[[:space:]]*=" "$CONFIG_FILE"; then
        # Обновляем существующее значение
        sed -i "s/^[[:space:]]*$KEY[[:space:]]*=.*/$SETTING/" "$CONFIG_FILE"
        echo "Обновлено: $SETTING"
    else
        # Добавляем в конец файла, если параметра нет вообще
        echo "$SETTING" >> "$CONFIG_FILE"
        echo "Добавлено: $SETTING"
    fi
done

# Применяем изменения
if sysctl -p "$CONFIG_FILE" 2>/dev/null; then
    echo "Все настройки /etc/sysctl.conf успешно применены!"
else
    echo "Предупреждение: возникли проблемы при применении настроек через sysctl -p" >&2
fi



##### CONFIGURING PASSWORD POLICY #####

# 1. Создаём /etc/security/pwquality.conf (АРМ пользователей)
cat > /etc/security/pwquality.conf << 'EOF'
minlen = 17		# Минимальная длина пароля — 12 символов
minclass = 4		# Минимум 3 класса символов из 4 возможных
reject_username = 1	# Запрет совпадения с именем пользователя
gecoscheck = 1		# Проверка на слова из GECOS
EOF
echo "[OK] Создан /etc/security/pwquality.conf"

# 2. Настраиваем базовый /etc/login.defs (АРМ пользователей)
# Функция для обновления параметра в /etc/login.defs
update_login_defs() {
    local param="$1"
    local value="$2"

    # Пытаемся заменить существующую строку
    sed -i "s/^${param}.*/${param} ${value}/" /etc/login.defs

    # Проверяем, есть ли теперь строка в файле
    if ! grep -q "^${param}" /etc/login.defs; then
        # Если нет — добавляем в конец файла
        echo "${param} ${value}" >> /etc/login.defs
    fi
}

# Применяем ко всем нужным параметрам
update_login_defs "PASS_MAX_DAYS" "60"
update_login_defs "PASS_MIN_DAYS" "0"
update_login_defs "PASS_MIN_LEN" "17"
update_login_defs "PASS_WARN_AGE" "14"
update_login_defs "LOG_UNKFAIL_ENAB" "yes"
update_login_defs "FAILLOG_ENAB" "yes"
update_login_defs "LOG_OK_LOGINS" "yes"
update_login_defs "ENCRYPT_METHOD" "SHA512"

echo "[OK] Обновлён /etc/login.defs (АРМ пользователей)"


# 3. Настраиваем /etc/pam.d/common-password
CONFIG_FILE="/etc/pam.d/common-password"
NEW_LINE="password        requisite pam_pwhistory.so use_authtok remember=10"

grep -q "pam_unix.so" "$CONFIG_FILE" && \
  sed -i "/pam_unix\.so/i\\$NEW_LINE" "$CONFIG_FILE" || \
  echo "$NEW_LINE" >> "$CONFIG_FILE"
echo "[OK] Настроен /etc/pam.d/common-password"





##### CONFIGURING PAM.D/SU #####
echo "Начинаем настройку /etc/pam.d/su ..."

PAM_FILE="/etc/pam.d/su"
TARGET_LINE="auth[[:space:]]+required[[:space:]]+pam_wheel.so[[:space:]]+use[[:space:]]+uid[[:space:]]+group=admins"
SEARCH_LINE="auth[[:space:]]+required[[:space:]]+pam_wheel.so"

# 1. Проверяем, есть ли уже раскомментированная нужная строка
if grep -qE "^$TARGET_LINE$" "$PAM_FILE"; then
    echo "Строка 'auth required pam_wheel.so use uid group=admins' уже присутствует и активна."
else
    # 2. Ищем закомментированную версию нужной строки
    if grep -qE "^[[:space:]]*#[[:space:]]*$TARGET_LINE$" "$PAM_FILE"; then
        # Раскомментируем её
        sed -i -E "s/^([[:space:]]*)#[[:space:]]*($TARGET_LINE)$/\1\2/" "$PAM_FILE"
        echo "Раскомментирована строка: auth required pam_wheel.so use uid group=admins"
    else
        # 3. Ищем базовую строку без параметров (auth required pam_wheel.so)
        if grep -qE "^[[:space:]]*(#[[:space:]]*)?$SEARCH_LINE$" "$PAM_FILE"; then
            # Обновляем существующую строку: раскомментируем и добавляем параметры
            sed -i -E "s/^([[:space:]]*)(#[[:space:]]*)?($SEARCH_LINE)$/\1\3 use uid group=admins/" "$PAM_FILE"
            echo "Обновлена строка: добавлена 'use uid group=admins'"
        else
            # 4. Если ничего не нашли — добавляем новую строку в конец файла
            echo "auth required pam_wheel.so use uid group=admins" >> "$PAM_FILE"
            echo "Добавлено: auth required pam_wheel.so use uid group=admins"
        fi
    fi
fi
echo "Настройка /etc/pam.d/su завершена"


##### CONFIGURING KESL #####

# Создаём конфиг
cat >/tmp/kesl.ini <<EOF
EULA_AGREED=yes
PRIVACY_POLICY_AGREED=yes
SERVICE_LOCALE=en_US.UTF-8
USE_KSN=yes
USE_GUI=no
INSTALL_LICENSE=
GROUP_CLEAN=no
ScanMemoryLimit=2048
USE_SYSTEMD=yes
EOF

# Устанавливаем на основе конфига
apt-get install /tmp/kesl_12.3.0-1162_amd64.deb
/opt/kaspersky/kesl/bin/kesl-setup.pl --autoinstall=/tmp/kesl.ini &
echo "Установка KESL выполнена"


##### CONFIGURING SAMBA #####

# Create local users
if ! id -u "$SAMBA_USER" >/dev/null 2>&1; then
	useradd -m -s /bin/bash "$SAMBA_USER" || true
fi
echo "$SAMBA_USER:$SAMBA_PASSWORD" | chpasswd
echo '$SAMBA_USER ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/90-$SAMBA_USER
chmod 0440 /etc/sudoers.d/90-$SAMBA_USER

mkdir -p "$SAMBA_SHARE_PATH"
chmod -R 0777 "$SAMBA_SHARE_PATH" || true

# Samba configuration
mkdir -p /var/log/samba
cat >/etc/samba/smb.conf <<EOF
[global]
   workgroup = $WORKGROUP
   server role = standalone server
   map to guest = Bad User
   usershare allow guests = yes
   dns proxy = no
   log file = /var/log/samba/log.%m
   max log size = 50
   load printers = no
   printing = bsd
   disable spoolss = yes

[$SAMBA_SHARE_NAME]
   path = $SAMBA_SHARE_PATH
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0666
   directory mask = 0775
EOF

# Create Samba user (requires system account to exist)
printf '%s\n%s\n' "$SAMBA_PASSWORD" "$SAMBA_PASSWORD" | smbpasswd -s -a "$SAMBA_USER" || true

# Разворачиваем sshd + adm пользователя
chmod +x /usr/local/bin/adm.sh
/usr/local/bin/adm.sh
/usr/sbin/sshd

mkdir -p /var/log/supervisor
cat <<'EOF' >/etc/supervisor/conf.d/samba.conf
[program:nmbd]
command=/usr/sbin/nmbd -F --no-process-group
autorestart=true
stdout_logfile=/var/log/supervisor/nmbd.log
stderr_logfile=/var/log/supervisor/nmbd.log
priority=10

[program:smbd]
command=/usr/sbin/smbd -F --no-process-group
autorestart=true
stdout_logfile=/var/log/supervisor/smbd.log
stderr_logfile=/var/log/supervisor/smbd.log
priority=20
EOF

# Создаём файлы логов, даем права и запускаем rsyslogd
touch /var/log/auth.log /var/log/syslog
chown syslog:adm /var/log/auth.log /var/log/syslog 2>/dev/null || true
chmod 644 /var/log/auth.log /var/log/syslog
echo "Запускаем rsyslogd"
rsyslogd -n -f /etc/rsyslog.conf &

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
