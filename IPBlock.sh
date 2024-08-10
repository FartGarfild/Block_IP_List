#!/bin/bash

# Проверка наличия iptables
if ! command -v iptables &> /dev/null; then
    echo "iptables could not be found"
    exit 1
fi

# Устанавливаем путь к файлу заблокированных IP-адресов
BLOCKED_IPS_FILE_PATH="/path/to/blocked_ips.txt"

# Устанавливаем белый список IP-адресов
WHITELIST=("127.0.0.1" "111.111.111.111")

# Определяем пороговое значение уникальных соединений
THRESHOLD=10

# Устанавливаем время блокировки в секундах (например, 1 час)
BLOCK_TIME=3600

# Создаем файл для хранения заблокированных IP-адресов, если он не существует
touch $BLOCKED_IPS_FILE_PATH

# Функция для разблокировки IP
unblock_ip() {
    local ip=$1
    iptables -D INPUT -s $ip -j DROP
    sed -i "/^$ip:/d" $BLOCKED_IPS_FILE_PATH
    logger "Unblocked $ip"
    echo "Unblocked $ip"
}

# Проверяем и разблокируем IP-адреса, у которых истекло время блокировки
while IFS=: read -r ip block_time; do
    current_time=$(date +%s)
    if (( current_time > block_time )); then
        unblock_ip $ip
    fi
done < $BLOCKED_IPS_FILE_PATH

# Используем netstat для подсчета количества уникальных IP-адресов и сортировки по количеству соединений
IP_COUNT=$(netstat -tn | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn)

# Используем цикл для прохода по каждой строке с результатом подсчета IP-адресов
while read -r line; do
    # Получаем количество соединений и IP-адрес из текущей строки
    count=$(echo $line | awk '{print $1}')
    ip=$(echo $line | awk '{print $2}')

    # Проверяем, был ли IP-адрес уже заблокирован ранее
    if grep -q "^$ip:" $BLOCKED_IPS_FILE_PATH; then
        continue
    fi

    # Проверяем, является ли IP-адрес белым списком
    if [[ " ${WHITELIST[@]} " =~ " ${ip} " ]]; then
        continue
    fi

    # Если количество соединений превышает пороговое значение, добавляем правило в iptables для блокировки IP-адреса
    if [[ $count -gt $THRESHOLD ]]; then
        # Добавляем временную блокировку
        iptables -A INPUT -s $ip -j DROP

        # Вычисляем время разблокировки
        unblock_time=$(($(date +%s) + BLOCK_TIME))

        # Логируем блокировку
        echo "$ip:$unblock_time" >> $BLOCKED_IPS_FILE_PATH
        logger "Blocked $ip with $count connections. Will be unblocked at $(date -d @$unblock_time)"
        echo "Blocked $ip with $count connections. Will be unblocked at $(date -d @$unblock_time)"

        # Устанавливаем таймер на разблокировку
        (
            sleep $BLOCK_TIME
            unblock_ip $ip
        ) &
    fi
done <<< "$IP_COUNT"
