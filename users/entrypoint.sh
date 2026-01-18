#!/usr/bin/env bash
set -euo pipefail

# Adjust default route via firewall
ip route del default || true
ip route add default via "$GATEWAY_IP" || true


##### CONFIGURING PASSWORD POLICY #####

# 1. Создаём /etc/security/pwquality.conf (АРМ пользователей)
cat > /etc/security/pwquality.conf << 'EOF'
minlen = 12		# Минимальная длина пароля — 12 символов
minclass = 3		# Минимум 3 класса символов из 4 возможных
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
update_login_defs "PASS_MAX_DAYS" "90"
update_login_defs "PASS_MIN_DAYS" "0"
update_login_defs "PASS_MIN_LEN" "12"
update_login_defs "PASS_WARN_AGE" "14"
update_login_defs "LOG_UNKFAIL_ENAB" "yes"
update_login_defs "FAILLOG_ENAB" "yes"
update_login_defs "LOG_OK_LOGINS" "yes"
update_login_defs "ENCRYPT_METHOD" "SHA512"

echo "[OK] Обновлён /etc/login.defs (АРМ пользователей)"


# 3. Настраиваем /etc/pam.d/common-password
CONFIG_FILE="/etc/pam.d/common-password"
NEW_LINE="password        requisite pam_pwhistory.so use_authtok remember=5"

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
if [[ "$(hostname)" == "petrov-linux-001" ]]; then
	echo "На petrov-linux-001 KESL не устанавливаем"	
else
	apt-get install /tmp/kesl_12.3.0-1162_amd64.deb
	/opt/kaspersky/kesl/bin/kesl-setup.pl --autoinstall=/tmp/kesl.ini &
	echo "Установка KESL выполнена"
fi




##### CONFIGURING FTP FOR 1 USER PC #####
if [[ "$(hostname)" == "petrov-linux-001" ]]; then
# FTP setup (minimal)
	echo "Starting minimal FTP server..."

	apt-get update && apt-get install -y vsftpd

# Базовая конфигурация vsftpd (анонимный доступ)
cat > /etc/vsftpd.conf << EOF
listen=YES
anonymous_enable=YES
no_anon_password=YES
anon_root=/var/ftp
anon_upload_enable=YES
anon_mkdir_write_enable=YES
write_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
seccomp_sandbox=NO
EOF

# Создаём корневую папку для анонимного FTP
	mkdir -p /var/ftp/upload
	chmod -R 0755 /var/ftp

# Запускаем сервер в фоне
	vsftpd /etc/vsftpd.conf &

	echo "Anonymous FTP server started on port 21"
	echo "Files can be uploaded to /var/ftp/upload"
fi


# Разворачиваем sshd + adm пользователя
chmod +x /usr/local/bin/adm.sh
/usr/local/bin/adm.sh
/usr/sbin/sshd

if ! id -u ${USERNAME}>/dev/null 2>&1; then
	useradd -m -s /bin/bash -p "${USER_HASH}" ${USERNAME} || true
fi


# Добавляем лишние права пользователю petrov и лишнюю учетку test
if [[ "$(hostname)" == "petrov-linux-001" ]]; then
	echo "Включаем ${USERNAME} в группу sudo"
	usermod -a -G sudo ${USERNAME}
	
	echo "Добавляем левую учетку test"
	if ! id -u test>/dev/null 2>&1; then
		useradd -m -s /bin/bash -p "${USER_HASH}" test || true
	fi
fi









# Создаём файлы логов, даем права и запускаем rsyslogd
touch /var/log/auth.log /var/log/syslog
chown syslog:adm /var/log/auth.log /var/log/syslog 2>/dev/null || true
chmod 644 /var/log/auth.log /var/log/syslog
echo "Запускаем rsyslogd"
rsyslogd -n -f /etc/rsyslog.conf &


sleep infinity
