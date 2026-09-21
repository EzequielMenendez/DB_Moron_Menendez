# DUIA - TP5: indices, vistas y vista materializada

## Registro honesto de asistencia

| Herramienta | Proposito | Entrada conservada | Resultado revisado | Decision |
|---|---|---|---|---|
| Kiro (formato de spec) | Especificar alcance, consultas y criterios | `.kiro/specs/tp5_indices_vistas/` | Tres indices, cuatro vistas y una materializada propuestos | Aceptar solo objetos compatibles con el esquema heredado |
| Agente de codigo | Generar y revisar SQL | Specs anteriores y `db/schema.sql` | Scripts 11, 12 y 13 | Revisados manualmente; no se modifica ninguna tabla base |
| Agente de codigo | Evaluar sobreindexacion | Consulta Q1 e indices heredados | Propuesta `producto(activo)` | Descartada por baja cardinalidad y redundancia funcional |

## Limitacion verificable

Esta sesion no ejecuto Kiro ni OpenCode como aplicaciones separadas. El artefacto
de referencia compartido por el estudiante se uso para conservar el flujo
`spec -> generacion -> revision -> Git`; las especificaciones quedan en formato
Kiro. Antes de entregar, registrar aqui la interaccion real con esas herramientas
si la catedra exige su evidencia literal.

## Ejecucion y revision humana

Los scripts se ejecutaron en la copia `food_store_tp5` con PostgreSQL 18.6. Se
confirmaron los cambios de plan de las tres consultas, las equivalencias con
`EXCEPT` en ambos sentidos y `REFRESH MATERIALIZED VIEW CONCURRENTLY`. Los valores
observados estan en `docs/informe_indices_vistas_tp5.md`. La revision final de
commits y de la defensa oral sigue siendo responsabilidad humana.
