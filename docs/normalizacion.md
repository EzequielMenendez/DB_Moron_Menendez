# Normalización hasta 3FN/BCNF — Food Store

Documento verificado contra `db/schema.sql` y `db/sql/01_restricciones_integridad.sql`.

## Dependencias funcionales (DF)

Notación: `X → Y` significa "X determina funcionalmente a Y".

### CLIENTE

| DF | Justificación |
|----|---------------|
| `id_cliente → nombre, apellido, email, telefono` | El id identifica de forma única al cliente |
| `email → id_cliente, nombre, apellido, telefono` | `email` tiene restricción UNIQUE, también identifica al cliente (clave candidata alternativa) |

Claves candidatas: `{id_cliente}` (primaria), `{email}` (alternativa).

### CATEGORIA

| DF | Justificación |
|----|---------------|
| `id_categoria → nombre, descripcion, activo` | El id identifica de forma única a la categoría |

Clave candidata: `{id_categoria}`.

### PRODUCTO

| DF | Justificación |
|----|---------------|
| `id_producto → nombre, descripcion, precio_lista, stock, activo, id_categoria` | El id identifica de forma única al producto |
| `id_categoria → (nada que no dependa ya de la PK)` | Una categoría no determina un producto individual (1:N) |

Clave candidata: `{id_producto}`.

### PEDIDO

| DF | Justificación |
|----|---------------|
| `id_pedido → fecha, id_cliente, forma_pago` | El id identifica de forma única al pedido |
| `id_cliente → (nada)` | Un cliente no determina un pedido individual (1:N) |

Clave candidata: `{id_pedido}`.

### DETALLE_PEDIDO

| DF | Justificación |
|----|---------------|
| `(id_pedido, id_producto) → cantidad, precio_unitario` | La pareja identifica la línea del pedido |
| `id_pedido → (nada sin id_producto)` | Un pedido tiene muchas líneas |
| `id_producto → (nada sin id_pedido)` | Un producto aparece en muchos pedidos |

Clave candidata: `{id_pedido, id_producto}` (compuesta).

**Nota sobre `precio_unitario`:** Podría parecer que `id_producto → precio_unitario`
(dado el producto, su precio), pero no es así: `precio_unitario` es el precio al
momento de la venta y puede variar entre pedidos para el mismo producto. Por lo
tanto depende de la pareja completa `(id_pedido, id_producto)`, no solo de
`id_producto`. Si dependiera solo de `id_producto`, habría una dependencia
parcial (violación de 2FN).

## Verificación por niveles

### 1FN — Forma normal de primer orden

**Regla:** Todos los atributos deben ser atómicos (sin columnas repetidas ni conjuntos).

| Tabla | ¿Cumple? | Verificación |
|-------|----------|--------------|
| `cliente` | ✅ | Todos los atributos son escalares; `telefono` es un solo valor |
| `categoria` | ✅ | Todos escalares |
| `producto` | ✅ | Todos escalares |
| `pedido` | ✅ | `forma_pago` es un ENUM de valores simples |
| `detalle_pedido` | ✅ | Todos escalares |

No hay atributos multivaluados ni compuestos. **1FN cumplida en todas.**

### 2FN — Forma normal de segundo orden

**Regla:** Sin dependencias parciales (ningún atributo no clave debe depender
de una *parte* de la clave compuesta).

Solo `detalle_pedido` tiene clave compuesta, así que es la única tabla a evaluar:

| Atributo no clave | ¿Depende de la PK completa o de una parte? |
|-------------------|--------------------------------------------|
| `cantidad` | Depende de la pareja `(id_pedido, id_producto)` — la cantidad es de esa línea específica. **Depende de la PK completa.** ✅ |
| `precio_unitario` | Depende de la pareja `(id_pedido, id_producto)` — es el precio al momento de esa venta concreta. **Depende de la PK completa.** ✅ |

Las demás tablas tienen PK de un solo atributo, por lo que 2NF es trivial.

**2NF cumplida:** no hay dependencias parciales.

### 3FN — Forma normal de tercer orden

**Regla:** Sin dependencias transitivas (ningún atributo no clave debe
depender de otro atributo no clave).

| Tabla | ¿Hay dependencia transitiva? | Verificación |
|-------|------------------------------|--------------|
| `cliente` | No ✅ | `nombre`, `apellido`, `telefono` dependen de `id_cliente` directamente. `email` es clave candidata, no un atributo dependiente transitivo. |
| `categoria` | No ✅ | `nombre`, `descripcion`, `activo` dependen de `id_categoria` directamente. |
| `producto` | No ✅ | `id_categoria` es FK (depende de la PK), pero `precio_lista`, `stock`, `activo` no dependen de `id_categoria` sino de `id_producto`. No hay cadena `PK → id_categoria → (otro atributo de producto)`. |
| `pedido` | No ✅ | `fecha`, `id_cliente`, `forma_pago` dependen de `id_pedido` directamente. |
| `detalle_pedido` | No ✅ | `cantidad`, `precio_unitario` dependen de la PK compuesta directamente. |

**3NF cumplida:** no hay dependencias transitivas en ninguna tabla.

### BCNF (Boyce-Codd)

**Regla:** En toda dependencia funcional `X → Y`, `X` debe ser superclave
(es decir, cada determinante debe ser clave candidata).

| Tabla | Determinantes encontrados | ¿Es superclave? |
|-------|---------------------------|-----------------|
| `cliente` | `id_cliente`, `email` | Ambos son claves candidatas ✅ |
| `categoria` | `id_categoria` | PK ✅ |
| `producto` | `id_producto` | PK ✅ |
| `pedido` | `id_pedido` | PK ✅ |
| `detalle_pedido` | `(id_pedido, id_producto)` | PK compuesta ✅ |

No existen dependencias funcionales triviales en las que el determinante no sea
superclave (por ejemplo, no hay `id_categoria → nombre` siendo `id_categoria`
no-clave en otra tabla). **BCNF cumplida.**

## Resumen

| Nivel | ¿Se cumple? | Motivo |
|-------|-------------|--------|
| 1FN | ✅ Sí | Atributos atómicos en todas las tablas |
| 2FN | ✅ Sí | Sin dependencias parciales (PK de `detalle_pedido` es compuesta y todo depende de ella completa) |
| 3FN | ✅ Sí | Sin dependencias transitivas (las FK dependen de la PK, no hay cadenas entre no-claves) |
| BCNF | ✅ Sí | Todo determinante es superclave (PK o clave candidata) |

**El esquema Food Store está en 3FN y BCNF.**
