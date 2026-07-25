
-- Топ 50 товаров по сумме заврешенных заказов

SELECT p.product_id,
       p.product_code,
       p.title,
       sum(oi.quantity) AS sold_quantity,
       sum(oi.quantity * oi.unit_price) AS revenue,
       count(DISTINCT o.order_id) AS order_count
FROM sales.tb_orders AS o
JOIN sales.tb_order_items AS oi
    ON oi.order_id = o.order_id
JOIN catalog.tb_products AS p
    ON p.product_id = oi.product_id
WHERE o.status = 'completed'
GROUP BY p.product_id,
         p.product_code,
         p.title
ORDER BY revenue DESC
LIMIT 50;

-- Заказы по городам

WITH order_city AS
(
    SELECT o.order_id,
           COALESCE(oa.city_id, ca.city_id) AS city_id
    FROM sales.tb_orders AS o
    JOIN customer.tb_customer_addresses AS ca
        ON ca.customer_id = o.customer_id
        AND ca.is_default
    LEFT JOIN sales.tb_order_delivery_addresses AS oa
        ON oa.order_id = o.order_id
)
SELECT c.city_name,
       count(DISTINCT o.order_id) AS order_count,
       sum(oi.quantity * oi.unit_price) AS revenue
FROM sales.tb_orders AS o
JOIN order_city oc
    ON oc.order_id = o.order_id
JOIN general.tb_cities AS c
    ON c.city_id = oc.city_id
JOIN sales.tb_order_items AS oi
    ON oi.order_id = o.order_id
WHERE o.status = 'completed'
GROUP BY c.city_id,
         c.city_name
ORDER BY revenue DESC;
