-- This script is independent of updated_at triggers.
-- Historical/generated rows populate created_at and updated_at explicitly.
-- Small dictionaries are normalized to a fixed timestamp to keep the dataset
-- reproducible across repeated runs with the same scale.

\set ON_ERROR_STOP on

\if :{?scale}
\else
    \set scale 1
\endif

\echo '== Filling emarket with deterministic synthetic data; scale=' :scale '=='

SELECT (:scale::integer >= 1) AS scale_is_valid
\gset

\if :scale_is_valid
\else
    \echo 'ERROR: scale must be an integer greater than or equal to 1.'
    \quit
\endif

SET client_min_messages TO warning;
SET synchronous_commit TO off;
SET work_mem TO '128MB';
SET maintenance_work_mem TO '256MB';

BEGIN;

TRUNCATE TABLE
    sales.tb_order_status_history,
    sales.tb_order_items,
    sales.tb_order_delivery_addresses,
    sales.tb_orders,
    sales.tb_delivery_types,
    sales.tb_payment_types,
    stock.tb_product_stocks,
    stock.tb_warehouses,
    catalog.tb_product_prices,
    catalog.tb_product_property_values,
    catalog.tb_products,
    catalog.tb_properties,
    catalog.tb_property_value_types,
    catalog.tb_measures,
    catalog.tb_categories,
    customer.tb_customer_addresses,
    customer.tb_customers,
    general.tb_cities
RESTART IDENTITY CASCADE;

CREATE OR REPLACE FUNCTION pg_temp.det_int
(
    p_value bigint,
    p_modulus integer
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
AS
$$
    SELECT (
        (
            (p_value * 1103515245::bigint + 12345::bigint) % p_modulus
            + p_modulus
        ) % p_modulus
    )::integer;
$$;

\echo '-- Dictionaries and category tree'

INSERT INTO general.tb_cities
(
    city_code,
    city_name,
    region_name,
    timezone
)
VALUES
    ('moscow',          'Москва',               'Москва',                    'Europe/Moscow'),
    ('saint-petersburg','Санкт-Петербург',      'Санкт-Петербург',           'Europe/Moscow'),
    ('novosibirsk',     'Новосибирск',          'Новосибирская область',      'Asia/Novosibirsk'),
    ('yekaterinburg',   'Екатеринбург',         'Свердловская область',       'Asia/Yekaterinburg'),
    ('kazan',           'Казань',               'Республика Татарстан',       'Europe/Moscow'),
    ('nizhny-novgorod', 'Нижний Новгород',      'Нижегородская область',      'Europe/Moscow'),
    ('chelyabinsk',     'Челябинск',            'Челябинская область',        'Asia/Yekaterinburg'),
    ('samara',          'Самара',               'Самарская область',          'Europe/Samara'),
    ('omsk',            'Омск',                 'Омская область',             'Asia/Omsk'),
    ('rostov-on-don',   'Ростов-на-Дону',       'Ростовская область',         'Europe/Moscow'),
    ('ufa',             'Уфа',                  'Республика Башкортостан',     'Asia/Yekaterinburg'),
    ('krasnoyarsk',     'Красноярск',           'Красноярский край',          'Asia/Krasnoyarsk'),
    ('perm',            'Пермь',                'Пермский край',              'Asia/Yekaterinburg'),
    ('voronezh',        'Воронеж',              'Воронежская область',        'Europe/Moscow'),
    ('volgograd',       'Волгоград',            'Волгоградская область',      'Europe/Volgograd'),
    ('krasnodar',       'Краснодар',            'Краснодарский край',         'Europe/Moscow'),
    ('saratov',         'Саратов',              'Саратовская область',        'Europe/Saratov'),
    ('tyumen',          'Тюмень',               'Тюменская область',          'Asia/Yekaterinburg'),
    ('tolyatti',        'Тольятти',             'Самарская область',          'Europe/Samara'),
    ('izhevsk',         'Ижевск',               'Удмуртская Республика',      'Europe/Samara'),
    ('barnaul',         'Барнаул',              'Алтайский край',             'Asia/Barnaul'),
    ('ulyanovsk',       'Ульяновск',            'Ульяновская область',        'Europe/Ulyanovsk'),
    ('irkutsk',         'Иркутск',              'Иркутская область',          'Asia/Irkutsk'),
    ('khabarovsk',      'Хабаровск',            'Хабаровский край',           'Asia/Vladivostok'),
    ('yaroslavl',       'Ярославль',            'Ярославская область',        'Europe/Moscow'),
    ('vladivostok',     'Владивосток',          'Приморский край',            'Asia/Vladivostok'),
    ('makhachkala',     'Махачкала',            'Республика Дагестан',        'Europe/Moscow'),
    ('tomsk',           'Томск',                'Томская область',            'Asia/Tomsk'),
    ('orenburg',        'Оренбург',             'Оренбургская область',       'Asia/Yekaterinburg'),
    ('kemerovo',        'Кемерово',             'Кемеровская область',        'Asia/Novokuznetsk');

INSERT INTO catalog.tb_property_value_types
(
    property_value_type_name,
    description
)
VALUES
    ('text',    'Arbitrary text value.'),
    ('number',  'Number stored physically as text with a dot as decimal separator.'),
    ('boolean', 'Boolean stored physically as true or false.'),
    ('date',    'Date stored physically in ISO format YYYY-MM-DD.');

INSERT INTO catalog.tb_measures
(
    measure_name,
    symbol,
    description
)
VALUES
    ('килограмм', 'кг',   'Mass in kilograms.'),
    ('месяц',     'мес.', 'Duration in months.'),
    ('дюйм',      '"',    'Screen diagonal in inches.'),
    ('гигабайт',  'ГБ',   'Digital storage capacity.'),
    ('литр',      'л',    'Volume in litres.'),
    ('ватт',      'Вт',   'Electrical power.');

INSERT INTO catalog.tb_categories
(
    parent_category_id,
    category_name,
    sort_order
)
VALUES
    (NULL, 'Электроника',        1),
    (NULL, 'Бытовая техника',    2),
    (NULL, 'Дом и сад',          3),
    (NULL, 'Красота и здоровье', 4),
    (NULL, 'Продукты питания',   5),
    (1, 'Смартфоны',          10000),
    (1, 'Ноутбуки',           10001),
    (1, 'Телевизоры',         10002),
    (1, 'Наушники',           10003),
    (2, 'Холодильники',       20000),
    (2, 'Стиральные машины',  20001),
    (2, 'Пылесосы',           20002),
    (3, 'Инструменты',        30000),
    (3, 'Освещение',          30001),
    (3, 'Мебель',             30002),
    (4, 'Косметика',          40000),
    (4, 'Парфюмерия',         40001),
    (4, 'Уход за собой',      40002),
    (5, 'Бакалея',            50000),
    (5, 'Напитки',            50001);

INSERT INTO catalog.tb_properties
(
    property_name,
    description,
    property_value_type_id,
    measure_id,
    sort_order
)
VALUES
    ('Вес',              'Вес одной продаваемой позиции.',                   2, 1,  10),
    ('Цвет',             'Основной цвет товара.',                            1, NULL, 20),
    ('Гарантия',         'Гарантийный срок производителя.',                  2, 2,  30),
    ('Хрупкий товар',    'Требуется осторожное обращение при транспортировке.',3,NULL, 40),
    ('Дата выпуска',     'Дата выпуска модели или партии.',                  4, NULL, 50),
    ('Причина уценки',   'Причина, по которой товар продаётся как уценённый.',1,NULL, 60),
    ('Диагональ экрана', 'Диагональ экрана устройства.',                     2, 3,  70),
    ('Объём памяти',     'Объём встроенной памяти.',                         2, 4,  80);

INSERT INTO sales.tb_payment_types
(
    payment_type_name,
    description
)
VALUES
    ('Онлайн-оплата',           'Оплата банковской картой на сайте.'),
    ('Картой при получении',    'Оплата банковской картой при получении.'),
    ('Наличными при получении', 'Оплата наличными при получении.');

INSERT INTO sales.tb_delivery_types
(
    delivery_type_name,
    description
)
VALUES
    ('Курьерская доставка', 'Доставка заказа по указанному адресу.'),
    ('Самовывоз',            'Получение заказа покупателем на складе или в пункте выдачи.');


\echo '-- Fixing deterministic timestamps for small dictionaries'

UPDATE general.tb_cities
SET
    created_at = TIMESTAMPTZ '2024-01-01 00:00:00+00',
    updated_at = TIMESTAMPTZ '2024-01-01 00:00:00+00';

UPDATE catalog.tb_measures
SET
    created_at = TIMESTAMPTZ '2024-01-01 00:00:00+00',
    updated_at = TIMESTAMPTZ '2024-01-01 00:00:00+00';

UPDATE catalog.tb_categories
SET
    created_at = TIMESTAMPTZ '2024-01-01 00:00:00+00',
    updated_at = TIMESTAMPTZ '2024-01-01 00:00:00+00';

UPDATE catalog.tb_properties
SET
    created_at = TIMESTAMPTZ '2024-01-01 00:00:00+00',
    updated_at = TIMESTAMPTZ '2024-01-01 00:00:00+00';

UPDATE sales.tb_payment_types
SET
    created_at = TIMESTAMPTZ '2024-01-01 00:00:00+00',
    updated_at = TIMESTAMPTZ '2024-01-01 00:00:00+00';

UPDATE sales.tb_delivery_types
SET
    created_at = TIMESTAMPTZ '2024-01-01 00:00:00+00',
    updated_at = TIMESTAMPTZ '2024-01-01 00:00:00+00';

\echo '-- Products'

WITH source_rows AS
(
    SELECT
        generated_number,
        6 + pg_temp.det_int(generated_number * 17, 15) AS category_id,
        (ARRAY[
            'Aster', 'Boreal', 'Cobalt', 'Delta', 'Element',
            'Fenix', 'Gravity', 'Helios', 'Impulse', 'Jupiter'
        ])[1 + pg_temp.det_int(generated_number * 23, 10)] AS brand_name
    FROM generate_series(1, 4500 * :scale) AS generated(generated_number)
)
INSERT INTO catalog.tb_products
(
    category_id,
    product_code,
    internal_barcode,
    title,
    brand_name,
    units_per_package,
    is_markdown,
    vat_rate,
    is_active,
    created_at,
    updated_at
)
SELECT
    source_rows.category_id,
    'PRD-' || lpad(source_rows.generated_number::text, 8, '0'),
    (2000000000000::bigint + source_rows.generated_number)::text,
    category.category_name || ' ' || source_rows.brand_name || ' ' ||
        lpad(source_rows.generated_number::text, 5, '0'),
    source_rows.brand_name,
    (ARRAY[1, 1, 1, 2, 4, 6, 12])[1 + pg_temp.det_int(source_rows.generated_number * 31, 7)],
    false,
    (ARRAY[0::numeric, 10::numeric, 22::numeric])[
        1 + pg_temp.det_int(source_rows.generated_number * 37, 3)
    ],
    true,
    TIMESTAMPTZ '2023-01-01 00:00:00+00'
        + make_interval(days => pg_temp.det_int(source_rows.generated_number * 41, 900)),
    TIMESTAMPTZ '2023-01-01 00:00:00+00'
        + make_interval(days => pg_temp.det_int(source_rows.generated_number * 41, 900))
FROM source_rows
JOIN catalog.tb_categories AS category
    ON category.category_id = source_rows.category_id;

WITH settings AS
(
    SELECT 4500 * :scale AS base_product_count
),
markdown_rows AS
(
    SELECT
        generated_number,
        1 + pg_temp.det_int(generated_number * 43, settings.base_product_count)
            AS source_product_id
    FROM settings
    CROSS JOIN generate_series(1, 500 * :scale) AS generated(generated_number)
)
INSERT INTO catalog.tb_products
(
    source_product_id,
    category_id,
    product_code,
    internal_barcode,
    title,
    brand_name,
    units_per_package,
    is_markdown,
    vat_rate,
    is_active,
    created_at,
    updated_at
)
SELECT
    source_product.product_id,
    source_product.category_id,
    'MD-' || lpad(markdown_rows.generated_number::text, 8, '0'),
    (2900000000000::bigint + markdown_rows.generated_number)::text,
    source_product.title || ' — уценка',
    source_product.brand_name,
    source_product.units_per_package,
    true,
    source_product.vat_rate,
    true,
    source_product.created_at + interval '30 days',
    source_product.created_at + interval '30 days'
FROM markdown_rows
JOIN catalog.tb_products AS source_product
    ON source_product.product_id = markdown_rows.source_product_id;

\echo '-- Product properties'

INSERT INTO catalog.tb_product_property_values
(
    product_id,
    property_id,
    value_text,
    created_at,
    updated_at
)
SELECT
    product.product_id,
    1,
    round(
        0.10::numeric
        + pg_temp.det_int(product.product_id * 47, 5000)::numeric / 100,
        2
    )::text,
    product.created_at,
    product.updated_at
FROM catalog.tb_products AS product;

INSERT INTO catalog.tb_product_property_values
(
    product_id,
    property_id,
    value_text,
    created_at,
    updated_at
)
SELECT
    product.product_id,
    2,
    (ARRAY[
        'чёрный', 'белый', 'серебристый', 'синий',
        'красный', 'зелёный', 'серый', 'бежевый'
    ])[1 + pg_temp.det_int(product.product_id * 53, 8)],
    product.created_at,
    product.updated_at
FROM catalog.tb_products AS product
WHERE product.product_id % 4 <> 0;

INSERT INTO catalog.tb_product_property_values
(
    product_id,
    property_id,
    value_text,
    created_at,
    updated_at
)
SELECT
    product.product_id,
    3,
    (ARRAY['6', '12', '18', '24', '36'])[
        1 + pg_temp.det_int(product.product_id * 59, 5)
    ],
    product.created_at,
    product.updated_at
FROM catalog.tb_products AS product
WHERE product.category_id BETWEEN 6 AND 12;

INSERT INTO catalog.tb_product_property_values
(
    product_id,
    property_id,
    value_text,
    created_at,
    updated_at
)
SELECT
    product.product_id,
    4,
    CASE
        WHEN product.category_id IN (8, 10, 11, 12, 14, 17)
            THEN 'true'
        ELSE 'false'
    END,
    product.created_at,
    product.updated_at
FROM catalog.tb_products AS product
WHERE product.product_id % 3 = 0;

INSERT INTO catalog.tb_product_property_values
(
    product_id,
    property_id,
    value_text,
    created_at,
    updated_at
)
SELECT
    product.product_id,
    5,
    (
        DATE '2018-01-01'
        + pg_temp.det_int(product.product_id * 61, 2920)
    )::text,
    product.created_at,
    product.updated_at
FROM catalog.tb_products AS product;

INSERT INTO catalog.tb_product_property_values
(
    product_id,
    property_id,
    value_text,
    created_at,
    updated_at
)
SELECT
    product.product_id,
    6,
    (ARRAY[
        'повреждена упаковка',
        'витринный образец',
        'незначительные следы эксплуатации',
        'неполная комплектация',
        'косметический дефект'
    ])[1 + pg_temp.det_int(product.product_id * 67, 5)],
    product.created_at,
    product.updated_at
FROM catalog.tb_products AS product
WHERE product.is_markdown;

INSERT INTO catalog.tb_product_property_values
(
    product_id,
    property_id,
    value_text,
    created_at,
    updated_at
)
SELECT
    product.product_id,
    7,
    (ARRAY['5.5', '6.1', '6.7', '13.3', '15.6', '43', '55', '65'])[
        1 + pg_temp.det_int(product.product_id * 71, 8)
    ],
    product.created_at,
    product.updated_at
FROM catalog.tb_products AS product
WHERE product.category_id IN (6, 7, 8);

INSERT INTO catalog.tb_product_property_values
(
    product_id,
    property_id,
    value_text,
    created_at,
    updated_at
)
SELECT
    product.product_id,
    8,
    (ARRAY['64', '128', '256', '512', '1024'])[
        1 + pg_temp.det_int(product.product_id * 73, 5)
    ],
    product.created_at,
    product.updated_at
FROM catalog.tb_products AS product
WHERE product.category_id IN (6, 7);

\echo '-- Customers and customer addresses'

WITH generated_customers AS
(
    SELECT
        generated_number,
        CASE
            WHEN generated_number % 2 = 0
                THEN (ARRAY[
                    'Иван', 'Алексей', 'Сергей', 'Дмитрий', 'Андрей',
                    'Михаил', 'Максим', 'Николай', 'Павел', 'Роман'
                ])[1 + pg_temp.det_int(generated_number * 79, 10)]
            ELSE (ARRAY[
                    'Анна', 'Мария', 'Елена', 'Ольга', 'Наталья',
                    'Ирина', 'Екатерина', 'Светлана', 'Юлия', 'Дарья'
                ])[1 + pg_temp.det_int(generated_number * 83, 10)]
        END AS first_name,
        (ARRAY[
            'Иванов', 'Петров', 'Смирнов', 'Кузнецов', 'Попов',
            'Соколов', 'Лебедев', 'Козлов', 'Новиков', 'Морозов',
            'Волков', 'Алексеев', 'Семёнов', 'Егоров', 'Павлов'
        ])[1 + pg_temp.det_int(generated_number * 89, 15)] AS last_name
    FROM generate_series(1, 20000 * :scale) AS generated(generated_number)
)
INSERT INTO customer.tb_customers
(
    last_name,
    first_name,
    middle_name,
    birth_date,
    gender,
    email,
    phone,
    is_email_verified,
    is_phone_verified,
    is_blocked,
    created_at,
    updated_at
)
SELECT
    generated_customers.last_name,
    generated_customers.first_name,
    CASE
        WHEN generated_customers.generated_number % 2 = 0
            THEN 'Александрович'
        ELSE 'Александровна'
    END,
    DATE '1950-01-01'
        + pg_temp.det_int(generated_customers.generated_number * 97, 20000),
    CASE
        WHEN generated_customers.generated_number % 2 = 0 THEN 'male'
        ELSE 'female'
    END,
    CASE
        WHEN generated_customers.generated_number % 20 = 0 THEN NULL
        ELSE
            'customer'
            || lpad(generated_customers.generated_number::text, 8, '0')
            || '@example.test'
    END,
    CASE
        WHEN generated_customers.generated_number % 25 = 0 THEN NULL
        ELSE '+79' || lpad(generated_customers.generated_number::text, 9, '0')
    END,
    generated_customers.generated_number % 20 <> 0
        AND generated_customers.generated_number % 4 <> 0,
    generated_customers.generated_number % 25 <> 0
        AND generated_customers.generated_number % 5 <> 0,
    generated_customers.generated_number % 101 = 0,
    TIMESTAMPTZ '2020-01-01 00:00:00+00'
        + make_interval(days => pg_temp.det_int(generated_customers.generated_number * 101, 1800)),
    TIMESTAMPTZ '2020-01-01 00:00:00+00'
        + make_interval(days => pg_temp.det_int(generated_customers.generated_number * 101, 1800))
FROM generated_customers;

INSERT INTO customer.tb_customer_addresses
(
    customer_id,
    city_id,
    street_name,
    house_number,
    building_number,
    apartment_number,
    entrance,
    floor,
    intercom,
    recipient_name,
    recipient_phone,
    delivery_comment,
    is_default,
    created_at,
    updated_at
)
SELECT
    customer.customer_id,
    1 + pg_temp.det_int(customer.customer_id * 103 + address_sequence * 11, 30),
    (ARRAY[
        'Ленина', 'Центральная', 'Молодёжная', 'Школьная',
        'Садовая', 'Лесная', 'Новая', 'Советская',
        'Набережная', 'Гагарина', 'Мира', 'Победы'
    ])[1 + pg_temp.det_int(customer.customer_id * 107 + address_sequence, 12)],
    (
        1 + pg_temp.det_int(customer.customer_id * 109 + address_sequence, 250)
    )::text
    || CASE
           WHEN customer.customer_id % 17 = 0 THEN 'А'
           ELSE ''
       END,
    CASE
        WHEN customer.customer_id % 4 = 0
            THEN (1 + pg_temp.det_int(customer.customer_id * 113, 5))::text
        ELSE NULL
    END,
    CASE
        WHEN customer.customer_id % 7 = 0
            THEN NULL
        ELSE (1 + pg_temp.det_int(customer.customer_id * 127 + address_sequence, 500))::text
    END,
    CASE
        WHEN customer.customer_id % 7 = 0
            THEN NULL
        ELSE (1 + pg_temp.det_int(customer.customer_id * 131, 8))::text
    END,
    CASE
        WHEN customer.customer_id % 7 = 0
            THEN NULL
        ELSE (1 + pg_temp.det_int(customer.customer_id * 137, 25))::text
    END,
    CASE
        WHEN customer.customer_id % 3 = 0
            THEN lpad(pg_temp.det_int(customer.customer_id * 139, 10000)::text, 4, '0')
        ELSE NULL
    END,
    concat_ws(' ', customer.first_name, customer.last_name),
    COALESCE(
        customer.phone,
        '+78' || lpad((customer.customer_id * 10 + address_sequence)::text, 9, '0')
    ),
    CASE
        WHEN address_sequence = 1 THEN 'Позвонить за 15 минут до приезда.'
        ELSE 'Оставить заказ у консьержа.'
    END,
    address_sequence = 1,
    customer.created_at + make_interval(days => address_sequence),
    customer.created_at + make_interval(days => address_sequence)
FROM customer.tb_customers AS customer
CROSS JOIN LATERAL generate_series(
    1,
    CASE
        WHEN customer.customer_id % 5 IN (0, 1) THEN 2
        ELSE 1
    END
) AS generated_address(address_sequence);

\echo '-- Warehouses, current prices and stocks'

INSERT INTO stock.tb_warehouses
(
    city_id,
    warehouse_name,
    is_active,
    created_at,
    updated_at
)
SELECT
    city.city_id,
    city.city_name || CASE
        WHEN warehouse_number = 1 THEN ' — центральный склад'
        ELSE ' — городской склад'
    END,
    true,
    TIMESTAMPTZ '2022-01-01 00:00:00+00'
        + make_interval(days => city.city_id::integer + warehouse_number),
    TIMESTAMPTZ '2022-01-01 00:00:00+00'
        + make_interval(days => city.city_id::integer + warehouse_number)
FROM general.tb_cities AS city
CROSS JOIN generate_series(1, 2) AS generated_warehouse(warehouse_number);

INSERT INTO catalog.tb_product_prices
(
    product_id,
    city_id,
    amount,
    created_at,
    updated_at
)
SELECT
    product.product_id,
    city.city_id,
    round(
        (
            100::numeric
            + pg_temp.det_int(product.product_id * 149 + city.city_id * 17, 250000)::numeric / 100
            + city.city_id::numeric * 3.25
        )
        * CASE
              WHEN product.is_markdown THEN 0.65::numeric
              ELSE 1::numeric
          END,
        2
    ),
    product.created_at,
    product.updated_at
FROM catalog.tb_products AS product
CROSS JOIN general.tb_cities AS city;

INSERT INTO stock.tb_product_stocks
(
    warehouse_id,
    product_id,
    quantity,
    created_at,
    updated_at
)
SELECT
    1 + (
        (
            product.product_id * 13
            + warehouse_sequence * 7
        ) % 60
    )::bigint,
    product.product_id,
    pg_temp.det_int(product.product_id * 151 + warehouse_sequence * 19, 251),
    product.created_at,
    product.updated_at
FROM catalog.tb_products AS product
CROSS JOIN generate_series(1, 8) AS generated_stock(warehouse_sequence);

\echo '-- Orders'

WITH settings AS
(
    SELECT 20000 * :scale AS customer_count
),
raw_orders AS
(
    SELECT
        generated_number,
        1 + pg_temp.det_int(generated_number * 157, settings.customer_count)
            AS customer_id,
        pg_temp.det_int(generated_number * 163, 100) AS status_bucket,
        TIMESTAMPTZ '2026-06-30 12:00:00+00'
            - make_interval(
                days  => pg_temp.det_int(generated_number * 167, 720),
                hours => pg_temp.det_int(generated_number * 173, 24),
                mins  => pg_temp.det_int(generated_number * 179, 60)
            ) AS created_at
    FROM settings
    CROSS JOIN generate_series(1, 100000 * :scale)
        AS generated(generated_number)
),
prepared_orders AS
(
    SELECT
        raw_orders.*,
        CASE
            WHEN status_bucket < 5  THEN 'waiting_for_payment'
            WHEN status_bucket < 15 THEN 'paid'
            WHEN status_bucket < 30 THEN 'processing'
            WHEN status_bucket < 80 THEN 'completed'
            ELSE 'cancelled'
        END AS status
    FROM raw_orders
)
INSERT INTO sales.tb_orders
(
    order_number,
    customer_id,
    payment_type_id,
    delivery_type_id,
    status,
    reservation_expires_at,
    created_at,
    updated_at
)
SELECT
    'ORD-' || lpad(prepared_orders.generated_number::text, 10, '0'),
    prepared_orders.customer_id,
    CASE
        WHEN prepared_orders.status = 'waiting_for_payment' THEN 1
        ELSE 1 + pg_temp.det_int(prepared_orders.generated_number * 181, 3)
    END,
    CASE
        WHEN pg_temp.det_int(prepared_orders.generated_number * 191, 10) < 7 THEN 1
        ELSE 2
    END,
    prepared_orders.status,
    CASE
        WHEN prepared_orders.status IN ('waiting_for_payment', 'cancelled')
            THEN prepared_orders.created_at + interval '30 minutes'
        ELSE NULL
    END,
    prepared_orders.created_at,
    prepared_orders.created_at
        + CASE prepared_orders.status
              WHEN 'waiting_for_payment' THEN interval '5 minutes'
              WHEN 'paid'                THEN interval '1 hour'
              WHEN 'processing'          THEN interval '12 hours'
              WHEN 'completed'           THEN interval '3 days'
              WHEN 'cancelled'           THEN interval '2 hours'
          END
FROM prepared_orders;

INSERT INTO sales.tb_order_delivery_addresses
(
    order_id,
    city_id,
    street_name,
    house_number,
    building_number,
    apartment_number,
    entrance,
    floor,
    intercom,
    recipient_name,
    recipient_phone,
    delivery_comment,
    created_at,
    updated_at
)
SELECT
    orders.order_id,
    address.city_id,
    address.street_name,
    address.house_number,
    address.building_number,
    address.apartment_number,
    address.entrance,
    address.floor,
    address.intercom,
    address.recipient_name,
    address.recipient_phone,
    address.delivery_comment,
    orders.created_at,
    orders.created_at
FROM sales.tb_orders AS orders
JOIN customer.tb_customer_addresses AS address
    ON address.customer_id = orders.customer_id
   AND address.is_default
WHERE orders.delivery_type_id = 1;

WITH settings AS
(
    SELECT 5000 * :scale AS product_count
),
expanded_order_items AS
(
    SELECT
        orders.order_id,
        orders.customer_id,
        default_address.city_id,
        line_number,
        1 + pg_temp.det_int(
            orders.order_id * 193 + line_number * 197,
            settings.product_count
        ) AS product_id
    FROM sales.tb_orders AS orders
    JOIN customer.tb_customer_addresses AS default_address
        ON default_address.customer_id = orders.customer_id
       AND default_address.is_default
    CROSS JOIN settings
    CROSS JOIN LATERAL generate_series(
        1,
        1 + pg_temp.det_int(orders.order_id * 199, 5)
    ) AS generated_line(line_number)
)
INSERT INTO sales.tb_order_items
(
    order_id,
    line_number,
    product_id,
    quantity,
    unit_price,
    vat_rate
)
SELECT
    expanded_order_items.order_id,
    expanded_order_items.line_number::smallint,
    expanded_order_items.product_id,
    1 + pg_temp.det_int(
        expanded_order_items.order_id * 211 + expanded_order_items.line_number,
        4
    ),
    price.amount,
    product.vat_rate
FROM expanded_order_items
JOIN catalog.tb_product_prices AS price
    ON price.product_id = expanded_order_items.product_id
   AND price.city_id = expanded_order_items.city_id
JOIN catalog.tb_products AS product
    ON product.product_id = expanded_order_items.product_id;

\echo '-- Order status history'

INSERT INTO sales.tb_order_status_history
(
    order_id,
    previous_status,
    current_status,
    created_at
)
SELECT
    order_id,
    NULL,
    'new',
    created_at
FROM sales.tb_orders;

INSERT INTO sales.tb_order_status_history
(
    order_id,
    previous_status,
    current_status,
    created_at
)
SELECT
    order_id,
    'new',
    'waiting_for_payment',
    created_at + interval '1 minute'
FROM sales.tb_orders;

INSERT INTO sales.tb_order_status_history
(
    order_id,
    previous_status,
    current_status,
    created_at
)
SELECT
    order_id,
    'waiting_for_payment',
    'paid',
    created_at + interval '30 minutes'
FROM sales.tb_orders
WHERE status IN ('paid', 'processing', 'completed');

INSERT INTO sales.tb_order_status_history
(
    order_id,
    previous_status,
    current_status,
    created_at
)
SELECT
    order_id,
    'paid',
    'processing',
    created_at + interval '2 hours'
FROM sales.tb_orders
WHERE status IN ('processing', 'completed');

INSERT INTO sales.tb_order_status_history
(
    order_id,
    previous_status,
    current_status,
    created_at
)
SELECT
    order_id,
    'processing',
    'completed',
    created_at + interval '3 days'
FROM sales.tb_orders
WHERE status = 'completed';

INSERT INTO sales.tb_order_status_history
(
    order_id,
    previous_status,
    current_status,
    created_at
)
SELECT
    order_id,
    'waiting_for_payment',
    'cancelled',
    created_at + interval '2 hours'
FROM sales.tb_orders
WHERE status = 'cancelled';

COMMIT;

RESET synchronous_commit;
RESET work_mem;
RESET maintenance_work_mem;

ANALYZE;

\echo '== Data generation completed =='
\echo 'Expected scale=1: about 1.1 million rows across all tables.'

SELECT *
FROM
(
    SELECT 'general.tb_cities' AS table_name, count(*) AS row_count FROM general.tb_cities
    UNION ALL
    SELECT 'customer.tb_customers', count(*) FROM customer.tb_customers
    UNION ALL
    SELECT 'customer.tb_customer_addresses', count(*) FROM customer.tb_customer_addresses
    UNION ALL
    SELECT 'catalog.tb_categories', count(*) FROM catalog.tb_categories
    UNION ALL
    SELECT 'catalog.tb_products', count(*) FROM catalog.tb_products
    UNION ALL
    SELECT 'catalog.tb_product_property_values', count(*) FROM catalog.tb_product_property_values
    UNION ALL
    SELECT 'catalog.tb_product_prices', count(*) FROM catalog.tb_product_prices
    UNION ALL
    SELECT 'stock.tb_warehouses', count(*) FROM stock.tb_warehouses
    UNION ALL
    SELECT 'stock.tb_product_stocks', count(*) FROM stock.tb_product_stocks
    UNION ALL
    SELECT 'sales.tb_orders', count(*) FROM sales.tb_orders
    UNION ALL
    SELECT 'sales.tb_order_delivery_addresses', count(*) FROM sales.tb_order_delivery_addresses
    UNION ALL
    SELECT 'sales.tb_order_items', count(*) FROM sales.tb_order_items
    UNION ALL
    SELECT 'sales.tb_order_status_history', count(*) FROM sales.tb_order_status_history
) AS row_counts
ORDER BY table_name;
