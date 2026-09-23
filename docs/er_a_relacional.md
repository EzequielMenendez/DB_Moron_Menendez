# Paso de ER a Modelo Relacional — Food Store

Documento derivado de `docs/modelo_er.md` y verificado contra `db/schema.sql`.

## Reglas de transformación aplicadas

| Regla ER | Aplicación en Food Store |
|----------|--------------------------|
| Cada entidad → una tabla | `CLIENTE`, `CATEGORIA`, `PRODUCTO`, `PEDIDO` |
| Cada atributo → una columna | Todos los atributos del modelo ER |
| Clave primaria de la entidad → PK de la tabla | `id_cliente`, `id_categoria`, `id_producto`, `id_pedido` |
| Relación **1:N** → FK en el lado "N" | `producto.id_categoria`, `pedido.id_cliente` |
| Relación **N:M** → tabla intermedia | `detalle_pedido` entre `pedido` y `producto` |
| Atributo multivalorado → tabla aparte | No hay (todos los atributos son monovalorados) |
| Atributo derivado → no se persiste | `subtotal` se calcula, no se guarda (se expone en la vista `vw_tp5_detalle_pedido_producto`) |
| Tipos de dominio → tipos SQL | `forma_pago_enum` como ENUM, `BOOLEAN` para `activo`, `NUMERIC(12,2)` para montos |

## Transformación de cada relación

### Relación 1:N — CLIENTE → PEDIDO ("realiza")

**En ER:** Un cliente realiza muchos pedidos; un pedido es realizado por un solo cliente.

**En relacional:** Se coloca la FK en el lado "N" (`pedido`), que es el lado que tiene muchas instancias por cada instancia del lado "1".

```sql
CREATE TABLE pedido (
    id_pedido  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    id_cliente BIGINT NOT NULL,                -- FK al lado "1"
    forma_pago forma_pago_enum NOT NULL,
    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente)
        ON DELETE RESTRICT
);
```

**Justificación:** Cada fila de `pedido` referencia exactamente un `cliente`.
No se pone una lista de pedidos en `cliente` porque eso crearía una columna
multivalorida (violación de 1FN).

### Relación 1:N — CATEGORIA → PRODUCTO ("agrupa")

**En ER:** Una categoría agrupa muchos productos; un producto pertenece a una sola categoría.

**En relacional:** FK en `producto` (lado "N").

```sql
CREATE TABLE producto (
    id_producto  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ...
    id_categoria BIGINT NOT NULL,              -- FK al lado "1"
    CONSTRAINT fk_producto_categoria
        FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria)
        ON DELETE RESTRICT
);
```

### Relación N:M — PEDIDO ↔ PRODUCTO (resuelta con tabla intermedia)

**En ER:** Un pedido incluye muchos productos; un producto aparece en muchos pedidos.

**En relacional:** Se crea la tabla intermedia `detalle_pedido` con:
- Las PK de ambas entidades como **FK compuesta** que forma su propia PK
- Los atributos de la relación (`cantidad`, `precio_unitario`) como columnas propias

```sql
CREATE TABLE detalle_pedido (
    id_pedido      BIGINT NOT NULL,
    id_producto    BIGINT NOT NULL,
    cantidad       INTEGER NOT NULL,
    precio_unitario NUMERIC(12,2) NOT NULL,
    CONSTRAINT pk_detalle_pedido PRIMARY KEY (id_pedido, id_producto),
    CONSTRAINT fk_detalle_pedido_pedido
        FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido) ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_pedido_producto
        FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT
);
```

**Justificación de la PK compuesta:** La pareja `(id_pedido, id_producto)` es
única porque un mismo producto no se repite dos veces en un mismo pedido (la
cantidad acumulada en una sola fila). Esto identifica de forma única cada línea.

**Justificación de `precio_unitario`:** Es un atributo de la relación (no del
producto): captura el precio al momento de la venta, que puede diferir de
`producto.precio_lista` si el precio cambió después. Por eso no se referencia
a `producto.precio_lista` con FK sino que se copia el valor.

## Resumen de la transformación

| Entidad/Relación ER | Tabla relacional | PK | FK recibidas |
|---------------------|------------------|----|--------------| 
| CLIENTE | `cliente` | `id_cliente` | — |
| CATEGORIA | `categoria` | `id_categoria` | — |
| PRODUCTO | `producto` | `id_producto` | `id_categoria` → categoria |
| PEDIDO | `pedido` | `id_pedido` | `id_cliente` → cliente |
| N:M PEDIDO ↔ PRODUCTO | `detalle_pedido` (intermedia) | `(id_pedido, id_producto)` | `id_pedido` → pedido, `id_producto` → producto |

## Verificación de que no se perdió información

- Toda entidad del ER tiene tabla: 5/5 ✓
- Toda relación 1:N tiene FK en el lado N: 2/2 ✓
- Toda relación N:M tiene tabla intermedia: 1/1 ✓
- Ningún atributo multivalorado quedó comprimido en una columna: no hay ✓
- Los atributos derivados no se persisten: `subtotal` se calcula en la vista ✓
