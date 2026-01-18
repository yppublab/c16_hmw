#!/usr/bin/env bash
set -eu

# Network route first (before apk fetches)
ip route del default 2>/dev/null || true
ip route add default via "${GATEWAY_IP}" || true


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




# Minimal nginx site
rm -f /etc/nginx/http.d/default.conf 2>/dev/null || true

# Разворачиваем sshd + adm пользователя
chmod +x /usr/local/bin/adm.sh
/usr/local/bin/adm.sh
/usr/sbin/sshd



# Добавляем лишнюю учетку test
echo "Добавляем левую учетку test"
if ! id -u test>/dev/null 2>&1; then
	useradd -m -s /bin/bash -p "${ADM_HASH}" test || true
fi


# Start services
nginx -g 'daemon off;' &
# nginx -s reload

sleep infinity
