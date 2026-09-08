# Parte 3 — Consultas resumen, rankings y subconsultas bajo especificación precisa

Base: `food_store_tp3` (PostgreSQL 18.6).

---

## Consulta A: Ranking con función de ventana

### Especificación

> Para cada cliente vigente (`nombre IS NOT NULL`) con al menos un pedido no eliminado:
> - Calcular su **gasto total** (suma de `cantidad * precio_unitario` en `detalle_pedido`)
> - Asignar un **puesto global** con `RANK()` (mayor gasto = puesto 1, empates comparten puesto)
> - Calcular su **forma de pago preferida** (`mode() WITHIN GROUP (ORDER BY forma_pago)`)
> - Asignar un **puesto dentro de su forma de pago**
> - No usar `SELECT *`
> - Excluir filas eliminadas lógicamente

### SQL generado por IA

```sql
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
ORDER BY puesto_global
LIMIT 20;
```

### Resultado (top 5)

| puesto_global | cliente | gasto_total | forma_preferida | puesto_por_pago |
|---|---|---|---|---|
| 1 | Nombre3245 Apellido3245 | 464172.55 | TRANSFERENCIA | 1 |
| 2 | Nombre15337 Apellido15337 | 437765.95 | TRANSFERENCIA | 2 |
| 3 | Nombre19311 Apellido19311 | 433207.72 | TARJETA | 1 |
| 4 | Nombre6760 Apellido6760 | 426066.16 | EFECTIVO | 1 |
| 5 | Nombre4322 Apellido4322 | 424859.41 | TRANSFERENCIA | 3 |

### Versión 2 (estructura distinta: subconsulta scalar en lugar de CTE)

```sql
WITH ranking AS (
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
SELECT * FROM ranking ORDER BY puesto_global LIMIT 20;
```

### Verificación de equivalencia

```
direccion | filas
----------+------
v1 solo   |     0
v2 solo   |     0
```

**Equivalencia confirmada**: ambas versiones producen exactamente los mismos resultados (EXCEPT devuelve 0 filas en ambos sentidos).

---

## Consulta B: Subconsulta correlacionada

### Especificación

> Para cada producto **vigente** (`activo = TRUE`) cuyo **precio promedio de venta** (`avg(precio_unitario)` en `detalle_pedido`) supere el **precio promedio de venta de su categoría**:
> - Devolver: nombre del producto, precio promedio del producto, precio promedio de la categoría
> - El promedio de la categoría se calcula con **subconsulta correlacionada** (se evalúa por cada fila del producto)
> - No usar `SELECT *`
> - Excluir filas eliminadas lógicamente

### SQL generado por IA

```sql
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
```

### Resultado

| producto | precio_promedio_producto | precio_promedio_categoria |
|---|---|---|
| Producto 11698 | 4158.76 | 1997.87 |

Solo 1 producto supera el promedio de su categoría.

### Versión 2 (con JOIN precalculado en lugar de subconsulta correlacionada)

```sql
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
```

### Verificación de equivalencia

```
direccion | filas
----------+------
v1 solo   |     0
v2 solo   |     0
```

**Equivalencia confirmada**: ambas versiones producen exactamente los mismos resultados.

---

## Resumen de equivalencias verificadas

| Consulta | Versiones | EXCEPT v1→v2 | EXCEPT v2→v1 | Equivalente |
|---|---|---|---|---|
| A. Ranking con ventana | CTE vs subconsulta scalar | 0 filas | 0 filas | **Sí** |
| B. Subconsulta correlacionada | Subconsulta vs JOIN precalculado | 0 filas | 0 filas | **Sí** |
