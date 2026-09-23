# Informe Técnico — Resumen de lo actuado

Base de Datos II — Food Store
Motor: PostgreSQL 18.6 (Windows)
Repositorio: `DB_Moron_Menendez`

---

## 1. Elementos implementados en cada unidad

### Unidad 1 — Modelado, integridad y concurrencia

| Elemento | Archivo |
|----------|---------|
| Modelo Entidad-Relación (entidades, claves, cardinalidad, participación) con diagrama Mermaid | `docs/modelo_er.md` |
| Paso de ER a modelo relacional (1:N con FK, N:M con tabla intermedia `detalle_pedido`) | `docs/er_a_relacional.md` |
| Normalización hasta 3FN/BCNF con dependencias funcionales justificadas | `docs/normalizacion.md` |
| DDL completo: tipo `forma_pago_enum`, 5 tablas con PKs `IDENTITY`, 4 FKs `ON DELETE RESTRICT`, CHECKs e índices | `db/schema.sql` |
| Restricciones reforzadas: `precio_lista > 0`, `btrim(nombre) <> ''`, `precio_unitario > 0` | `db/sql/01_restricciones_integridad.sql` |
| Pruebas de restricciones con casos válidos e inválidos protegidos por `SAVEPOINT` | `db/sql/02_pruebas_restricciones.sql` |
| Laboratorio de concurrencia: 3 escenarios en dos sesiones (lectura no repetible, lectura fantasma, bloqueo con `FOR UPDATE` + `lock_timeout`) comparando `READ COMMITTED` y `REPEATABLE READ` | `db/sql/03_laboratorio_concurrencia.sql` |
| Protocolo de seguridad: verificación de conexión, respaldo con `pg_dump`, plantillas, reglas de `BEGIN`/`ROLLBACK` | `docs/protocolo_seguridad.md` |
| Informe de concurrencia con evidencia real del motor | `docs/informe_concurrencia.md` |
| Lectura crítica de dos patrones SQL riesgosos (`UPDATE` masivo sin condición de negocio y `NOT IN` con `NULL`) | `docs/ejercicio_lectura_critica.md` |
| Borrado lógico: patrón `activo` en `categoria` y `producto`, con su impacto en consultas e índices | `docs/borrado_logico.md` |

### Unidad 2 — Optimización de consultas y analíticas asistidas por IA

| Elemento | Archivo |
|----------|---------|
| Carga masiva: 20.000 clientes, 50.000 productos, 200.000 pedidos, 600.000 detalles + `ANALYZE` | `db/sql/04_carga_masiva.sql` |
| Mediciones `EXPLAIN ANALYZE` antes/después de 3 consultas lentas con índices propuestos por IA | `docs/parte2_tabla_comparativa.md` |
| Lectura crítica de plan interpretado por IA (detectó omisión de recheck y filtración post-índice) | `docs/parte3_lectura_critica.md` |
| Consultas resumen con especificación precisa, versiones alternativas y verificación `EXCEPT` | `db/sql/05_parte4_consultas.sql`, `db/sql/06_parte4_consultas2.sql`, `docs/parte4_consultas_resumen.md` |
| Competencia de optimización: 3 intentos, descarte documentado de propuesta de IA | `docs/parte5_competencia_optimizacion.md` |
| Consultas analíticas con 3+ JOIN: facturación por categoría/mes y ranking de clientes, medición antes/después + índices de cobertura | `db/sql/07_parte1_analiticas.sql`, `docs/parte1_tabla_join_analiticas.md` |
| Lectura crítica de plan con 2 nodos de JOIN (verificó tablas externa/interna y confusión costo/tiempo de la IA) | `docs/parte2_lectura_critica_joins.md` |
| Ranking con `RANK() OVER` y subconsulta correlacionada, con versiones alternativas verificadas por `EXCEPT` | `db/sql/08_parte3_ranking_subconsulta.sql`, `db/sql/09_parte3_verificacion.sql`, `docs/parte3_consultas_analiticas.md` |
| Competencia TP4: baseline vs `work_mem` vs CTE, con análisis de por qué las estrategias no mejoraron | `db/sql/10_parte4_competencia.sql`, `docs/parte4_competencia_tp4.md` |

### Unidad 3 — Índices, vistas y objetos PL/pgSQL

| Elemento | Archivo |
|----------|---------|
| 3 mediciones antes/después de índices (GIN trigram, B-tree compuesto, cobertura `INCLUDE`) con benchmark reversible de escritura | `db/sql/11_tp5_indices_mediciones.sql`, `docs/informe_indices_vistas_tp5.md` |
| 4 vistas simples (incluida una de mínimo privilegio) + vista materializada con índice único para `REFRESH CONCURRENTLY` | `db/sql/12_tp5_views_materializadas.sql` |
| Verificación de equivalencia de vistas por `EXCEPT` en ambos sentidos + medición de la materializada | `db/sql/13_tp5_verificacion_vistas.sql` |
| Función `fn_total_pedido(id)` que calcula el total de un pedido | `db/sql/14_plpgsql_funciones_triggers.sql` |
| Procedimiento `sp_registrar_pedido(cliente, forma_pago, productos[], cantidades[])` que da de alta pedido + líneas de forma atómica | `db/sql/14_plpgsql_funciones_triggers.sql` |
| Trigger `trg_detalle_producto_activo` (`BEFORE INSERT OR UPDATE`) que implementa la regla de negocio de no facturar productos inactivos | `db/sql/14_plpgsql_funciones_triggers.sql` |
| Specs de planificación en formato Kiro (requirements, diseño, tareas) | `.kiro/specs/tp5_indices_vistas/` |

---

## 2. Cómo probaron su funcionamiento

1. **Restricciones de integridad** (`02_pruebas_restricciones.sql`): verificación previa de que no existan violaciones, inserción de casos válidos, y provocación de los 3 errores esperados (`precio = 0`, nombre solo espacios, `precio_unitario = 0`) protegidos por `SAVEPOINT`/`ROLLBACK TO SAVEPOINT`, cerrando con `ROLLBACK` para no dejar filas.
2. **Concurrencia** (`03_laboratorio_concurrencia.sql`): dos sesiones `psql` independientes sobre `food_store_tp2`, con marcador único compartido, semilla transaccional y limpieza final. Cada escenario se ejecutó en `READ COMMITTED` y `REPEATABLE READ`.
3. **Optimización** (scripts 04, 07, 11): `EXPLAIN (ANALYZE, BUFFERS)` antes de cualquier cambio, aplicación de índices propuestos por IA tras revisar línea por línea la justificación contra el nodo del plan, y nueva medición después.
4. **Equivalencia de consultas y vistas** (scripts 05, 06, 09, 13): cada par de versiones (IA vs propia, vista vs consulta manual) se verificó con `EXCEPT` en ambos sentidos; el resultado esperado era `0 filas` en cada dirección.
5. **PL/pgSQL** (script 14): ejecución en `food_store_tp5` con datos reales de carga masiva, todo dentro de `BEGIN`/`ROLLBACK`; se provocaron los errores esperados (producto inactivo, arrays de distinta longitud) y se verificó la existencia de funciones, procedimientos y triggers contra `information_schema`.
6. **Borrado lógico**: consultas con y sin `WHERE activo = TRUE` sobre la misma base, con `EXPLAIN ANALYZE` para comparar el uso del índice parcial y el conteo de filas.

---

## 3. Resultados obtenidos

### Unidad 1

- **3 restricciones CHECK** aplicadas y verificadas en `pg_constraint`; los 3 errores de prueba se produjeron con el mensaje esperado y los `SAVEPOINT` revirtieron sin abortar la transacción exterior.
- **Concurrencia reproducida con evidencia real del motor:**

| Escenario | READ COMMITTED | REPEATABLE READ |
|-----------|----------------|-----------------|
| Lectura no repetible (`precio_lista`) | Lectura 1 = 10,00 → Lectura 2 = 20,00 | Lectura 1 = 10,00 → Lectura 2 = 10,00 |
| Lectura fantasma (conteo de activos) | Conteo 1 = 2 → Conteo 2 = 3 | Conteo 1 = 2 → Conteo 2 = 2 |
| Bloqueo `FOR UPDATE` | Sesión B recibió `ERROR: ... lock_timeout` tras 5s | — |

- **Borrado lógico:** 47.434 productos activos de 50.000 (2.566 dados de baja). La vista vigente devuelve 47.434 filas; la consulta cruda sin filtro devuelve 50.000.

### Unidad 2

- **Carga masiva:** 8 categorías, 20.000 clientes, 50.000 productos, 200.000 pedidos, 600.000 detalles, con `ANALYZE` de las 5 tablas.
- **Consultas resumen:** 8 filas equivalentes en ambas versiones (`EXCEPT` = 0 en ambos sentidos) para facturación por categoría y para productos sobre el promedio de su categoría.
- **Ranking con ventana:** top 20 calculado con `RANK()` global y particionado por forma de pago; equivalencia confirmada (`v1 solo = 0`, `v2 solo = 0`).
- **Competencia TP4:** ganó el baseline con índices de cobertura (1.219 ms); `work_mem = 128MB` y la reescritura con CTE no mejoraron (1.233 ms y 1.255 ms) porque el cuello de botella es el `Seq Scan` de 600k filas, no la memoria temporal.

### Unidad 3

- **Índices TP5** (sobre `food_store_tp5`, corrida real):

| Consulta | Índice | Antes | Después | Mejora |
|----------|--------|-------|---------|--------|
| Búsqueda textual `ILIKE` + precio | GIN trigram parcial | 24.177 ms (Seq Scan) | 1.687 ms (Bitmap Index Scan) | **14,3x** |
| Pedidos por forma de pago + fecha | B-tree compuesto | 29.894 ms (Parallel Seq Scan) | 3.333 ms (Bitmap Index Scan) | **9,0x** |
| Historial de un producto | Cobertura `INCLUDE` | 129.277 ms (Parallel Seq Scan) | 0,130 ms (Index Only Scan) | **994x** |
| INSERT de 500 detalles | Los 3 índices | 9,165 ms | 10,064 ms | +9,8% (costo de mantenimiento) |

- **Vistas:** las 4 vistas y la materializada dieron `solo_vista = 0` y `solo_manual = 0` en la verificación por `EXCEPT`.
- **Vista materializada:** consulta original 1.591–1.647 ms vs lectura de la materializada **0,015 ms**; `REFRESH MATERIALIZED VIEW CONCURRENTLY` ejecutado correctamente gracias al índice único `(id_categoria, mes)`.
- **PL/pgSQL:** `fn_total_pedido` devolvió totales reales (p. ej. pedido 1 = 36.288,48) y `0,00` con `NOTICE` para pedido inexistente; `sp_registrar_pedido` registró un pedido de 2 líneas (total 9.094,29) revirtido al final; el trigger bloqueó con `ERROR: Regla de negocio...` el insert de un producto inactivo y permitió el de un producto activo.
- **Borrado lógico e índices:** con `WHERE activo = TRUE` el GIN parcial rinde 2,168 ms (Bitmap Index Scan); sin el filtro cae a Seq Scan en 18,075 ms — **8,3x más lento**.

---

## 4. Consultas optimizadas y diferencias antes/después

### Semana 3 (Unidad 2) — optimización de consultas simples

| Consulta | Cambio aplicado | Antes | Después | Diferencia |
|----------|-----------------|-------|---------|------------|
| Productos por `ILIKE` + rango de precio | `idx_producto_nombre_trgm` (GIN `pg_trgm`) | 18.640 ms, Seq Scan | 2.339 ms, Bitmap Heap Scan | **8x** |
| Pedidos por forma de pago + fecha, con total | `idx_pedido_forma_pago_fecha` (B-tree) | 179.388 ms | 175.863 ms | ~2% (el `HashAggregate` sobre 600k filas domina) |
| Top 20 productos vendidos con categoría | `idx_detalle_producto_cantidad` (`INCLUDE`) | 350.139 ms | 338.628 ms | ~3% (el plan no cambió: el optimizador prefiere `Seq Scan` para agregación completa) |

### Semana 4 (Unidad 2) — analíticas con múltiples JOIN

| Consulta | Algoritmo de join (antes y después) | Antes | Después | Diferencia |
|----------|--------------------------------------|-------|---------|------------|
| Facturación por categoría y mes (3 JOIN) | Hash Join × 3 (sin cambio) | 1.282 ms | 1.219 ms | **5%** |
| Ranking de clientes por gasto (2 JOIN) | Hash Join × 2 (sin cambio) | 2.584 ms | 2.598 ms | ~0% (índice no usado: el optimizador necesita `Seq Scan` para el `GROUP BY`) |

**Análisis:** en ambas analíticas el optimizador eligió `Hash Join` porque las tablas de dimensión (8 / 50k / 20k filas) caben en memoria. El cuello de botella real es el `Seq Scan` de 600k filas en `detalle_pedido` y el sort externo a disco (26–57 MB).

### Semana 5 (Unidad 3) — índices TP5

| Consulta | Índice | Antes | Después | Diferencia |
|----------|--------|-------|---------|------------|
| `ILIKE '%Producto 123%'` + precio | GIN trigram parcial `WHERE activo = TRUE` | 24.177 ms, Seq Scan | 1.687 ms, Bitmap Index Scan | **14,3x** |
| Pedidos `TARJETA` últimos 30 días | B-tree `(forma_pago, fecha DESC)` | 29.894 ms, Parallel Seq Scan | 3.333 ms, Bitmap Index Scan | **9,0x** |
| Historial de un producto | Cobertura `(id_producto, id_pedido) INCLUDE (...)` | 129.277 ms, Parallel Seq Scan | 0,130 ms, Index Only Scan | **994x** |

### Estrategias descartadas (con motivo documentado)

| Propuesta | Origen | Motivo del descarte |
|-----------|--------|---------------------|
| Índice B-tree sobre `producto(activo)` | IA | Baja cardinalidad (booleano) y ya cubierto por `idx_producto_categoria_activo`; no resuelve el `ILIKE` |
| Índice en `pedido(id_cliente)` para el ranking | IA | El optimizador prefiere `Seq Scan` sobre 200k filas para armar el Hash table completo del `GROUP BY` |
| Tabla resumen precalculada para la competencia | IA | La consigna pide una consulta, no un objeto de esquema; además quedaría desactualizada |
| `SET work_mem = '128MB'` | Propia | Eliminó los spills a disco pero no redujo el tiempo: el 90% del costo es el `Seq Scan` y la agregación |
| Reescritura con CTE preagregado | Propia | PostgreSQL 12+ inlinea los CTE y genera el mismo plan |

---

## 5. Herramientas de IA utilizadas

Se utilizaron exclusivamente las herramientas indicadas por la cátedra: **OpenCode** y **Kiro**. No se emplearon otras herramientas de IA adicionales.

El detalle de cada uso (prompt, decisión de aceptar o descartar) está registrado en las bitácoras de uso de IA:

| Bitácora | Alcance |
|----------|---------|
| `docs/duia_parte_1.md` | Restricciones de integridad y pruebas transaccionales |
| `docs/duia_parte_2.md` | Laboratorio de concurrencia en dos sesiones |
| `docs/duia_parte_3.md` | Informe de concurrencia y lectura crítica |
| `docs/duia_tp3.md` | Carga masiva, optimización de 3 consultas, lectura de plan, consultas resumen, competencia |
| `docs/duia_tp4.md` | Índices para analíticas, lectura de plan con JOINs, ranking con ventana, subconsultas, competencia |
| `docs/duia_tp5.md` | Specs en formato Kiro, generación/revisión de SQL, evaluación de sobreindexación |

**Decisiones representativas tomadas por el estudiante sobre propuestas de IA:**

- **Aceptado:** índice GIN trigram (8x y 14,3x de mejora), índice B-tree compuesto de forma de pago/fecha (9x), cobertura `INCLUDE` para historial (994x), reescrituras de consultas verificadas con `EXCEPT`.
- **Descartado:** B-tree aislado sobre `activo` (redundante), índice en `pedido(id_cliente)` para ranking (no usado por el optimizador), tabla resumen precalculada (no es una consulta), `work_mem` alto y reescritura con CTE (sin mejora medida), explicaciones de IA sobre planes con imprecisiones corregidas contra el `EXPLAIN ANALYZE` real (confusión costo/tiempo, omisión de recheck, atribución errónea de la elección de Hash Join a la falta de índices).
