# Informe de mediciones - TP5: indices, vistas y vista materializada

## Estado de evidencia

Ejecucion real completada el 2026-09-21 en `food_store_tp5`, PostgreSQL 18.6 local.
La carga genero 20.000 clientes, 50.000 productos, 200.000 pedidos y 600.000
detalles distribuidos entre los 50.000 productos. Los tiempos son una corrida de
laboratorio local: sirven para justificar el plan observado, no como SLA.

## Reproduccion segura

Desde PowerShell, en la raiz del repositorio y con la contrasena solicitada por
PostgreSQL de forma interactiva:

```powershell
$Pg = 'C:\Program Files\PostgreSQL\18\bin'
$Db = 'food_store_tp5'
& "$Pg\createdb.exe" -U postgres $Db
& "$Pg\psql.exe" -U postgres -d $Db -v ON_ERROR_STOP=1 -f db\schema.sql
& "$Pg\psql.exe" -U postgres -d $Db -v ON_ERROR_STOP=1 -f db\sql\04_carga_masiva.sql
& "$Pg\psql.exe" -U postgres -d $Db -v ON_ERROR_STOP=1 -f db\sql\11_tp5_indices_mediciones.sql 2>&1 | Tee-Object docs\evidencia_tp5_indices.txt
& "$Pg\psql.exe" -U postgres -d $Db -v ON_ERROR_STOP=1 -f db\sql\12_tp5_views_materializadas.sql
& "$Pg\psql.exe" -U postgres -d $Db -v ON_ERROR_STOP=1 -f db\sql\13_tp5_verificacion_vistas.sql 2>&1 | Tee-Object docs\evidencia_tp5_vistas.txt
```

La base `food_store_tp5` es exclusiva del TP. No ejecutar estos scripts sobre una
base de produccion ni sobre una base con datos no respaldados.

## Parte A - Plan de indexado

| Consulta | Indice aceptado | Antes: nodo/tiempo | Despues: nodo/tiempo | Estado |
|---|---|---|---|---|
| Q1, productos vigentes por texto y precio | `idx_tp5_producto_nombre_trgm` | Seq Scan, 24,177 ms | Bitmap Heap/Index Scan, 1,687 ms | 14,3x mas rapida |
| Q2, pedidos por forma de pago y fecha | `idx_tp5_pedido_forma_pago_fecha` | Parallel Seq Scan, 29,894 ms | Bitmap Heap/Index Scan, 3,333 ms | 9,0x mas rapida |
| Q3, historial de un producto | `idx_tp5_detalle_producto_cobertura` | Parallel Seq Scan, 129,277 ms | Index Only Scan, 0,130 ms | 994x mas rapida |
| INSERT de 500 detalles | Los tres indices anteriores | 9,165 ms; 1.057 buffers | 10,064 ms; 2.511 buffers | +9,8% y mas mantenimiento |

### Extractos de `EXPLAIN ANALYZE`

Q1 paso de `Seq Scan on producto` con 49.932 filas descartadas a
`Bitmap Index Scan on idx_tp5_producto_nombre_trgm`; los buffers bajaron de 714
a 129.

Q2 paso de `Parallel Seq Scan on pedido` con 97.272 filas descartadas por worker
a `Bitmap Index Scan on idx_tp5_pedido_forma_pago_fecha`; devolvio 5.457 filas.

Q3 paso de `Parallel Seq Scan on detalle_pedido` sobre 600.000 filas a
`Index Only Scan using idx_tp5_detalle_producto_cobertura`, con 12 filas y cero
heap fetches.

La comparacion de escritura se hizo dentro de `BEGIN`/`ROLLBACK`, por lo que no
persistio ninguna fila. Una repeticion controlada, con cache caliente y aislando
el indice de detalle, dio 13,367 ms sin el indice frente a 13,796 ms con el
indice (+3,2%); confirma el costo esperado sin confundirlo con variacion de cache.

### Indice descartado: `producto(activo)`

Se descarta un B-tree aislado sobre `activo`: es booleano, tiene baja
cardinalidad y no resuelve el `ILIKE '%...%'` de Q1. Ademas, la tabla ya posee
`idx_producto_categoria_activo`, cuyo segundo atributo es `activo`. El GIN parcial
aceptado contiene solo productos vigentes y ataca el operador de busqueda real.

## Parte B - Vistas y seguridad

| Objeto | Uso | Equivalencia |
|---|---|---|
| `vw_tp5_productos_vigentes_categoria` | Catalogo de productos/categorias activos | `solo_vista = 0`, `solo_manual = 0` |
| `vw_tp5_pedidos_clientes` | Reporte de pedidos con datos del cliente | `solo_vista = 0`, `solo_manual = 0` |
| `vw_tp5_detalle_pedido_producto` | Detalle valorizado de un pedido | `solo_vista = 0`, `solo_manual = 0` |
| `vw_tp5_clientes_publicos` | Minimo privilegio: oculta email y telefono | Revision de columnas en script |

El esquema heredado no contiene `usuario` ni `contrasena`; modificarlo para copiar
el ejemplo de la consigna rompería el alcance. La vista publica limita los datos
personales que recibe un consumidor de reportes.

## Parte C - Vista materializada

`mv_tp5_facturacion_categoria_mes` se crea con datos y su clave unica
`(id_categoria, mes)` habilita `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

Frecuencia propuesta: cada hora para un dashboard analitico. Durante esa hora, el
usuario ve el ultimo snapshot exitoso; no debe usar ese reporte para confirmar una
venta individual ni stock en tiempo real. La equivalencia dio `solo_vista = 0` y
`solo_manual = 0`. En dos ejecuciones la consulta original tomo entre
**1.591,098 ms** y **1.647,073 ms**, mientras la lectura de la vista materializada
tomo entre **0,015 ms** y **0,016 ms**. Tambien se ejecuto correctamente
`REFRESH MATERIALIZED VIEW CONCURRENTLY`, validando su indice unico.
