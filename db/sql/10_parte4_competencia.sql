-- ====================================================================
-- Parte 4: Competencia de optimizacion
-- Consulta: Facturacion por categoria y mes (2+ JOINs + agregacion)
-- ====================================================================

-- ====================================================================
-- Estrategia 1: Baseline (con indices de Parte 1)
-- Ya medido: 1219 ms
-- ====================================================================

-- ====================================================================
-- Estrategia 2: Aumentar work_mem para evitar sort a disco
-- ====================================================================

SET work_mem = '128MB';

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

RESET work_mem;

-- ====================================================================
-- Estrategia 3: Reescribir con subconsulta preagregada para reducir
-- el volumen que atraviesa los JOINs
-- ====================================================================

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH detalle_completo AS (
    SELECT dp.id_pedido,
           dp.id_producto,
           dp.cantidad,
           dp.precio_unitario
    FROM detalle_pedido dp
)
SELECT c.nombre AS categoria,
       date_trunc('month', p.fecha) AS mes,
       count(DISTINCT p.id_pedido) AS pedidos,
       sum(dc.cantidad) AS unidades,
       sum(dc.cantidad * dc.precio_unitario) AS facturacion
FROM detalle_completo dc
JOIN producto pr ON pr.id_producto = dc.id_producto
JOIN categoria c ON c.id_categoria = pr.id_categoria
JOIN pedido p ON p.id_pedido = dc.id_pedido
WHERE c.activo = TRUE
GROUP BY c.nombre, date_trunc('month', p.fecha)
ORDER BY facturacion DESC;
