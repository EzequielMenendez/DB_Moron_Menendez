-- ====================================================================
-- Carga Masiva - Food Store (Semana 3 / Parte 1)
-- 20.000 clientes, 50.000 productos, 200.000 pedidos con detalles
-- ====================================================================

BEGIN;

-- Categorias base
INSERT INTO categoria (nombre, descripcion, activo)
SELECT cat, 'Categoria generada para prueba masiva ' || cat, TRUE
FROM unnest(ARRAY['Pizzas','Bebidas','Empanadas','Postres','Ensaladas','Burgers','Cafeteria','Minutas']) AS cat
WHERE NOT EXISTS (SELECT 1 FROM categoria);

-- 20.000 clientes
INSERT INTO cliente (nombre, apellido, email, telefono)
SELECT
    'Nombre' || i,
    'Apellido' || i,
    'cliente_' || i || '@ejemplo.invalid',
    '555-' || lpad(i::text, 6, '0')
FROM generate_series(1, 20000) AS i;

-- 50.000 productos
INSERT INTO producto (nombre, descripcion, precio_lista, stock, activo, id_categoria)
SELECT
    'Producto ' || i,
    'Descripcion del producto numero ' || i,
    trunc((random() * 4500 + 500)::numeric, 2),
    floor(random() * 201)::int,
    (random() > 0.05),
    (SELECT id_categoria FROM categoria ORDER BY random() LIMIT 1)
FROM generate_series(1, 50000) AS i;

-- 200.000 pedidos
INSERT INTO pedido (fecha, id_cliente, forma_pago)
SELECT
    now() - (random() * interval '365 days'),
    (floor(random() * (SELECT count(*) FROM cliente) + (SELECT min(id_cliente) FROM cliente)))::bigint,
    (ARRAY['EFECTIVO'::forma_pago_enum, 'TARJETA'::forma_pago_enum, 'TRANSFERENCIA'::forma_pago_enum])[floor(random() * 3 + 1)]
FROM generate_series(1, 200000) AS s;

-- Detalles de pedidos (600.000). La serie depende de cada pedido para
-- distribuir las ventas entre productos; una subconsulta LATERAL sin esa
-- correlacion puede evaluarse una sola vez y concentrar toda la carga.
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT
    p.id_pedido,
    pr.id_producto,
    (floor(random() * 5 + 1))::int,
    pr.precio_lista
FROM pedido p
CROSS JOIN LATERAL generate_series(1, 3) AS linea(numero)
JOIN producto pr ON pr.id_producto =
    (((p.id_pedido * 104729 + linea.numero * 7919 - 1) % 50000) + 1);

COMMIT;

ANALYZE cliente;
ANALYZE categoria;
ANALYZE producto;
ANALYZE pedido;
ANALYZE detalle_pedido;
