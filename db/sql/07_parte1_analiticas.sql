-- ====================================================================
-- Parte 1: Consultas Analiticas Lentas - TP4 Semana 4
-- Dos consultas con 3+ JOINs sobre la base masiva
-- ====================================================================

-- ====================================================================
-- CONSULTA 1: Facturacion por categoria y mes
-- JOINs: detalle_pedido -> producto -> categoria, detalle_pedido -> pedido
-- ====================================================================

\echo '=== CONSULTA 1: Facturacion por categoria y mes (ANTES) ==='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT c.nombre AS categoria,
       date_trunc('month', p.fecha) AS mes,
       count(DISTINCT p.id_pedido) AS pedidos,
       sum(dp.cantidad) AS unidades,
       sum(dp.cantidad * dp.precio_unitario) AS facturacion
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto
JOIN categoria c ON c.id_categoria = pr.id_categoria
JOIN pedido p ON p.id_pedido = dp.id_pedido
WHERE c.activo = TRUE
GROUP BY c.nombre, date_trunc('month', p.fecha)
ORDER BY facturacion DESC;

-- ====================================================================
-- CONSULTA 2: Ranking de clientes por gasto total
-- JOINs: cliente -> pedido -> detalle_pedido
-- ====================================================================

\echo '=== CONSULTA 2: Ranking de clientes por gasto (ANTES) ==='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT cl.nombre || ' ' || cl.apellido AS cliente,
       cl.email,
       count(DISTINCT p.id_pedido) AS total_pedidos,
       sum(dp.cantidad) AS unidades_compradas,
       sum(dp.cantidad * dp.precio_unitario) AS gasto_total
FROM cliente cl
JOIN pedido p ON p.id_cliente = cl.id_cliente
JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
WHERE cl.nombre IS NOT NULL
GROUP BY cl.id_cliente, cl.nombre, cl.apellido, cl.email
HAVING sum(dp.cantidad * dp.precio_unitario) > 0
ORDER BY gasto_total DESC
LIMIT 20;

-- ====================================================================
-- FASE 2: Indices propuestos por IA
-- ====================================================================

-- Indice para Consulta 1: cobertura en detalle_pedido para el JOIN con pedido
-- y la agregacion
CREATE INDEX idx_detalle_pedido_producto ON detalle_pedido (id_pedido, id_producto)
    INCLUDE (cantidad, precio_unitario);

-- Indice para Consulta 2: busqueda rapida de pedidos por cliente
-- (ya existe idx_pedido_cliente_fecha, pero creamos uno mas especifico)
CREATE INDEX idx_pedido_cliente_id ON pedido (id_cliente)
    INCLUDE (id_pedido);

ANALYZE detalle_pedido;
ANALYZE pedido;

-- ====================================================================
-- FASE 3: Medicion DESPUES de indices
-- ====================================================================

\echo '=== CONSULTA 1: Facturacion por categoria y mes (DESPUES) ==='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT c.nombre AS categoria,
       date_trunc('month', p.fecha) AS mes,
       count(DISTINCT p.id_pedido) AS pedidos,
       sum(dp.cantidad) AS unidades,
       sum(dp.cantidad * dp.precio_unitario) AS facturacion
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto
JOIN categoria c ON c.id_categoria = pr.id_categoria
JOIN pedido p ON p.id_pedido = dp.id_pedido
WHERE c.activo = TRUE
GROUP BY c.nombre, date_trunc('month', p.fecha)
ORDER BY facturacion DESC;

\echo '=== CONSULTA 2: Ranking de clientes por gasto (DESPUES) ==='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT cl.nombre || ' ' || cl.apellido AS cliente,
       cl.email,
       count(DISTINCT p.id_pedido) AS total_pedidos,
       sum(dp.cantidad) AS unidades_compradas,
       sum(dp.cantidad * dp.precio_unitario) AS gasto_total
FROM cliente cl
JOIN pedido p ON p.id_cliente = cl.id_cliente
JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
WHERE cl.nombre IS NOT NULL
GROUP BY cl.id_cliente, cl.nombre, cl.apellido, cl.email
HAVING sum(dp.cantidad * dp.precio_unitario) > 0
ORDER BY gasto_total DESC
LIMIT 20;
