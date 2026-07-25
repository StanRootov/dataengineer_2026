\echo '== Initializing emarket schema =='

\set ON_ERROR_STOP on

ALTER DATABASE emarket SET timezone TO 'UTC';

SET client_min_messages TO warning;

CREATE SCHEMA general;
CREATE SCHEMA customer;
CREATE SCHEMA catalog;
CREATE SCHEMA stock;
CREATE SCHEMA sales;

CREATE TABLE general.tb_cities
(
    city_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_code    text        NOT NULL,
    city_name    text        NOT NULL,
    region_name  text        NOT NULL,
    timezone     text        NOT NULL,
    is_active    boolean     NOT NULL DEFAULT true,
    created_at   timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT unique_tb_cities_code
        UNIQUE (city_code),

    CONSTRAINT unique_tb_cities_region_name
        UNIQUE (region_name, city_name),

    CONSTRAINT check_tb_cities_code_not_empty
        CHECK (btrim(city_code) <> ''),

    CONSTRAINT check_tb_cities_name_not_empty
        CHECK (btrim(city_name) <> ''),

    CONSTRAINT check_tb_cities_region_not_empty
        CHECK (btrim(region_name) <> ''),

    CONSTRAINT check_tb_cities_timezone_not_empty
        CHECK (btrim(timezone) <> '')
);

CREATE TABLE customer.tb_customers
(
    customer_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    last_name         text,
    first_name        text,
    middle_name       text,
    birth_date        date,
    gender            text,
    email             text,
    phone             text,
    is_email_verified boolean     NOT NULL DEFAULT false,
    is_phone_verified boolean     NOT NULL DEFAULT false,
    is_blocked        boolean     NOT NULL DEFAULT false,
    created_at        timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT check_tb_customers_email_not_empty
        CHECK (email IS NULL OR btrim(email) <> ''),

    CONSTRAINT check_tb_customers_phone_format
        CHECK (phone IS NULL OR phone ~ '^\+[1-9][0-9]{7,14}$'),

    CONSTRAINT check_tb_customers_email_verification
        CHECK (NOT is_email_verified OR email IS NOT NULL),

    CONSTRAINT check_tb_customers_phone_verification
        CHECK (NOT is_phone_verified OR phone IS NOT NULL),

    CONSTRAINT check_tb_customers_gender
        CHECK (gender IS NULL OR gender IN ('male', 'female'))
);

CREATE TABLE customer.tb_customer_addresses
(
    address_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id      bigint      NOT NULL,
    city_id          bigint      NOT NULL,
    street_name      text        NOT NULL,
    house_number     text        NOT NULL,
    building_number  text,
    apartment_number text,
    entrance         text,
    floor             text,
    intercom          text,
    recipient_name   text        NOT NULL,
    recipient_phone  text        NOT NULL,
    delivery_comment text,
    is_default       boolean     NOT NULL DEFAULT false,
    created_at       timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT foreign_key_tb_customer_addresses_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer.tb_customers (customer_id)
        ON DELETE CASCADE,

    CONSTRAINT foreign_key_tb_customer_addresses_city
        FOREIGN KEY (city_id)
        REFERENCES general.tb_cities (city_id)
        ON DELETE RESTRICT,

    CONSTRAINT check_tb_customer_addresses_street_name
        CHECK (btrim(street_name) <> ''),

    CONSTRAINT check_tb_customer_addresses_house_number
        CHECK (btrim(house_number) <> ''),

    CONSTRAINT check_tb_customer_addresses_recipient_name
        CHECK (btrim(recipient_name) <> ''),

    CONSTRAINT check_tb_customer_addresses_recipient_phone
        CHECK (recipient_phone ~ '^\+[1-9][0-9]{7,14}$')
);

CREATE TABLE catalog.tb_categories
(
    category_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_category_id bigint,
    category_name      text        NOT NULL,
    sort_order         bigint      NOT NULL,
    is_active          boolean     NOT NULL DEFAULT true,
    created_at         timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT foreign_key_tb_categories_parent
        FOREIGN KEY (parent_category_id)
        REFERENCES catalog.tb_categories (category_id)
        ON DELETE RESTRICT,

    CONSTRAINT unique_tb_categories_parent_name
        UNIQUE NULLS NOT DISTINCT (parent_category_id, category_name),

    CONSTRAINT unique_tb_categories_sort_order
        UNIQUE (sort_order),

    CONSTRAINT check_tb_categories_name_not_empty
        CHECK (btrim(category_name) <> ''),

    CONSTRAINT check_tb_categories_sort_order
        CHECK (sort_order > 0),

    CONSTRAINT check_tb_categories_not_self_parent
        CHECK
        (
            parent_category_id IS NULL
            OR parent_category_id <> category_id
        )
);

CREATE TABLE catalog.tb_measures
(
    measure_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    measure_name text        NOT NULL,
    symbol       text        NOT NULL,
    description  text,
    is_active    boolean     NOT NULL DEFAULT true,
    created_at   timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT unique_tb_measures_name
        UNIQUE (measure_name),

    CONSTRAINT unique_tb_measures_symbol
        UNIQUE (symbol),

    CONSTRAINT check_tb_measures_name_not_empty
        CHECK (btrim(measure_name) <> ''),

    CONSTRAINT check_tb_measures_symbol_not_empty
        CHECK (btrim(symbol) <> '')
);

CREATE TABLE catalog.tb_property_value_types
(
    property_value_type_id   smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    property_value_type_name text NOT NULL,
    description              text,

    CONSTRAINT unique_tb_property_value_types_name
        UNIQUE (property_value_type_name),

    CONSTRAINT check_tb_property_value_types_name_not_empty
        CHECK (btrim(property_value_type_name) <> '')
);

CREATE TABLE catalog.tb_properties
(
    property_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    property_name         text        NOT NULL,
    description           text,
    property_value_type_id smallint   NOT NULL,
    measure_id            bigint,
    sort_order            integer     NOT NULL DEFAULT 100,
    is_active             boolean     NOT NULL DEFAULT true,
    created_at            timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT foreign_key_tb_properties_value_type
        FOREIGN KEY (property_value_type_id)
        REFERENCES catalog.tb_property_value_types (property_value_type_id)
        ON DELETE RESTRICT,

    CONSTRAINT foreign_key_tb_properties_measure
        FOREIGN KEY (measure_id)
        REFERENCES catalog.tb_measures (measure_id)
        ON DELETE RESTRICT,

    CONSTRAINT check_tb_properties_name_not_empty
        CHECK (btrim(property_name) <> ''),

    CONSTRAINT check_tb_properties_sort_order
        CHECK (sort_order >= 0)
);

CREATE TABLE catalog.tb_products
(
    product_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_product_id bigint,
    category_id       bigint         NOT NULL,
    product_code      text           NOT NULL,
    internal_barcode  text           NOT NULL,
    title             text           NOT NULL,
    brand_name        text,
    units_per_package integer        NOT NULL DEFAULT 1,
    is_markdown       boolean        NOT NULL DEFAULT false,
    vat_rate          numeric(5, 2)  NOT NULL,
    is_active         boolean        NOT NULL DEFAULT true,
    created_at        timestamptz    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        timestamptz    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT foreign_key_tb_products_source_product
        FOREIGN KEY (source_product_id)
        REFERENCES catalog.tb_products (product_id)
        ON DELETE RESTRICT,

    CONSTRAINT foreign_key_tb_products_category
        FOREIGN KEY (category_id)
        REFERENCES catalog.tb_categories (category_id)
        ON DELETE RESTRICT,

    CONSTRAINT unique_tb_products_product_code
        UNIQUE (product_code),

    CONSTRAINT unique_tb_products_internal_barcode
        UNIQUE (internal_barcode),

    CONSTRAINT check_tb_products_product_code_not_empty
        CHECK (btrim(product_code) <> ''),

    CONSTRAINT check_tb_products_internal_barcode_not_empty
        CHECK (btrim(internal_barcode) <> ''),

    CONSTRAINT check_tb_products_title_not_empty
        CHECK (btrim(title) <> ''),

    CONSTRAINT check_tb_products_units_per_package
        CHECK (units_per_package > 0),

    CONSTRAINT check_tb_products_vat_rate
        CHECK (vat_rate IN (0, 10, 22)),

    CONSTRAINT check_tb_products_markdown_source
        CHECK
        (
            (is_markdown AND source_product_id IS NOT NULL)
            OR
            (NOT is_markdown AND source_product_id IS NULL)
        ),

    CONSTRAINT check_tb_products_not_self_source
        CHECK
        (
            source_product_id IS NULL
            OR source_product_id <> product_id
        )
);

CREATE TABLE catalog.tb_product_property_values
(
    product_id  bigint      NOT NULL,
    property_id bigint      NOT NULL,
    value_text  text        NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT primary_key_tb_product_property_values
        PRIMARY KEY (product_id, property_id),

    CONSTRAINT foreign_key_tb_product_property_values_product
        FOREIGN KEY (product_id)
        REFERENCES catalog.tb_products (product_id)
        ON DELETE CASCADE,

    CONSTRAINT foreign_key_tb_product_property_values_property
        FOREIGN KEY (property_id)
        REFERENCES catalog.tb_properties (property_id)
        ON DELETE RESTRICT,

    CONSTRAINT check_tb_product_property_values_not_empty
        CHECK (btrim(value_text) <> '')
);

CREATE TABLE catalog.tb_product_prices
(
    product_id bigint         NOT NULL,
    city_id    bigint         NOT NULL,
    amount     numeric(12, 2) NOT NULL,
    created_at timestamptz    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT primary_key_tb_product_prices
        PRIMARY KEY (product_id, city_id),

    CONSTRAINT foreign_key_tb_product_prices_product
        FOREIGN KEY (product_id)
        REFERENCES catalog.tb_products (product_id)
        ON DELETE RESTRICT,

    CONSTRAINT foreign_key_tb_product_prices_city
        FOREIGN KEY (city_id)
        REFERENCES general.tb_cities (city_id)
        ON DELETE RESTRICT,

    CONSTRAINT check_tb_product_prices_amount
        CHECK (amount >= 0)
);

CREATE TABLE stock.tb_warehouses
(
    warehouse_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_id        bigint      NOT NULL,
    warehouse_name text        NOT NULL,
    is_active      boolean     NOT NULL DEFAULT true,
    created_at     timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT foreign_key_tb_warehouses_city
        FOREIGN KEY (city_id)
        REFERENCES general.tb_cities (city_id)
        ON DELETE RESTRICT,

    CONSTRAINT unique_tb_warehouses_city_name
        UNIQUE (city_id, warehouse_name),

    CONSTRAINT check_tb_warehouses_name_not_empty
        CHECK (btrim(warehouse_name) <> '')
);

CREATE TABLE stock.tb_product_stocks
(
    warehouse_id bigint      NOT NULL,
    product_id   bigint      NOT NULL,
    quantity     integer     NOT NULL DEFAULT 0,
    created_at   timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT primary_key_tb_product_stocks
        PRIMARY KEY (warehouse_id, product_id),

    CONSTRAINT foreign_key_tb_product_stocks_warehouse
        FOREIGN KEY (warehouse_id)
        REFERENCES stock.tb_warehouses (warehouse_id)
        ON DELETE RESTRICT,

    CONSTRAINT foreign_key_tb_product_stocks_product
        FOREIGN KEY (product_id)
        REFERENCES catalog.tb_products (product_id)
        ON DELETE RESTRICT,

    CONSTRAINT check_tb_product_stocks_quantity
        CHECK (quantity >= 0)
);

CREATE TABLE sales.tb_payment_types
(
    payment_type_id   smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_type_name text        NOT NULL,
    description       text,
    is_active         boolean     NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT unique_tb_payment_types_name
        UNIQUE (payment_type_name),

    CONSTRAINT check_tb_payment_types_name_not_empty
        CHECK (btrim(payment_type_name) <> '')
);

CREATE TABLE sales.tb_delivery_types
(
    delivery_type_id   smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    delivery_type_name text        NOT NULL,
    description        text,
    is_active          boolean     NOT NULL DEFAULT true,
    created_at         timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT unique_tb_delivery_types_name
        UNIQUE (delivery_type_name),

    CONSTRAINT check_tb_delivery_types_name_not_empty
        CHECK (btrim(delivery_type_name) <> '')
);

CREATE TABLE sales.tb_orders
(
    order_id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_number           text        NOT NULL,
    customer_id            bigint      NOT NULL,
    payment_type_id        smallint    NOT NULL,
    delivery_type_id       smallint    NOT NULL,
    status                  text        NOT NULL,
    reservation_expires_at timestamptz,
    created_at              timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT unique_tb_orders_order_number
        UNIQUE (order_number),

    CONSTRAINT foreign_key_tb_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer.tb_customers (customer_id)
        ON DELETE RESTRICT,

    CONSTRAINT foreign_key_tb_orders_payment_type
        FOREIGN KEY (payment_type_id)
        REFERENCES sales.tb_payment_types (payment_type_id)
        ON DELETE RESTRICT,

    CONSTRAINT foreign_key_tb_orders_delivery_type
        FOREIGN KEY (delivery_type_id)
        REFERENCES sales.tb_delivery_types (delivery_type_id)
        ON DELETE RESTRICT,

    CONSTRAINT check_tb_orders_number_not_empty
        CHECK (btrim(order_number) <> ''),

    CONSTRAINT check_tb_orders_status_not_empty
        CHECK (btrim(status) <> ''),

    CONSTRAINT check_tb_orders_reservation_expiration
        CHECK
        (
            reservation_expires_at IS NULL
            OR reservation_expires_at > created_at
        )
);

CREATE TABLE sales.tb_order_delivery_addresses
(
    order_id         bigint      NOT NULL,
    city_id          bigint      NOT NULL,
    street_name      text        NOT NULL,
    house_number     text        NOT NULL,
    building_number  text,
    apartment_number text,
    entrance         text,
    floor            text,
    intercom         text,
    recipient_name   text        NOT NULL,
    recipient_phone  text        NOT NULL,
    delivery_comment text,
    created_at       timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT primary_key_tb_order_delivery_addresses
        PRIMARY KEY (order_id),

    CONSTRAINT foreign_key_tb_order_delivery_addresses_order
        FOREIGN KEY (order_id)
        REFERENCES sales.tb_orders (order_id)
        ON DELETE CASCADE,

    CONSTRAINT foreign_key_tb_order_delivery_addresses_city
        FOREIGN KEY (city_id)
        REFERENCES general.tb_cities (city_id)
        ON DELETE RESTRICT,

    CONSTRAINT check_tb_order_delivery_addresses_street_name
        CHECK (btrim(street_name) <> ''),

    CONSTRAINT check_tb_order_delivery_addresses_house_number
        CHECK (btrim(house_number) <> ''),

    CONSTRAINT check_tb_order_delivery_addresses_recipient_name
        CHECK (btrim(recipient_name) <> ''),

    CONSTRAINT check_tb_order_delivery_addresses_recipient_phone
        CHECK (recipient_phone ~ '^\+[1-9][0-9]{7,14}$')
);

CREATE TABLE sales.tb_order_items
(
    order_id    bigint         NOT NULL,
    line_number smallint       NOT NULL,
    product_id  bigint         NOT NULL,
    quantity    integer        NOT NULL,
    unit_price  numeric(12, 2) NOT NULL,
    vat_rate    numeric(5, 2)  NOT NULL,

    CONSTRAINT primary_key_tb_order_items
        PRIMARY KEY (order_id, line_number),

    CONSTRAINT foreign_key_tb_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES sales.tb_orders (order_id)
        ON DELETE CASCADE,

    CONSTRAINT foreign_key_tb_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES catalog.tb_products (product_id)
        ON DELETE RESTRICT,

    CONSTRAINT check_tb_order_items_line_number
        CHECK (line_number > 0),

    CONSTRAINT check_tb_order_items_quantity
        CHECK (quantity > 0),

    CONSTRAINT check_tb_order_items_unit_price
        CHECK (unit_price >= 0),

    CONSTRAINT check_tb_order_items_vat_rate
        CHECK (vat_rate IN (0, 10, 22))
);

CREATE TABLE sales.tb_order_status_history
(
    order_status_history_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id                bigint      NOT NULL,
    previous_status         text,
    current_status          text        NOT NULL,
    created_at              timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT foreign_key_tb_order_status_history_order
        FOREIGN KEY (order_id)
        REFERENCES sales.tb_orders (order_id)
        ON DELETE RESTRICT,

    CONSTRAINT check_tb_order_status_history_previous_status_not_empty
        CHECK (previous_status IS NULL OR btrim(previous_status) <> ''),

    CONSTRAINT check_tb_order_status_history_current_status_not_empty
        CHECK (btrim(current_status) <> ''),

    CONSTRAINT check_tb_order_status_history_status_changed
        CHECK
        (
            previous_status IS NULL
            OR previous_status <> current_status
        )
);

\echo '== Creating basic indexes =='

CREATE UNIQUE INDEX unique_tb_customers_email
    ON customer.tb_customers (lower(email))
    WHERE email IS NOT NULL;

CREATE UNIQUE INDEX unique_tb_customers_phone
    ON customer.tb_customers (phone)
    WHERE phone IS NOT NULL;

CREATE UNIQUE INDEX unique_tb_customer_addresses_default
    ON customer.tb_customer_addresses (customer_id)
    WHERE is_default;

CREATE INDEX index_tb_customer_addresses_customer
    ON customer.tb_customer_addresses (customer_id, address_id);

CREATE INDEX index_tb_customer_addresses_city
    ON customer.tb_customer_addresses (city_id, customer_id);

CREATE INDEX index_tb_categories_parent
    ON catalog.tb_categories (parent_category_id, sort_order);

CREATE INDEX index_tb_properties_value_type
    ON catalog.tb_properties (property_value_type_id);

CREATE INDEX index_tb_properties_measure
    ON catalog.tb_properties (measure_id)
    WHERE measure_id IS NOT NULL;

CREATE INDEX index_tb_products_category
    ON catalog.tb_products (category_id, product_id);

CREATE INDEX index_tb_products_source_product
    ON catalog.tb_products (source_product_id)
    WHERE source_product_id IS NOT NULL;

CREATE INDEX index_tb_products_active_category
    ON catalog.tb_products (category_id, product_id)
    WHERE is_active;

CREATE INDEX index_tb_product_property_values_property
    ON catalog.tb_product_property_values (property_id, product_id);

CREATE INDEX index_tb_product_prices_city
    ON catalog.tb_product_prices (city_id, product_id);

CREATE INDEX index_tb_product_prices_city_amount
    ON catalog.tb_product_prices (city_id, amount, product_id);

CREATE INDEX index_tb_warehouses_city
    ON stock.tb_warehouses (city_id, warehouse_id);

CREATE INDEX index_tb_product_stocks_product
    ON stock.tb_product_stocks (product_id, warehouse_id);

CREATE INDEX index_tb_product_stocks_available
    ON stock.tb_product_stocks (product_id, warehouse_id, quantity)
    WHERE quantity > 0;

CREATE INDEX index_tb_orders_customer_created
    ON sales.tb_orders (customer_id, created_at DESC, order_id);

CREATE INDEX index_tb_orders_status_created
    ON sales.tb_orders (status, created_at DESC, order_id);

CREATE INDEX index_tb_orders_reservation_expiration
    ON sales.tb_orders (reservation_expires_at, order_id)
    WHERE reservation_expires_at IS NOT NULL;

CREATE INDEX index_tb_orders_payment_type
    ON sales.tb_orders (payment_type_id, created_at DESC);

CREATE INDEX index_tb_orders_delivery_type
    ON sales.tb_orders (delivery_type_id, created_at DESC);

CREATE INDEX index_tb_order_delivery_addresses_city
    ON sales.tb_order_delivery_addresses (city_id, order_id);

CREATE INDEX index_tb_order_items_product
    ON sales.tb_order_items (product_id, order_id);

CREATE INDEX index_tb_order_status_history_order_created
    ON sales.tb_order_status_history (order_id, created_at, order_status_history_id);

\echo '== Database objects created successfully =='
