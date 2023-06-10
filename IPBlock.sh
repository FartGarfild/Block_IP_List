#!/bin/bash

# Устанавливаем путь к файлу заблокированных IP-адресов
BLOCKED_IPS_FILE_PATH="/path/to/blocked_ips.txt"

# Устанавливаем белый список IP-адресов - тут указываются ip которые не будут блокироваться скриптом..
WHITELIST=("127.0.0.1" "111.111.111.111")

# Определяем пороговое значение уникальных соединений
THRESHOLD=10

# Создаем файл для хранения заблокированных IP-адресов, если он не существует
touch $BLOCKED_IPS_FILE_PATH

# Используем netstat для подсчета количества уникальных IP-адресов и сортировки по количеству соединений
IP_COUNT=$(netstat -tn | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn)

# Используем цикл для прохода по каждой строке с результатом подсчета IP-адресов
while read -r line; do
  # Получаем количество соединений и IP-адрес из текущей строки
  count=$(echo $line | awk '{print $1}')
  ip=$(echo $line | awk '{print $2}')

  # Проверяем, был ли IP-адрес уже заблокирован ранее
  if grep -q "^$ip$" $BLOCKED_IPS_FILE_PATH; then
    continue
  fi

  # Проверяем, является ли IP-адрес белым списком
  if [[ " ${WHITELIST[@]} " =~ " ${ip} " ]]; then
    continue
  fi

  # Если количество соединений превышает пороговое значение, добавляем правило в iptables для блокировки IP-адреса
  if [[ $count -gt $THRESHOLD ]]; then
    iptables -A INPUT -s $ip -j DROP
    echo "Blocked $ip with $count connections."
    # Добавляем IP-адрес в файл заблокированных IP-адресов
    echo $ip >> $BLOCKED_IPS_FILE_PATH
  fi
done <<< "$IP_COUNT"
