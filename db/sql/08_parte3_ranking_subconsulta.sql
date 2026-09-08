-- ====================================================================
-- Parte 3: Consultas con ventana y subconsulta correlacionada
-- ====================================================================

-- ====================================================================
-- CONSULTA A: Ranking con funcion de ventana
-- Ranking de clientes por gasto total, con puesto (RANK) y
-- particion por forma de pago.
-- ====================================================================

-- Spec: "Para cada cliente vigente con al menos un pedido no eliminado,
-- calcular su gasto total y asignar un puesto dentro de un ranking
-- global (mayor gasto = puesto 1). Usar RANK para que los empates
-- compartan puesto. Adicionalmente, mostrar el puesto dentro de su
-- forma de pago preferida (la que mas veces uso). No usar SELECT *.
-- Filas eliminadas logicalamente en cualquier tabla deben excluirse."

-- VERSION 1: Ranking con ventana (RANK sobre gasto total)
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
SELECT cliente,
       email,
       gasto_total,
       forma_preferida,
       RANK() OVER (ORDER BY gasto_total DESC) AS puesto_global,
       RANK() OVER (PARTITION BY forma_preferida ORDER BY gasto_total DESC) AS puesto_por_pago
FROM gastos
ORDER BY puesto_global
LIMIT 20;

-- ====================================================================
-- CONSULTA B: Subconsulta correlacionada
-- Productos cuyo precio unitario promedio en los pedidos es mayor
-- al precio promedio de todos los productos de su categoria.
-- ====================================================================

-- Spec: "Devolver el nombre del producto, su precio promedio de venta
-- (precio_unitario promedio en detalle_pedido) y el precio promedio
-- de la categoria. Solo productos vigentes (activo = TRUE) cuyo
-- precio promedio supere el promedio de su categoria. El promedio
-- de la categoria se calcula con subconsulta correlacionada."

-- VERSION 1: Subconsulta correlacionada
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
LIMIT 20;
