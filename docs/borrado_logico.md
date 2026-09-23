# Borrado Lógico (Soft Delete) y su Impacto en Consultas e Índices

Base: `food_store_tp5` (PostgreSQL 18.6), 50.000 productos / 8 categorías.

## Qué es el borrado lógico en este esquema

En lugar de `DELETE` físico (que perdería histórico y violaría las FK con
`ON DELETE RESTRICT`), Food Store marca las filas como inactivas con la
columna booleana `activo`:

| Tabla | Columna | Valor activo | Valor dado de baja |
|-------|---------|--------------|--------------------|
| `categoria` | `activo BOOLEAN NOT NULL DEFAULT TRUE` | `TRUE` | `FALSE` |
| `producto` | `activo BOOLEAN NOT NULL DEFAULT TRUE` | `TRUE` | `FALSE` |

**No hay `DELETE` en el flujo normal de negocio.** La "baja" es
`UPDATE tabla SET activo = FALSE WHERE id = ...`. Las filas permanecen en la
tabla, con todas sus referencias intactas.

Estado actual de `producto` en `food_store_tp5`:

| Total | Activos | Inactivos (borrado lógico) |
|-------|---------|----------------------------|
| 50.000 | 47.434 | 2.566 |

## Impacto 1: Toda consulta de negocio debe filtrar `activo = TRUE`

### Lo que muestra la evidencia

**Sin filtro** (consulta cruda sobre el join producto↔categoria):

```sql
SELECT count(*) FROM producto pr
JOIN categoria c ON c.id_categoria = pr.id_categoria;
-- Resultado: 50.000  ← incluye 2.566 productos dados de baja
```

**Con filtro** (como lo hace la vista `vw_tp5_productos_vigentes_categoria` del script 12):

```sql
SELECT count(*) FROM vw_tp5_productos_vigentes_categoria;
-- Resultado: 47.434  ← solo productos vigentes
```

**Diferencia: 2.566 filas fantasma** si se olvida el filtro. Un reporte de
facturación, un catálogo o un conteo de stock que omita `WHERE activo = TRUE`
incluirá productos que ya no se venden.

### Dónde el proyecto ya lo aplica correctamente

| Objeto | Archivo | Filtro aplicado |
|--------|---------|-----------------|
| `vw_tp5_productos_vigentes_categoria` | `12_tp5_views_materializadas.sql` | `pr.activo = TRUE AND c.activo = TRUE` |
| `mv_tp5_facturacion_categoria_mes` | `12_tp5_views_materializadas.sql` | `c.activo = TRUE AND pr.activo = TRUE` |
| Trigger `trg_detalle_producto_activo` | `14_plpgsql_funciones_triggers.sql` | Bloquea INSERT si `producto.activo = FALSE` |
| Procedimiento `sp_registrar_pedido` | `14_plpgsql_funciones_triggers.sql` | Valida `activo` antes de cada línea |
| Consultas de negocio (scripts 05–10) | Varios | `WHERE activo = TRUE` explícito |

## Impacto 2: los índices parciales solo funcionan con el filtro

### Índice GIN parcial (script 11)

```sql
CREATE INDEX idx_tp5_producto_nombre_trgm
    ON producto USING gin (nombre gin_trgm_ops)
    WHERE activo = TRUE;   -- ← condición parcial
```

Este índice **solo contiene filas con `activo = TRUE`**. El plan lo demuestra:

**Consulta CON `activo = TRUE` (el predicado coincide con la condición parcial):**

```
Bitmap Heap Scan on producto  (actual time=1.746..1.804 rows=106.00)
  Recheck Cond: (((nombre)::text ~~* '%Producto 123%'::text) AND activo)
  -> Bitmap Index Scan on idx_tp5_producto_nombre_trgm  (actual time=1.726..1.726 rows=107.00)
Execution Time: 2.168 ms
```

**Consulta SIN `activo = TRUE` (el predicado no coincide → no puede usar el índice parcial):**

```
Seq Scan on producto  (actual time=0.060..17.999 rows=111.00)
  Filter: ((nombre)::text ~~* '%Producto 123%'::text)
  Rows Removed by Filter: 49889
Execution Time: 18.075 ms
```

| Consulto | Nodo elegido | Tiempo | Efecto |
|----------|--------------|--------|--------|
| Con `activo = TRUE` | Bitmap Index Scan (índice parcial) | **2,168 ms** | El índice resuelve la búsqueda |
| Sin `activo = TRUE` | Seq Scan + Filter | **18,075 ms** | Índice inutilizable; escanea 50k filas y descarta 49.889 |

**8,3x más lenta sin el filtro.** No es solo cuestión de resultados correctos:
olvidar `activo = TRUE` también **destruye el rendimiento** porque los índices
parciales dejan de ser elegibles para el optimizador.

### Índice B-tree compuesto (schema.sql)

```sql
CREATE INDEX idx_producto_categoria_activo ON producto (id_categoria, activo);
```

Este índice no es parcial (no tiene `WHERE`), pero `activo` es su segunda
columna. Con el filtro, ambas columnas se resuelven en el `Index Cond`:

```
Index Scan using idx_producto_categoria_activo
  Index Cond: ((id_categoria = 1) AND (activo = true))   ← con filtro
  Index Cond: (id_categoria = 1)                         ← sin filtro
```

Sin el filtro, `activo` se evalúa como `Filter` después del acceso al índice,
recuperando filas inactivas que después se descartan.

## Impacto 3: UNIQUE sigue aplicando a filas dadas de baja

La restricción `cliente_email_key UNIQUE (email)` en `cliente` no "apaga" su
acción sobre filas lógicamente borradas. **Un email de un cliente dado de baja
sigue ocupado**: no se puede crear un nuevo cliente con ese mismo email hasta
que se elimine físicamente o se libere el email con un `UPDATE`.

En el esquema actual esto no se manifiesta como bug porque `cliente` no tiene
columna `activo`. Pero es la **trampa clásica del soft delete**: si en el
futuro se agrega `activo` a `cliente` junto al `UNIQUE(email)`, será necesario
decidir si el UNIQUE debe ser:

```sql
-- Opción A: UNIQUE simple (impide reusar emails de clientes dados de baja)
UNIQUE (email);

-- Opción B: UNIQUE parcial (solo sobre filas activas, permite reusar emails)
CREATE UNIQUE INDEX uq_cliente_email_activo ON cliente (email) WHERE activo = TRUE;
```

La opción B es la habitual en esquemas con soft delete, pero **cambia el
comportamiento de negocio** y debe decidirse con el responsable funcional, no
imponerse técnicalemente. Hoy el esquema usa la opción A (UNIQUE simple) y no
hay conflicto porque no hay columna `activo` en `cliente`.

## Resumen de reglas para este esquema

1. **Toda consulta de reportes/catálogos** debe incluir `WHERE activo = TRUE`
   en `producto` y `categoria`, o usar una vista que ya lo haga.
2. **Los índices parciales** (`WHERE activo = TRUE`) solo se usan si la consulta
   incluye ese predicado — si no, el optimizador los ignora y cae a Seq Scan.
3. **Nunca `DELETE` físico** en el flujo de negocio: usar `UPDATE ... SET activo = FALSE`.
4. **Las FK con `ON DELETE RESTRICT`** protegen el histórico: no se puede borrar
   un producto/categoría que tenga pedidos, incluso si está inactivo.
5. **El trigger del script 14** cierra el circuito: aunque un producto esté en
   la tabla, si `activo = FALSE` no puede entrar en un nuevo `detalle_pedido`.
6. **UNIQUE y soft delete** deben evaluarse juntos si se agrega `activo` a una
   tabla con restricción UNIQUE en el futuro.

## Evidencia reproducible

```sql
-- 1. Conteo con y sin filtro
SELECT count(*) AS total,
       count(*) FILTER (WHERE activo) AS activos,
       count(*) FILTER (WHERE NOT activo) AS inactivos
FROM producto;

-- 2. Vista vs consulta cruda
SELECT count(*) FROM vw_tp5_productos_vigentes_categoria;   -- 47.434
SELECT count(*) FROM producto pr JOIN categoria c ON c.id_categoria = pr.id_categoria;  -- 50.000

-- 3. Índice parcial: rendimiento con y sin el filtro
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre FROM producto
WHERE activo = TRUE AND nombre ILIKE '%Producto 123%';       -- 2,2 ms, Bitmap Index Scan

EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre FROM producto
WHERE nombre ILIKE '%Producto 123%';                          -- 18,1 ms, Seq Scan

-- 4. Trigger: insert con producto inactivo falla (script 14)
```
