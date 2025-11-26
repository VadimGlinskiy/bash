#!/bin/bash

try_pg_dump() {
    local DB_USER=$1
    local PASSWORD="$2"
    echo "Попытка сдампить дб с помощью пользователя $DB_USER"
    export PGPASSWORD=$PASSWORD
    echo ""
    echo "== Попытка дампа с пользователем: $DB_USER =="
    echo "Хост: $DB_HOST"
    echo "Порт: 6432"
    echo "База: $DB_NAME"
    echo "Файл дампа: $DUMP_FILE"
    echo ""
    if pg_dump "host=${DB_HOST} \
port=6432 \
sslmode=verify-full \
sslrootcert=/home/${USER}/.postgresql/root.crt \
dbname=${DB_NAME} \
user=${DB_USER}" \
--verbose \
--no-owner \
--format=c > "${DUMP_FILE}"; then
        echo "Дамп успешно создан пользователем $DB_USER"
        unset PGPASSWORD
        return 0
    else
        echo "Ошибка при создании дампа с пользователем $DB_USER"
        unset PGPASSWORD
        return 1
    fi
}


echo "=== Проверка наличия pg_dump ==="
if ! command -v pg_dump &> /dev/null; then
    echo "pg_dump не найден, будет проведена установка"
    apt update
    apt install --yes postgresql-client
else
    echo "pg_dump найден, пропуск установки"
fi



DB_HOST_FILE="$HOME/.db_host"
echo "=== Проверка переменной окружения DB_HOST(адрес хоста кластера бд) ==="
if [ -f "$DB_HOST_FILE" ]; then
    DB_HOST=$(<"$DB_HOST_FILE")
    echo "Используется сохранённый хост базы данных: $DB_HOST"
else
   echo "Файл с адресом хоста базы данных не найден. Пожалуйста, введите адрес хоста базы данных."
   read -p "Хост базы данных: " DB_HOST
   echo "$DB_HOST" > "$DB_HOST_FILE"
   export DB_HOST="${DB_HOST}"
   echo "Хост успешно задан для будущих запусков в файле '$DB_HOST_FILE'"
fi
echo "=== Скачивание сертификата ==="

mkdir -p ~/.postgresql

if [ ! -f ~/.postgresql/root.crt ]; then
    wget "https://storage.yandexcloud.net/cloud-certs/CA.pem" \
      --output-document ~/.postgresql/root.crt
    chmod 0655 ~/.postgresql/root.crt
    echo "Сертификат загружен"
else
    echo "Сертификат уже существует, пропуск загрузки"
fi

echo "=== Сбор данных для подключения ==="
read -p "Имя базы данных: " DB_NAME
DUMP_FILE="${DB_NAME}.dump"
USERS=(
    "${DB_NAME}-app"
    "${DB_NAME}-admin"
    "${DB_NAME}-user"
)

for DB_USER in "${USERS[@]}"; do
  read -s -p "Пароль пользователя '$DB_USER' для подключения: " PASSWORD
  echo ""
  if try_pg_dump "$DB_USER" "$PASSWORD"; then
    break
  fi
done

if [ ! -f "$DUMP_FILE" ]; then
    echo "Неудача: не удалось создать дамп базы данных ни с одним из пользователей."
    exit 1
fi

echo "Размер файла: $(du -h "$DUMP_FILE" | cut -f1)"
echo "=== Операция завершена ==="