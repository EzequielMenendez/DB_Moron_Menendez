-- TP Unidad 3 - Vistas y vista materializada.
-- Ejecutar SOLO despues de cargar el esquema y los datos en una copia de laboratorio.
\set ON_ERROR_STOP on

CREATE OR REPLACE VIEW vw_tp5_productos_vigentes_categoria AS
SELECT pr.id_producto,
       pr.nombre AS producto,
       pr.descripcion,
       pr.precio_lista,
       pr.stock,
       c.id_categoria,
       c.nombre AS categoria
FROM producto pr
JOIN categoria c ON c.id_categoria = pr.id_categoria
WHERE pr.activo = TRUE
  AND c.activo = TRUE;

-- No expone telefono: el reporte operativo solo necesita el identificador y nombre.
CREATE OR REPLACE VIEW vw_tp5_pedidos_clientes AS
SELECT p.id_pedido,
       p.fecha,
       p.forma_pago,
       c.id_cliente,
       c.nombre,
       c.apellido,
       c.email
FROM pedido p
JOIN cliente c ON c.id_cliente = p.id_cliente;

CREATE OR REPLACE VIEW vw_tp5_detalle_pedido_producto AS
SELECT dp.id_pedido,
       dp.id_producto,
       pr.nombre AS producto,
       dp.cantidad,
       dp.precio_unitario,
       dp.cantidad * dp.precio_unitario AS subtotal
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto;

-- Vista de minimo privilegio: oculta email y telefono de cliente.
-- El modelo actual no posee tabla usuario ni columna contrasena; no se inventan
-- columnas ni se altera el esquema heredado solo para satisfacer ese ejemplo.
CREATE OR REPLACE VIEW vw_tp5_clientes_publicos AS
SELECT id_cliente, nombre, apellido
FROM cliente;

DROP MATERIALIZED VIEW IF EXISTS mv_tp5_facturacion_categoria_mes;
CREATE MATERIALIZED VIEW mv_tp5_facturacion_categoria_mes AS
SELECT c.id_categoria,
       c.nombre AS categoria,
       date_trunc('month', p.fecha) AS mes,
       count(DISTINCT p.id_pedido) AS pedidos,
       sum(dp.cantidad) AS unidades,
       sum(dp.cantidad * dp.precio_unitario) AS facturacion
FROM detalle_pedido dp
JOIN pedido p ON p.id_pedido = dp.id_pedido
JOIN producto pr ON pr.id_producto = dp.id_producto
JOIN categoria c ON c.id_categoria = pr.id_categoria
WHERE c.activo = TRUE
  AND pr.activo = TRUE
GROUP BY c.id_categoria, c.nombre, date_trunc('month', p.fecha)
WITH DATA;

CREATE UNIQUE INDEX idx_mv_tp5_facturacion_categoria_mes
    ON mv_tp5_facturacion_categoria_mes (id_categoria, mes);

-- En produccion, si el reporte admite datos de hasta una hora:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tp5_facturacion_categoria_mes;
