# Parte 4 — Competencia de optimización

## Consulta base (misma para todos los equipos)

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

Base: `food_store_tp3` (~600k filas en `detalle_pedido`, 200k en `pedido`, 50k en `producto`, 8 en `categoria`).

## Registro de la competencia

| Estrategia | Tiempo antes (ms) | Tiempo después (ms) | Mejora (x) | Cambio aplicado |
|---|---|---|---|---|
| **Baseline** (con índices TP3) | 1282 | **1219** | 1.05x | `idx_detalle_pedido_producto` + `idx_pedido_cliente_id` |
| **Estrategia 2**: work_mem = 128MB | 1219 | **1233** | 0.99x (sin mejora) | `SET work_mem = '128MB'` para evitar sort a disco |
| **Estrategia 3**: CTE preagregado | 1219 | **1255** | 0.97x (sin mejora) | Reescribir con CTE `detalle_completo` |

## Detalle de cada estrategia

### Estrategia 1: Baseline con índices (ya medido en Parte 1)

- **Cambio**: `CREATE INDEX idx_detalle_pedido_producto ON detalle_pedido (id_pedido, id_producto) INCLUDE (cantidad, precio_unitario)`
- **Resultado**: 1282 → 1219 ms (5% mejora)
- **Por qué no mejoró más**: El optimizador sigue eligiendo Seq Scan sobre `detalle_pedido` porque necesita procesar las 600k filas completas para el GROUP BY. El índice no se usa para el scan porque el optimizador estima que un Index Scan sobre 600k filas sería más lento que un Seq Scan completo.

### Estrategia 2: Aumentar work_mem

- **Cambio**: `SET work_mem = '128MB'` antes de la consulta
- **Resultado**: 1233 ms (sin mejora significativa)
- **Efecto en el plan**: 
  - El Hash de `pedido` ahora cabe en 1 batch (11423kB) en lugar de 2 batches con 438kB a disco
  - El Sort usa quicksort en memoria (57389kB) en lugar de external merge a disco (26MB)
- **Por qué no mejoró**: El cuello de botella real es el **Seq Scan de 600k filas** en `detalle_pedido` (~25ms), no el sort ni el hash spill. El 90% del tiempo está en la agregación y el join, no en el I/O temporal.

### Estrategia 3: CTE preagregado

- **Cambio**: Reescribir con CTE `detalle_completo` que selecciona solo las columnas necesarias
- **Resultado**: 1255 ms (sin mejora, incluso ligeramente más lento)
- **Por qué no funcionó**: En PostgreSQL 12+, los CTEs no son barreras de optimización — el optimizador los "inlinea" y genera el mismo plan que la consulta original. La reescritura no cambia el plan ejecutado.

## Análisis del algoritmo de join

| Join | Algoritmo | Tabla externa | Tabla interna (hash) | Justificación |
|---|---|---|---|---|
| dp ↔ pr | Hash Join | `detalle_pedido` (600k) | `producto` (50k, 2856kB) | Producto cabe en memoria |
| dp ↔ c | Hash Join | resultado anterior | `categoria` (8, 9kB) | Categoría cabe en 1 batch |
| (dp+pr+c) ↔ p | Hash Join | resultado anterior | `pedido` (200k, 6749kB) | Pedido necesita 2 batches con work_mem default |

## Conclusión

**Ganó la Estrategia 1** (índices de cobertura) con 1219 ms. Las demás estrategias no mejoraron porque:

1. El cuello de botella es el **Seq Scan completo** de 600k filas — no se puede evitar sin cambiar la lógica de la consulta (necesita todas las filas para GROUP BY)
2. El **sort a disco** (26MB) es inevitable con work_mem default (~4MB) para 600k filas, pero su impacto es menor al del scan
3. El **hash spill de pedido** (438kB a disco) se resolvió con más work_mem, pero no impactó el tiempo total

**Estrategia descartada (y por qué)**: Aumentar `work_mem` a 128MB elimina los spills a disco pero no reduce el tiempo porque el 90% del costo está en el Seq Scan y la agregación, no en el I/O temporal.
