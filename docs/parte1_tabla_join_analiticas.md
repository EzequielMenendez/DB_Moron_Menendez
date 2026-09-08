# Parte 1 — Tabla comparativa de consultas analíticas

Base: `food_store_tp3` (PostgreSQL 18.6, ~600k filas en `detalle_pedido`).

## Consulta 1: Facturación por categoría y mes

```sql
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
```

| Aspecto | Antes | Después |
|---------|-------|---------|
| **Tiempo real** | **1282 ms** | **1219 ms** |
| **Algoritmo de join** | Hash Join × 3 | Hash Join × 3 (sin cambio) |
| **Orden de joins** | `dp → pr → c` (primero), `dp → p` (segundo) | Igual |
| **Nodo dominante** | Sort externo (external merge Disk: 26MB) | Igual |
| **Seq Scan en detalle_pedido** | Sí (600k filas, 4318 buffers read) | Sí (600k filas, 3686 buffers read) |
| **Cambio aplicado** | — | `CREATE INDEX idx_detalle_pedido_producto ON detalle_pedido (id_pedido, id_producto) INCLUDE (cantidad, precio_unitario)` |
| **Mejora** | — | **~5% (marginal)** |

**Análisis del join:** El optimizador eligió **Hash Join** para las 3 combinaciones de tablas porque:
- `categoria` tiene 8 filas (tabla dimensión pequeña → Hash table cabe en memoria)
- `producto` tiene 50k filas (Hash table cabe en memoria, 2856kB)
- `pedido` tiene 200k filas (Hash table en 2 batches, 6749kB + disco)
- `detalle_pedido` tiene 600k filas (tabla principal, Secuencia Scan)

El Hash Join es eficiente aquí porque las tablas de dimensión son相对较pequeñas y caben en memoria. Un Nested Loop sería peor porque haría 600k iteraciones. Un Merge Join requeriría ordenamiento previo.

---

## Consulta 2: Ranking de clientes por gasto total

```sql
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
```

| Aspecto | Antes | Después |
|---------|-------|---------|
| **Tiempo real** | **2584 ms** | **2598 ms** |
| **Algoritmo de join** | Hash Join × 2 | Hash Join × 2 (sin cambio) |
| **Orden de joins** | `dp → p` (primero), `(dp+p) → cl` (segundo) | Igual |
| **Nodo dominante** | Sort externo (external merge Disk: 57MB) | Igual |
| **Seq Scan en detalle_pedido** | Sí (600k filas, 4224 buffers read) | Sí (600k filas, 3592 buffers read) |
| **Cambio aplicado** | — | `CREATE INDEX idx_pedido_cliente_id ON pedido (id_cliente) INCLUDE (id_pedido)` |
| **Mejora** | — | **~0% (sin mejora)** |

**Análisis del join:** El optimizador usó **Hash Join** para ambas combinaciones:
- Primero hashea `pedido` (200k filas, 6749kB en 2 batches) y lo une con `detalle_pedido` (Seq Scan)
- Luego hashea `cliente` (20k filas, 2131kB) y lo une con el resultado anterior

El índice en `pedido(id_cliente)` no se usa porque el optimizador prefiere Seq Scan sobre 200k filas para construir el Hash table completo (necesita todas las filas para el GROUP BY). Un Nested Loop sería catastrófico: 600k × 1 lookup cada uno.

---

## Resumen de algoritmos de join

| Consulta | Join 1 | Join 2 | Join 3 | Tiempo total |
|----------|--------|--------|--------|-------------|
| 1. Facturación categoría/mes | Hash Join (dp↔pr) | Hash Join (dp↔c) | Hash Join (dp↔p) | 1219 ms |
| 2. Ranking clientes gasto | Hash Join (dp↔p) | Hash Join (dp↔cl) | — | 2598 ms |

**Conclusión:** En ambas consultas, el optimizador eligió **Hash Join** porque las tablas de dimensión (categoria=8, producto=50k, cliente=20k) son relativamente pequeñas y sus Hash tables caben en memoria. Los índices adicionales no cambiaron el algoritmo de join ni el plan general; el cuello de botella real es el **Seq Scan de 600k filas en `detalle_pedido`** y el **Sort externo** (escritura a disco de 26-57MB).
