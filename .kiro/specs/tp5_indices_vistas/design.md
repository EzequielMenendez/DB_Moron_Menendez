# Design - TP5 indices, vistas y vista materializada

## Indices

- `idx_tp5_producto_nombre_trgm`: GIN parcial sobre `producto.nombre` para `ILIKE`
  con comodin inicial; la condicion `activo = TRUE` coincide con la consulta.
- `idx_tp5_pedido_forma_pago_fecha`: B-tree compuesto para igualdad en
  `forma_pago` y rango/orden descendente en `fecha`.
- `idx_tp5_detalle_producto_cobertura`: B-tree que empieza por `id_producto`,
  opuesto a la PK `(id_pedido, id_producto)`, con columnas de lectura incluidas.

## Vistas

Las vistas tienen nombres `vw_tp5_*` y columnas explicitas. El modelo heredado
usa `cliente` y no tiene una columna de contrasena; por eso la vista de minimo
privilegio omite los datos de contacto, sin inventar una tabla o columna.

La materializada agrupa por `id_categoria` y mes. Esa clave es unica y permite
refresco concurrente fuera de una transaccion. El reporte puede refrescarse cada
hora: entre refrescos muestra un snapshot, no ventas en tiempo real.

## Verificacion y seguridad

Los scripts se ejecutan en una base creada para el TP. Las inserciones de
benchmark quedan dentro de `BEGIN`/`ROLLBACK`; no quedan filas de prueba.
No se guardan contrasenas ni cadenas de conexion en el repositorio.
