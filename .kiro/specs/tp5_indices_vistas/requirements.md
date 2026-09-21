# Requirements - TP5 indices, vistas y vista materializada

## Alcance

El TP agrega objetos de consulta al esquema Food Store existente sin cambiar tablas,
tipos, restricciones ni datos de las tablas base. Se trabaja sobre una copia de
laboratorio con la carga masiva.

## Criterios de aceptacion

1. Medir con `EXPLAIN (ANALYZE, BUFFERS)` antes y despues tres consultas frecuentes:
   busqueda textual de productos vigentes, pedidos por medio de pago/fecha e historial
   de un producto.
2. Aceptar solo los tres indices que atacan el predicado de cada consulta y registrar
   el costo de insertar 500 filas en `detalle_pedido` antes y despues.
3. Rechazar por escrito el B-tree aislado sobre `producto(activo)` por baja cardinalidad.
4. Exponer vistas para productos vigentes, pedidos con cliente y detalle de pedido;
   agregar una vista de minimo privilegio para clientes.
5. Crear la vista materializada de facturacion por categoria y mes con `WITH DATA` e
   indice unico apto para `REFRESH MATERIALIZED VIEW CONCURRENTLY`.
6. Verificar cada vista y la materializada contra su consulta manual con `EXCEPT` en
   ambos sentidos.
