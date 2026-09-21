-- TP Unidad 3 - Indices y vistas.
-- Ejecutar SOLO en una copia de laboratorio ya cargada con schema.sql y 04_carga_masiva.sql.
-- El script conserva las tres consultas, sus planes antes/despues y la prueba de escritura.
\set ON_ERROR_STOP on
\timing on

\echo '=== TP5: limpieza de indices propios para medir el ANTES ==='
DROP INDEX IF EXISTS idx_tp5_producto_nombre_trgm;
DROP INDEX IF EXISTS idx_tp5_pedido_forma_pago_fecha;
DROP INDEX IF EXISTS idx_tp5_detalle_producto_cobertura;
ANALYZE producto;
ANALYZE pedido;
ANALYZE detalle_pedido;

\echo '=== Q1 ANTES: busqueda frecuente de productos vigentes por texto y precio ==='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id_producto, nombre, precio_lista, stock
FROM producto
WHERE activo = TRUE
  AND nombre ILIKE '%Producto 123%'
  AND precio_lista BETWEEN 1000 AND 4000
ORDER BY precio_lista DESC;

\echo '=== Q2 ANTES: pedidos con tarjeta del ultimo mes ==='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.id_pedido, p.fecha, p.id_cliente, p.forma_pago
FROM pedido p
WHERE p.forma_pago = 'TARJETA'
  AND p.fecha >= CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY p.fecha DESC;

\echo '=== Q3 ANTES: detalle e historial de un producto ==='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT dp.id_pedido, p.fecha, dp.cantidad, dp.precio_unitario
FROM detalle_pedido dp
JOIN pedido p ON p.id_pedido = dp.id_pedido
WHERE dp.id_producto = (SELECT min(id_producto) FROM producto)
ORDER BY p.fecha DESC;

\echo '=== Escritura ANTES: 500 detalles reversibles ==='
BEGIN;
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH pedido_benchmark AS (
    INSERT INTO pedido (fecha, id_cliente, forma_pago)
    SELECT CURRENT_TIMESTAMP, min(id_cliente), 'TARJETA'::forma_pago_enum
    FROM cliente
    RETURNING id_pedido
)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT b.id_pedido, pr.id_producto, 1, pr.precio_lista
FROM pedido_benchmark b
CROSS JOIN (
    SELECT id_producto, precio_lista
    FROM producto
    ORDER BY id_producto
    LIMIT 500
) pr;
ROLLBACK;

\echo '=== Indices aceptados ==='
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Q1: el patron ILIKE contiene comodin inicial; B-tree no resuelve esa busqueda.
CREATE INDEX idx_tp5_producto_nombre_trgm
    ON producto USING gin (nombre gin_trgm_ops)
    WHERE activo = TRUE;

-- Q2: igualdad por medio de pago y rango/orden descendente por fecha.
CREATE INDEX idx_tp5_pedido_forma_pago_fecha
    ON pedido (forma_pago, fecha DESC);

-- Q3: la PK comienza por id_pedido; esta consulta comienza por id_producto.
CREATE INDEX idx_tp5_detalle_producto_cobertura
    ON detalle_pedido (id_producto, id_pedido)
    INCLUDE (cantidad, precio_unitario);

ANALYZE producto;
ANALYZE pedido;
ANALYZE detalle_pedido;

\echo '=== Q1 DESPUES ==='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id_producto, nombre, precio_lista, stock
FROM producto
WHERE activo = TRUE
  AND nombre ILIKE '%Producto 123%'
  AND precio_lista BETWEEN 1000 AND 4000
ORDER BY precio_lista DESC;

\echo '=== Q2 DESPUES ==='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.id_pedido, p.fecha, p.id_cliente, p.forma_pago
FROM pedido p
WHERE p.forma_pago = 'TARJETA'
  AND p.fecha >= CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY p.fecha DESC;

\echo '=== Q3 DESPUES ==='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT dp.id_pedido, p.fecha, dp.cantidad, dp.precio_unitario
FROM detalle_pedido dp
JOIN pedido p ON p.id_pedido = dp.id_pedido
WHERE dp.id_producto = (SELECT min(id_producto) FROM producto)
ORDER BY p.fecha DESC;

\echo '=== Escritura DESPUES: 500 detalles reversibles ==='
BEGIN;
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH pedido_benchmark AS (
    INSERT INTO pedido (fecha, id_cliente, forma_pago)
    SELECT CURRENT_TIMESTAMP, min(id_cliente), 'TARJETA'::forma_pago_enum
    FROM cliente
    RETURNING id_pedido
)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT b.id_pedido, pr.id_producto, 1, pr.precio_lista
FROM pedido_benchmark b
CROSS JOIN (
    SELECT id_producto, precio_lista
    FROM producto
    ORDER BY id_producto
    LIMIT 500
) pr;
ROLLBACK;

-- Propuesta descartada: CREATE INDEX ... ON producto (activo).
-- activo tiene baja cardinalidad y ya participa como segunda columna de
-- idx_producto_categoria_activo. Para Q1, el predicado parcial del GIN es util;
-- un B-tree aislado por activo agregaria costo de escritura sin resolver ILIKE.
