-- Verificacion de equivalencia para las vistas del TP5.
-- Cada par debe devolver solo_vista = 0 y solo_manual = 0.
\set ON_ERROR_STOP on

WITH vista AS (
    SELECT * FROM vw_tp5_productos_vigentes_categoria
), manual AS (
    SELECT pr.id_producto, pr.nombre AS producto, pr.descripcion, pr.precio_lista,
           pr.stock, c.id_categoria, c.nombre AS categoria
    FROM producto pr
    JOIN categoria c ON c.id_categoria = pr.id_categoria
    WHERE pr.activo = TRUE AND c.activo = TRUE
)
SELECT 'vw_tp5_productos_vigentes_categoria' AS objeto,
       (SELECT count(*) FROM (SELECT * FROM vista EXCEPT SELECT * FROM manual) d) AS solo_vista,
       (SELECT count(*) FROM (SELECT * FROM manual EXCEPT SELECT * FROM vista) d) AS solo_manual;

WITH vista AS (
    SELECT * FROM vw_tp5_pedidos_clientes
), manual AS (
    SELECT p.id_pedido, p.fecha, p.forma_pago, c.id_cliente, c.nombre, c.apellido, c.email
    FROM pedido p
    JOIN cliente c ON c.id_cliente = p.id_cliente
)
SELECT 'vw_tp5_pedidos_clientes' AS objeto,
       (SELECT count(*) FROM (SELECT * FROM vista EXCEPT SELECT * FROM manual) d) AS solo_vista,
       (SELECT count(*) FROM (SELECT * FROM manual EXCEPT SELECT * FROM vista) d) AS solo_manual;

WITH vista AS (
    SELECT * FROM vw_tp5_detalle_pedido_producto
), manual AS (
    SELECT dp.id_pedido, dp.id_producto, pr.nombre AS producto, dp.cantidad,
           dp.precio_unitario, dp.cantidad * dp.precio_unitario AS subtotal
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id_producto = dp.id_producto
)
SELECT 'vw_tp5_detalle_pedido_producto' AS objeto,
       (SELECT count(*) FROM (SELECT * FROM vista EXCEPT SELECT * FROM manual) d) AS solo_vista,
       (SELECT count(*) FROM (SELECT * FROM manual EXCEPT SELECT * FROM vista) d) AS solo_manual;

WITH vista AS (
    SELECT id_categoria, categoria, mes, pedidos, unidades, facturacion
    FROM mv_tp5_facturacion_categoria_mes
), manual AS (
    SELECT c.id_categoria, c.nombre AS categoria, date_trunc('month', p.fecha) AS mes,
           count(DISTINCT p.id_pedido) AS pedidos, sum(dp.cantidad) AS unidades,
           sum(dp.cantidad * dp.precio_unitario) AS facturacion
    FROM detalle_pedido dp
    JOIN pedido p ON p.id_pedido = dp.id_pedido
    JOIN producto pr ON pr.id_producto = dp.id_producto
    JOIN categoria c ON c.id_categoria = pr.id_categoria
    WHERE c.activo = TRUE AND pr.activo = TRUE
    GROUP BY c.id_categoria, c.nombre, date_trunc('month', p.fecha)
)
SELECT 'mv_tp5_facturacion_categoria_mes' AS objeto,
       (SELECT count(*) FROM (SELECT * FROM vista EXCEPT SELECT * FROM manual) d) AS solo_vista,
       (SELECT count(*) FROM (SELECT * FROM manual EXCEPT SELECT * FROM vista) d) AS solo_manual;

\echo '=== Medicion: consulta original ==='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT c.id_categoria, c.nombre AS categoria, date_trunc('month', p.fecha) AS mes,
       count(DISTINCT p.id_pedido) AS pedidos, sum(dp.cantidad) AS unidades,
       sum(dp.cantidad * dp.precio_unitario) AS facturacion
FROM detalle_pedido dp
JOIN pedido p ON p.id_pedido = dp.id_pedido
JOIN producto pr ON pr.id_producto = dp.id_producto
JOIN categoria c ON c.id_categoria = pr.id_categoria
WHERE c.activo = TRUE AND pr.activo = TRUE
GROUP BY c.id_categoria, c.nombre, date_trunc('month', p.fecha);

\echo '=== Medicion: vista materializada ==='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id_categoria, categoria, mes, pedidos, unidades, facturacion
FROM mv_tp5_facturacion_categoria_mes;
