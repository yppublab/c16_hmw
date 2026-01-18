#!/bin/sh
set -eu

# Network route first (before apk fetches)
ip route del default 2>/dev/null || true
ip route add default via "${GATEWAY_IP}" || true


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



# Разворачиваем sshd + adm пользователя
chmod +x /usr/local/bin/adm.sh
/usr/local/bin/adm.sh
/usr/sbin/sshd

# Создаём файлы логов, даем права и запускаем rsyslogd
touch /var/log/auth.log /var/log/syslog
chown syslog:adm /var/log/auth.log /var/log/syslog 2>/dev/null || true
chmod 644 /var/log/auth.log /var/log/syslog
echo "Запускаем rsyslogd"
rsyslogd -n -f /etc/rsyslog.conf &

exec coredns -conf /etc/coredns/Corefile

sleep infinity
