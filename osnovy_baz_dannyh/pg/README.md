# Emarket PostgreSQL demo database

Локальный PostgreSQL 16 с доменной OLTP-моделью интернет-магазина и
детерминированным набором тестовых данных.

## Структура sql скриптов

- `init_sql/01_create_emarket.sql` - создаёт схемы, таблицы, связи,
  ограничения, индексы.
- `init_sql/02_fill_emarket.sql` - заполняет базу воспроизводимыми данными.
  При запуске из Docker используется `scale=1`:
  - 20 000 клиентов
  - 28 000 адресов клиентов
  - 5 000 товарных позиций
  - 500 уценённых товаров
  - 150 000 цен по городам
  - 60 складов
  - 40 000 строк остатков
  - 100 000 заказов
  - около 300 000 строк заказов
  - около 410 000 переходов статусов.

Для ручной перегенерации с другим масштабом:

```bash
docker compose exec -T postgres \
  sh -c 'psql \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    -v scale=2 \
    -f /docker-entrypoint-initdb.d/02_fill_emarket.sql'
```

## Первый запуск

```bash
docker compose up -d
```

Подключение с хоста:

```bash
psql \
  --host localhost \
  --port 5435 \
  --username app \
  --dbname emarket
```

Полное пересоздание базы и повторное наполнение:

```bash
docker compose down -v
docker compose up -d
```

## Доменные схемы

- `general` - география;
- `customer` - клиенты и адреса;
- `catalog` - каталог, свойства и цены;
- `stock` - склады и текущие остатки;
- `sales` - заказы и жизненный цикл.
