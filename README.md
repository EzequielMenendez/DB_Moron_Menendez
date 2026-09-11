# BDII - Food Store (Base de Datos II)

Entrega académica para el curso de Base de Datos II. Sistema de gestión de una tienda de alimentos con PostgreSQL.

## Estructura del proyecto

```
├── db/
│   ├── schema.sql              # Esquema base del proyecto
│   ├── sql/                    # Scripts SQL organizados por práctica
│   └── backups/                # Respaldos (NO versionar)
├── docs/                       # Documentación y entregables
├── src/                        # Código fuente (futuro)
├── .kiro/steering/             # Reglas de Kiro
│   └── security-policies.md    # Normas de seguridad
├── .gitignore
├── .env.example                # Variables de entorno (sin valores reales)
├── AGENTS.md                   # Contexto del proyecto para OpenCode
└── README.md
```

## Entregas realizadas

### Semana 2 - Integridad y Concurrencia
- `db/schema.sql`: esquema base del proyecto.
- `docs/protocolo_seguridad.md`: creación segura de bases, respaldos y uso transaccional.
- `db/sql/01_restricciones_integridad.sql`: restricciones de integridad revisadas.
- `db/sql/02_pruebas_restricciones.sql`: pruebas válidas e inválidas reversibles.
- `db/sql/03_laboratorio_concurrencia.sql`: procedimientos para dos sesiones.
- `docs/informe_concurrencia.md`: informe con evidencia real del motor.
- `docs/ejercicio_lectura_critica.md`: análisis de dos patrones SQL riesgosos.
- `docs/duia_parte_*.md`: declaraciones de uso de IA.

### Semana 3 - Optimización de Consultas (Carga Masiva)
- `db/sql/04_carga_masiva.sql`: carga masiva de datos (20k clientes, 50k productos, 200k pedidos, 600k detalles).
- `db/sql/05_parte4_consultas.sql` / `06_parte4_consultas2.sql`: consultas resumen con verificación EXCEPT.
- `docs/parte2_tabla_comparativa.md`: tabla comparativa de optimización antes/después.
- `docs/parte3_lectura_critica.md`: lectura crítica de planes EXPLAIN ANALYZE.
- `docs/parte4_consultas_resumen.md`: resumen de consultas y verificación de equivalencia.
- `docs/parte5_competencia_optimizacion.md`: registro de competencia de optimización.
- `docs/duia_tp3.md`: declaración de uso de IA.

### Semana 4 - Analíticas Asistidas por IA (Joins, Subconsultas, Ventana)
- `db/sql/07_parte1_analiticas.sql`: consultas analíticas con 3+ JOINs, EXPLAIN ANALYZE antes/después + índices de cobertura.
- `db/sql/08_parte3_ranking_subconsulta.sql`: ranking con RANK() y subconsulta correlacionada.
- `db/sql/09_parte3_verificacion.sql`: versiones alternativas + verificación EXCEPT de equivalencia.
- `db/sql/10_parte4_competencia.sql`: 3 estrategias de competencia (baseline, work_mem, CTE).
- `docs/parte1_tabla_join_analiticas.md`: tabla comparativa de algoritmos de join (todos Hash Join).
- `docs/parte2_lectura_critica_joins.md`: lectura crítica de planes con 2+ JOINs, imprecisiones de IA detectadas.
- `docs/parte3_consultas_analiticas.md`: specs + SQL + verificación EXCEPT (equivalencia confirmada).
- `docs/parte4_competencia_tp4.md`: registro de competencia, ganó baseline con índices (1219ms).
- `docs/duia_tp4.md`: declaración de uso de IA (5 usos).

## Requisitos previos

- PostgreSQL 18.x con `psql`, `createdb`, `pg_dump` y `pg_restore` en `PATH`.
- Git y GitHub Desktop instalados.
- OpenCode y Kiro configurados.
- Dos terminales independientes para la práctica de concurrencia.
