#!/bin/bash

# === Файлы конфигурации ===
DB_HOST_FILE="db_host"
S3_BUCKET_FILE="s3_bucket"

# Функция попытки восстановления
try_pg_restore() {
    local DB_USER=$1
    local PASSWORD="$2"
    local FILE_PATH="$3" 
    echo "Попытка восстановить БД с помощью пользователя $DB_USER"
    export PGPASSWORD=$PASSWORD
    echo "== Параметры восстановления =="
    echo "База: $DB_NAME"
    echo "Файл: $FILE_PATH"
    if pg_restore \
        --host="${DB_HOST}" \
        --port=6432 \
        --username="${DB_USER}" \
        --dbname="${DB_NAME}" \
        --verbose \
        --clean \
        --if-exists \
        --no-owner \
        --no-acl \
        --no-comments \
        --jobs=4 \
        "${FILE_PATH}"; then
            
        echo "Восстановление успешно выполнено пользователем $DB_USER"
        unset PGPASSWORD
        return 0
    else
        echo "Ошибка при восстановлении с пользователем $DB_USER"
        unset PGPASSWORD
        return 1
    fi
}

echo "=== Проверка зависимостей ==="
NEED_INSTALL=false

if ! command -v pg_restore &> /dev/null; then
    echo "pg_restore не найден."
    NEED_INSTALL=true
fi

if ! command -v aws &> /dev/null; then
    echo "aws-cli не найден (нужен для S3)."
    NEED_INSTALL=true
fi

if [ "$NEED_INSTALL" = true ]; then
    echo "Устанавливаем недостающие пакеты..."
    apt update
    apt install --yes postgresql-client awscli
else
    echo "Все утилиты найдены."
fi

# === Настройка Хоста БД (сохраняется в db_host) ===
echo "=== Проверка DB_HOST (адрес хоста кластера бд) ==="
if [ -f "$DB_HOST_FILE" ]; then
    DB_HOST=$(<"$DB_HOST_FILE")
    echo "Используется сохранённый хост БД: $DB_HOST"
else
   echo "Файл с адресом хоста базы данных не найден."
   read -p "Хост базы данных: " DB_HOST
   echo "$DB_HOST" > "$DB_HOST_FILE"
   export DB_HOST="${DB_HOST}"
   echo "Хост успешно задан для будущих запусков в файле '$DB_HOST_FILE'"
fi

# === Сертификат Yandex ===
mkdir -p ~/.postgresql
if [ ! -f ~/.postgresql/root.crt ]; then
    echo "Скачивание сертификата Yandex..."
    wget "https://storage.yandexcloud.net/cloud-certs/CA.pem" \
      --output-document ~/.postgresql/root.crt
    chmod 0655 ~/.postgresql/root.crt
fi


# === ВЫБОР ИСТОЧНИКА ДАМПА ===
echo ""
echo "=== Выбор источника дампа ==="
echo "1) Локальный файл"
echo "2) Скачать из S3 (Yandex Object Storage / AWS)"
read -p "Выберите вариант (1 или 2): " SOURCE_OPTION

DUMP_FILE=""
IS_TEMP_FILE=false

if [ "$SOURCE_OPTION" == "2" ]; then
    # --- Логика для S3 ---
    echo "=== Настройка подключения к S3 ==="
    
    # Чтение сохраненного имени бакета или запрос ввода (сохраняется в s3_bucket)
    if [ -f "$S3_BUCKET_FILE" ]; then
        S3_BUCKET=$(<"$S3_BUCKET_FILE")
        echo "Используется сохраненный бакет: $S3_BUCKET"
    else
        read -p "Имя бакета (Bucket Name): " S3_BUCKET
        echo "$S3_BUCKET" > "$S3_BUCKET_FILE"
        echo "Имя бакета сохранено в файле '$S3_BUCKET_FILE'."
    fi

    # Запрос пути к файлу
    read -p "Путь к файлу в бакете (например, backups/loyalty-core-dev-db.dump): " S3_KEY
    
    # Настройка окружения для Yandex Cloud
    export AWS_DEFAULT_REGION="ru-central1"
    
    DUMP_FILE=$(basename "$S3_KEY")
    IS_TEMP_FILE=true
    
    echo "Скачивание s3://$S3_BUCKET/$S3_KEY в $DUMP_FILE (используя ~/.aws/credentials)..."
    if aws s3 cp "s3://${S3_BUCKET}/${S3_KEY}" "$DUMP_FILE" --endpoint-url=https://storage.yandexcloud.net; then
        echo "Файл успешно скачан."
    else
        echo "Ошибка скачивания файла из S3. Проверьте ваш файл ~/.aws/credentials и права доступа."
        rm -f "$DUMP_FILE"
        exit 1
    fi

else
    # --- Логика для локального файла ---
    read -e -p "Введите путь к локальному файлу дампа: " DUMP_FILE
    if [ ! -f "$DUMP_FILE" ]; then
        echo "Файл не найден!"
        exit 1
    fi
fi

# === НОВАЯ ЛОГИКА ОПРЕДЕЛЕНИЯ ИМЕНИ БД ===
echo "=== Сбор данных для восстановления ==="

# Извлечение базового имени файла (без пути и расширения)
# 1. Берем basename (удаляем путь)
# 2. Удаляем расширение (.dump)
BASE_DUMP_NAME=$(basename "$DUMP_FILE")
DEFAULT_DB_NAME="${BASE_DUMP_NAME%.dump}"

if [ -z "$DEFAULT_DB_NAME" ] || [ "$DEFAULT_DB_NAME" == "$BASE_DUMP_NAME" ]; then
    # Если имя не удалось определить или файл не имеет расширения .dump,
    # предлагаем просто имя файла как базу.
    DEFAULT_DB_NAME="$BASE_DUMP_NAME"
    echo "Не удалось автоматически определить имя БД из имени файла."
else
    echo "Предлагаемое имя базы данных (из имени файла) (нажать Enter если совпадает): $DEFAULT_DB_NAME"
fi

# Запрос имени базы данных с предложенным значением
read -e -p "Имя базы данных (куда заливать): " DB_NAME
# Если пользователь нажал Enter без ввода, используем предложенное имя
DB_NAME=${DB_NAME:-$DEFAULT_DB_NAME}
echo "Будет использована БД: $DB_NAME"


# === Восстановление ===
USERS=(
    "${DB_NAME}-app"
    "${DB_NAME}-admin"
    "${DB_NAME}-user"
)

SUCCESS=false
for DB_USER in "${USERS[@]}"; do
  read -s -p "Пароль пользователя '$DB_USER': " PASSWORD
  echo ""
  if try_pg_restore "$DB_USER" "$PASSWORD" "$DUMP_FILE"; then
    SUCCESS=true
    break
  fi
done

# === Очистка: Удаление временного файла дампа, если он был скачан из S3 ===
if [ "$IS_TEMP_FILE" = true ] && [ -f "$DUMP_FILE" ]; then
    echo "Удаление файла дампа..."
    rm "$DUMP_FILE"
fi

if [ "$SUCCESS" != true ]; then
    echo "Неудача: не удалось восстановить базу."
    exit 1
fi

echo "=== Операция завершена ==="