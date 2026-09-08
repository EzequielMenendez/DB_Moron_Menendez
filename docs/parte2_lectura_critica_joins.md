# Parte 2 — Lectura crítica de planes de join interpretados por IA

## Plan seleccionado: Consulta 2 (Ranking de clientes por gasto)

### Plan real capturado (ANTES de optimización)

```
Limit  (cost=124483.92..124483.97 rows=20 width=141) (actual time=2574.902..2574.914 rows=20.00 loops=1)
  Buffers: shared hit=1916 read=4224, temp read=16432 written=16450
  ->  Sort  (cost=124483.92..124500.59 rows=6667 width=141) (actual time=2574.899..2574.909 rows=20.00 loops=1)
        Sort Key: (sum(((dp.cantidad)::numeric * dp.precio_unitario))) DESC
        Sort Method: top-N heapsort  Memory: 33kB
        Buffers: shared hit=1916 read=4224, temp read=16432 written=16450
        ->  GroupAggregate  (cost=113473.18..124306.51 rows=6667 width=141) (actual time=2340.156..2571.350 rows=19999.00 loops=1)
              Group Key: cl.email
              Filter: (sum(((dp.cantidad)::numeric * dp.precio_unitario)) > '0'::numeric)
              Buffers: shared hit=1916 read=4224, temp read=16432 written=16450
              ->  Sort  (cost=113473.18..114973.18 rows=600000 width=80) (actual time=2340.120..2434.421 rows=600000.00 loops=1)
                    Sort Key: cl.email, p.id_pedido
                    Sort Method: external merge  Disk: 57568kB
                    Buffers: shared hit=1916 read=4224, temp read=16432 written=16450
                    ->  Hash Join  (cost=7655.00..29226.37 rows=600000 width=80) (actual time=38.003..354.139 rows=600000.00 loops=1)
                          Hash Cond: (p.id_cliente = cl.id_cliente)
                          Buffers: shared hit=1916 read=4224, temp read=2046 written=2046
                          ->  Hash Join  (cost=6948.00..26944.03 rows=600000 width=27) (actual time=33.558..248.448 rows=600000.00 loops=1)
                                Hash Cond: (dp.id_pedido = p.id_pedido)
                                Buffers: shared hit=1659 read=4224, temp read=2046 written=2046
                                ->  Seq Scan on detalle_pedido dp  (cost=0.00..10412.00 rows=600000 width=19) (actual time=0.075..49.787 rows=600000.00 loops=1)
                                      Buffers: shared hit=188 read=4224
                                ->  Hash  (cost=3471.00..3471.00 rows=200000 width=16) (actual time=33.183..33.185 rows=200000.00 loops=1)
                                      Buckets: 262144  Batches: 2  Memory Usage: 6749kB
                                      Buffers: shared hit=1471, temp written=438
                                      ->  Seq Scan on pedido p  (cost=0.00..3471.00 rows=200000 width=16) (actual time=0.011..11.918 rows=200000.00 loops=1)
                                            Buffers: shared hit=1471
                          ->  Hash  (cost=457.00..457.00 rows=20000 width=61) (actual time=4.395..4.396 rows=20000.00 loops=1)
                                Buckets: 32768  Batches: 1  Memory Usage: 2131kB
                                Buffers: shared hit=257
                                ->  Seq Scan on cliente cl  (cost=0.00..457.00 rows=20000 width=61) (actual time=0.014..2.179 rows=20000.00 loops=1)
                                      Buffers: shared hit=257
Planning:
  Buffers: shared hit=74 read=9
Planning Time: 7.920 ms
Execution Time: 2584.457 ms
```

### Explicación de la IA (nodo por nodo)

Le pasé el plan real y pedí que lo explique en lenguaje natural:

> **Explicación de IA:**
>
> 1. **Seq Scan on cliente cl**: El optimizador lee secuencialmente las 20,000 filas de `cliente`. Es la tabla más pequeña, así que se usa para construir la segunda tabla hash.
>
> 2. **Hash (cliente)**: Construye una tabla hash con 20k filas de `cliente` en 2131kB de memoria (1 batch). Aquí la tabla "interna" es `cliente`.
>
> 3. **Seq Scan on pedido p**: Lee secuencialmente las 200,000 filas de `pedido`.
>
> 4. **Hash (pedido)**: Construye una tabla hash de 200k filas en 6749kB. No cabe en un solo batch → se divide en 2 batches, con 438kB escritos a disco temporal. La tabla "interna" es `pedido`.
>
> 5. **Seq Scan on detalle_pedido dp**: Lee las 600,000 filas de `detalle_pedido`. Esta es la tabla "externa" del primer Hash Join.
>
> 6. **Hash Join (dp ↔ pedido)**: Une `detalle_pedido` (externa) con `pedido` (interna/hash). El optimizador eligió Hash Join porque ambas tablas son grandes y no hay índice que haga Nested Loop eficiente.
>
> 7. **Hash Join (resultado ↔ cliente)**: Une el resultado del join anterior con `cliente` (interna/hash). Nuevamente Hash Join porque es la mejor opción para tablas de este tamaño.
>
> 8. **Sort externo**: Ordena los 600k resultados por gasto total descendente. Usa disco (57MB) porque no cabe en memoria.
>
> 9. **GroupAggregate**: Agrupa por `cl.email` y calcula SUM de cantidad*precio.
>
> 10. **Limit**: Retorna solo las top 20 filas.

### Verificación contra el plan real

| Afirmación de la IA | ¿Correcta? | Corrección / evidencia del plan real |
|----------------------|-------------|---------------------------------------|
| "Seq Scan on cliente es la tabla más pequeña" | **Sí** | Plan real: 20,000 filas, Buffers: shared hit=257. Es efectivamente la más pequeña. |
| "cliente es la tabla interna del segundo Hash Join" | **Sí** | Plan real: `Hash Cond: (p.id_cliente = cl.id_cliente)` — `cliente` está en el nodo `Hash` (interna), el resultado de `dp↔p` está en el nodo externo. Correcto. |
| "pedido tiene 200k filas y su Hash table cabe en 2 batches" | **Sí** | Plan real: `rows=200000`, `Batches: 2, Memory Usage: 6749kB`, `temp written=438`. Correcto. |
| "detalle_pedido es la tabla externa del primer Hash Join" | **Sí** | Plan real: El nodo raíz del primer Hash Join es Seq Scan on detalle_pedido (600k filas), y el Hash es Seq Scan on pedido. Correcto. |
| "El optimizador eligió Hash Join porque no hay índice que haga Nested Loop eficiente" | **Parcialmente incorrecto** | **Corrección**: El optimizador elige Hash Join porque las tablas de hash (`pedido` 200k, `cliente` 20k) caben relativamente en memoria y se necesita recorrer las 600k filas de `detalle_pedido` de todas formas para el GROUP BY. Un Nested Loop haría 600k × lookup, que sería peor. **No es por la falta de índice**, sino por el volumen de datos y la necesidad de procesar todas las filas. |
| "El Sort externo usa disco porque no cabe en memoria" | **Sí** | Plan real: `Sort Method: external merge Disk: 57568kB`. 57MB excede `work_mem`. Correcto. |
| "GroupAggregate calcula SUM" | **Sí** | Plan real: `Group Key: cl.email`, `Filter: (sum(...) > '0')`. Es un GroupAggregate, no un HashAggregate, porque los datos ya vienen ordenados del Sort. Correcto. |

### Hallazgos de la lectura crítica

1. **Error sobre "falta de índice"**: La IA atribuyó la elección de Hash Join a la ausencia de un índice en `detalle_pedido.id_pedido`. En realidad, el optimizador elige Hash Join porque el plan require procesar **todas** las 600k filas para el GROUP BY. Un Nested Loop con índice en `detalle_pedido` haría 200k × (lookup en 600k registros en promedio), lo cual sería más lento.

2. **Confusión sobre tabla externa/interna**: La IA correctamente identificó que `detalle_pedido` es externa en el primer join y que el resultado es externo en el segundo. Sin embargo, initialmente sugirió que el orden de los joins era "izquierda a derecha" (como aparecen en el SQL), cuando en realidad el optimizador puede reordenarlos. El plan real muestra que `pedido` se hashea primero y luego se une con `detalle_pedido`.

3. **Costo estimado vs tiempo real**: La IA no mencionó la discrepancia entre el costo estimado (`cost=7655.00..29226.37`) y el tiempo real (`actual time=38.003..354.139`). El costo es una estimación abstracta del optimizador, no el tiempo real. La diferencia de ~10x entre estimación y realidad sugiere que los estadísticos de las tablas podrían estar desactualizados (aunque se corrió ANALYZE).

4. **Impacto del Batch 2 en disco**: La IA no señaló que el Hash de `pedido` escribe 438kB a disco temporal (`temp written=438`), lo cual indica que `work_mem` no es suficiente para un solo batch de 200k filas. Esto es un cuello de botella real que un índice no resuelve — se necesitaría aumentar `work_mem`.
