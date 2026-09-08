-- ====================================================================
-- Verificacion de equivalencia: Ranking ventana V1 vs V2
-- ====================================================================

-- V1: Con CTE y subconsulta correlacionada en forma preferida
-- V2: Sin CTE, usando subconsulta scalar para forma preferida

-- VERSION 2: Misma logica con estructura distinta
WITH ranking AS (
    SELECT cliente,
           email,
           gasto_total,
           forma_preferida,
           RANK() OVER (ORDER BY gasto_total DESC) AS puesto_global,
           RANK() OVER (PARTITION BY forma_preferida ORDER BY gasto_total DESC) AS puesto_por_pago
    FROM (
        SELECT cl.nombre || ' ' || cl.apellido AS cliente,
               cl.email,
               sum(dp.cantidad * dp.precio_unitario) AS gasto_total,
               (
                   SELECT mode() WITHIN GROUP (ORDER BY p2.forma_pago)
                   FROM pedido p2
                   WHERE p2.id_cliente = cl.id_cliente
               ) AS forma_preferida
        FROM cliente cl
        JOIN pedido p ON p.id_cliente = cl.id_cliente
        JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
        WHERE cl.nombre IS NOT NULL
        GROUP BY cl.id_cliente, cl.nombre, cl.apellido, cl.email
        HAVING sum(dp.cantidad * dp.precio_unitario) > 0
    ) sub
)
SELECT * FROM ranking ORDER BY puesto_global LIMIT 20;

-- Verificacion EXCEPT (debe dar 0 filas en ambos sentidos)
WITH v1 AS (
    WITH gastos AS (
        SELECT cl.id_cliente,
               cl.nombre || ' ' || cl.apellido AS cliente,
               cl.email,
               sum(dp.cantidad * dp.precio_unitario) AS gasto_total,
               mode() WITHIN GROUP (ORDER BY p.forma_pago) AS forma_preferida
        FROM cliente cl
        JOIN pedido p ON p.id_cliente = cl.id_cliente
        JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
        WHERE cl.nombre IS NOT NULL
        GROUP BY cl.id_cliente, cl.nombre, cl.apellido, cl.email
        HAVING sum(dp.cantidad * dp.precio_unitario) > 0
    )
    SELECT cliente, email, gasto_total, forma_preferida,
           RANK() OVER (ORDER BY gasto_total DESC) AS puesto_global,
           RANK() OVER (PARTITION BY forma_preferida ORDER BY gasto_total DESC) AS puesto_por_pago
    FROM gastos
),
v2 AS (
    SELECT cliente, email, gasto_total, forma_preferida,
           RANK() OVER (ORDER BY gasto_total DESC) AS puesto_global,
           RANK() OVER (PARTITION BY forma_preferida ORDER BY gasto_total DESC) AS puesto_por_pago
    FROM (
        SELECT cl.nombre || ' ' || cl.apellido AS cliente,
               cl.email,
               sum(dp.cantidad * dp.precio_unitario) AS gasto_total,
               (
                   SELECT mode() WITHIN GROUP (ORDER BY p2.forma_pago)
                   FROM pedido p2
                   WHERE p2.id_cliente = cl.id_cliente
               ) AS forma_preferida
        FROM cliente cl
        JOIN pedido p ON p.id_cliente = cl.id_cliente
        JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
        WHERE cl.nombre IS NOT NULL
        GROUP BY cl.id_cliente, cl.nombre, cl.apellido, cl.email
        HAVING sum(dp.cantidad * dp.precio_unitario) > 0
    ) sub
)
SELECT 'v1 solo' AS direccion, count(*) AS filas FROM (SELECT * FROM v1 EXCEPT SELECT * FROM v2) t1
UNION ALL
SELECT 'v2 solo', count(*) FROM (SELECT * FROM v2 EXCEPT SELECT * FROM v1) t2;

-- ====================================================================
-- Verificacion de equivalencia: Subconsulta correlacionada V1 vs V2
-- ====================================================================

-- V2: Con JOIN en vez de subconsulta correlacionada
SELECT pr.nombre AS producto,
       avg(dp.precio_unitario) AS precio_promedio_producto,
       cat_avg.precio_promedio_categoria
FROM producto pr
JOIN detalle_pedido dp ON dp.id_producto = pr.id_producto
JOIN (
    SELECT pr2.id_categoria,
           avg(dp2.precio_unitario) AS precio_promedio_categoria
    FROM detalle_pedido dp2
    JOIN producto pr2 ON pr2.id_producto = dp2.id_producto
    WHERE pr2.activo = TRUE
    GROUP BY pr2.id_categoria
) cat_avg ON cat_avg.id_categoria = pr.id_categoria
WHERE pr.activo = TRUE
GROUP BY pr.id_producto, pr.nombre, cat_avg.precio_promedio_categoria
HAVING avg(dp.precio_unitario) > cat_avg.precio_promedio_categoria
ORDER BY precio_promedio_producto DESC
LIMIT 20;

-- Verificacion EXCEPT
WITH v1 AS (
    SELECT pr.nombre AS producto,
           avg(dp.precio_unitario) AS precio_promedio_producto,
           (
               SELECT avg(dp2.precio_unitario)
               FROM detalle_pedido dp2
               JOIN producto pr2 ON pr2.id_producto = dp2.id_producto
               WHERE pr2.id_categoria = pr.id_categoria
                 AND pr2.activo = TRUE
           ) AS precio_promedio_categoria
    FROM producto pr
    JOIN detalle_pedido dp ON dp.id_producto = pr.id_producto
    WHERE pr.activo = TRUE
    GROUP BY pr.id_producto, pr.nombre, pr.id_categoria
    HAVING avg(dp.precio_unitario) > (
        SELECT avg(dp2.precio_unitario)
        FROM detalle_pedido dp2
        JOIN producto pr2 ON pr2.id_producto = dp2.id_producto
        WHERE pr2.id_categoria = pr.id_categoria
          AND pr2.activo = TRUE
    )
    ORDER BY precio_promedio_producto DESC
    LIMIT 20
),
v2 AS (
    SELECT pr.nombre AS producto,
           avg(dp.precio_unitario) AS precio_promedio_producto,
           cat_avg.precio_promedio_categoria
    FROM producto pr
    JOIN detalle_pedido dp ON dp.id_producto = pr.id_producto
    JOIN (
        SELECT pr2.id_categoria,
               avg(dp2.precio_unitario) AS precio_promedio_categoria
        FROM detalle_pedido dp2
        JOIN producto pr2 ON pr2.id_producto = dp2.id_producto
        WHERE pr2.activo = TRUE
        GROUP BY pr2.id_categoria
    ) cat_avg ON cat_avg.id_categoria = pr.id_categoria
    WHERE pr.activo = TRUE
    GROUP BY pr.id_producto, pr.nombre, cat_avg.precio_promedio_categoria
    HAVING avg(dp.precio_unitario) > cat_avg.precio_promedio_categoria
    ORDER BY precio_promedio_producto DESC
    LIMIT 20
)
SELECT 'v1 solo' AS direccion, count(*) AS filas FROM (SELECT * FROM v1 EXCEPT SELECT * FROM v2) t1
UNION ALL
SELECT 'v2 solo', count(*) FROM (SELECT * FROM v2 EXCEPT SELECT * FROM v1) t2;
