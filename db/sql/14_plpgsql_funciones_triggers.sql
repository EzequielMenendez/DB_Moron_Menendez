-- ====================================================================
-- TP: PL/pgSQL - funciones, procedimientos almacenados y triggers
-- Ejecutar en una copia de laboratorio ya cargada con schema.sql
-- y 04_carga_masiva.sql (por ejemplo, food_store_tp5).
-- Las demostraciones usan BEGIN/ROLLBACK: no dejan datos persistentes.
-- ====================================================================
\set ON_ERROR_STOP off

-- ====================================================================
-- 1. FUNCION: total de un pedido
-- ====================================================================

CREATE OR REPLACE FUNCTION fn_total_pedido(p_id_pedido BIGINT)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_total NUMERIC(12,2);
BEGIN
    SELECT COALESCE(sum(cantidad * precio_unitario), 0)
    INTO v_total
    FROM detalle_pedido
    WHERE id_pedido = p_id_pedido;

    IF v_total = 0 THEN
        RAISE NOTICE 'El pedido % no existe o no tiene lineas.', p_id_pedido;
    END IF;

    RETURN v_total;
END;
$$;

\echo '=== DEMO funcion fn_total_pedido ==='
BEGIN;
-- Tomamos un pedido real con lineas
SELECT dp.id_pedido,
       count(*) AS lineas,
       fn_total_pedido(dp.id_pedido) AS total
FROM detalle_pedido dp
GROUP BY dp.id_pedido
ORDER BY dp.id_pedido
LIMIT 3;

-- Pedido inexistente: devuelve 0 y emite NOTICE
SELECT fn_total_pedido(-1) AS pedido_inexistente;
ROLLBACK;

-- ====================================================================
-- 2. PROCEDIMIENTO ALMACENADO: registrar pedido con sus lineas
--    Recibe arrays de productos y cantidades; usa precio_lista del
--    producto como precio_unitario. La atomicidad la garantiza la
--    transaccion que lo invoca (BEGIN ... CALL ... COMMIT/ROLLBACK).
-- ====================================================================

CREATE OR REPLACE PROCEDURE sp_registrar_pedido(
    p_id_cliente BIGINT,
    p_forma_pago forma_pago_enum,
    p_productos  BIGINT[],
    p_cantidades INTEGER[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_pedido BIGINT;
    i INTEGER;
    v_precio NUMERIC(12,2);
    v_activo BOOLEAN;
BEGIN
    -- Validacion de cardinalidad de arrays
    IF array_length(p_productos, 1) IS NULL
       OR array_length(p_productos, 1) <> array_length(p_cantidades, 1) THEN
        RAISE EXCEPTION 'Los arrays de productos y cantidades deben tener la misma longitud no nula.';
    END IF;

    -- Validacion de cliente vigente
    PERFORM 1 FROM cliente WHERE id_cliente = p_id_cliente;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cliente % no existe.', p_id_cliente;
    END IF;

    -- Alta del pedido
    INSERT INTO pedido (id_cliente, forma_pago)
    VALUES (p_id_cliente, p_forma_pago)
    RETURNING id_pedido INTO v_id_pedido;

    -- Alta de cada linea
    FOR i IN 1 .. array_length(p_productos, 1) LOOP
        SELECT precio_lista, activo
        INTO v_precio, v_activo
        FROM producto
        WHERE id_producto = p_productos[i]
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'El producto % no existe.', p_productos[i];
        END IF;

        -- El trigger trg_detalle_producto_activo tambien valida esto;
        -- la comprobacion aqui da un mensaje mas especifico antes.
        IF NOT v_activo THEN
            RAISE EXCEPTION 'El producto % esta inactivo y no puede venderse.', p_productos[i];
        END IF;

        IF p_cantidades[i] <= 0 THEN
            RAISE EXCEPTION 'La cantidad del producto % debe ser positiva.', p_productos[i];
        END IF;

        INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
        VALUES (v_id_pedido, p_productos[i], p_cantidades[i], v_precio);
    END LOOP;

    RAISE NOTICE 'Pedido % registrado con % linea(s).', v_id_pedido, array_length(p_productos, 1);
END;
$$;

\echo '=== DEMO procedimiento sp_registrar_pedido ==='
-- CALL no admite subconsultas en argumentos: se resuelven con \gset
SELECT min(id_cliente) AS id_cli FROM cliente \gset
SELECT array_agg(id_producto ORDER BY id_producto) AS prods
FROM (SELECT id_producto FROM producto WHERE activo = TRUE ORDER BY id_producto LIMIT 2) t \gset

BEGIN;
-- Registrar un pedido valido con 2 lineas (se revierte al final)
CALL sp_registrar_pedido(:id_cli, 'EFECTIVO', :'prods'::bigint[], ARRAY[2, 3]);

-- Verificar que se creo
SELECT p.id_pedido, p.id_cliente, p.forma_pago,
       count(*) AS lineas,
       fn_total_pedido(p.id_pedido) AS total
FROM pedido p
JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
WHERE p.id_cliente = :id_cli
GROUP BY p.id_pedido, p.id_cliente, p.forma_pago
ORDER BY p.id_pedido DESC
LIMIT 1;
ROLLBACK;

-- Caso de error: producto inactivo
SELECT array_agg(id_producto) AS prods_inactivos
FROM (SELECT id_producto FROM producto WHERE activo = FALSE ORDER BY id_producto LIMIT 1) t \gset

BEGIN;
\echo '--- Esperado: error por producto inactivo ---'
CALL sp_registrar_pedido(:id_cli, 'TARJETA', :'prods_inactivos'::bigint[], ARRAY[1]);
ROLLBACK;

-- Caso de error: arrays de distinta longitud
BEGIN;
\echo '--- Esperado: error por arrays de distinta longitud ---'
CALL sp_registrar_pedido(:id_cli, 'EFECTIVO', ARRAY[1, 2], ARRAY[1]);
ROLLBACK;

-- ====================================================================
-- 3. TRIGGER: regla de negocio - no facturar productos inactivos
--    CHECK no puede resolverlo porque requeriria subconsulta a otra
--    tabla, y un CHECK no admite consultas correlacionadas a otras
--    tablas de forma portable. El trigger consulta producto.activo
--    antes de permitir el INSERT en detalle_pedido.
-- ====================================================================

CREATE OR REPLACE FUNCTION fn_trg_producto_activo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_activo BOOLEAN;
BEGIN
    SELECT activo INTO v_activo
    FROM producto
    WHERE id_producto = NEW.id_producto;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto % no existe.', NEW.id_producto;
    END IF;

    IF NOT v_activo THEN
        RAISE EXCEPTION 'Regla de negocio: no se puede vender el producto % porque esta inactivo.',
            NEW.id_producto;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_detalle_producto_activo ON detalle_pedido;
CREATE TRIGGER trg_detalle_producto_activo
    BEFORE INSERT OR UPDATE ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_producto_activo();

\echo '=== DEMO trigger trg_detalle_producto_activo ==='
-- Insert valido: producto activo (se revierte)
SELECT max(id_pedido) AS ult_pedido FROM pedido \gset
SELECT id_producto AS prod_activo FROM producto WHERE activo = TRUE ORDER BY id_producto LIMIT 1 \gset
BEGIN;
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
VALUES (:ult_pedido, :prod_activo, 1, 10.00);
\echo 'Insert con producto activo: OK (se revierte abajo)'
ROLLBACK;

-- Insert invalido: producto inactivo - se espera ERROR
SELECT id_producto AS prod_inactivo FROM producto WHERE activo = FALSE ORDER BY id_producto LIMIT 1 \gset
BEGIN;
\echo '--- Esperado: error del trigger por producto inactivo ---'
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
VALUES (:ult_pedido, :prod_inactivo, 1, 10.00);
ROLLBACK;

\echo '=== Verificacion de objetos creados ==='
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('fn_total_pedido', 'sp_registrar_pedido', 'fn_trg_producto_activo')
ORDER BY routine_name;

SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'trg_detalle_producto_activo';
