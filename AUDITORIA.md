# Auditoría de mecánicas — Costa Hash 3D

> Revisión completa de la lógica de juego (2026-09-29). Objetivo: que todas las
> mecánicas tengan **orden y coherencia** (nada huérfano, nada que se contradiga).
> Se revisaron todos los scripts y su interacción.

## Bugs corregidos

| # | Problema | Impacto | Solución |
|---|----------|---------|----------|
| 1 | **`GameState.set_wanted()` no existía** pero la policía la llamaba al arrestar/escapar | Error de runtime en cada arresto | Añadido `set_wanted()` + sincronización `Wanted.level_changed → GameState.wanted` |
| 2 | La policía, en fase **búsqueda**, iba a `(0,0,0)` si no había "visto" al jugador | Coches alejándose al vacío | Si no hay última posición conocida, se usa la del jugador |
| 3 | **Progreso de misiones no se guardaba** | Se perdía al recargar | `Missions` guarda/restaura índice y progreso; se persisten en el save |
| 4 | **Hora/día no se guardaban** y `GameState.day` nunca cambiaba | Reloj inconsistente | `Clock` cuenta días (paso de medianoche) y se guarda hora + día |
| 5 | **`respeto` era un número muerto** (se mostraba y guardaba, pero nada lo cambiaba) | Mecánica huérfana | Se gana al vender y **reduce el calor** (hasta −30%). Ahora tiene efecto |
| 6 | **Ayuda del HUD incorrecta**: decía "M = movil" | Confusión | Corregido: `M = mapa`, `P = movil` (+ tecla P para abrir el móvil) |
| 7 | **Botón DELITO** era un marcador sin lógica (solo subía calor) | Mecánica sin sentido | Eliminado del HUD (la policía surge de vender); la tecla **R** queda como truco de desarrollo |
| 8 | **Móvil/Mecánico mostraba el id** ("moto") en vez del nombre | UI pobre | Muestra el nombre del vehículo |
| 9 | **Tap en el minimapa** competía con el arrastre de cámara | No abría el mapa en móvil | El minimapa gestiona su tap; la cámara ignora esa zona |
| 10 | Sangrado de código muerto (`client._life`, `Economy.unlocked_products`, `traffic_car.retarget(param)`, `police._lost_t`, `touch_controls.DESIGN`) | Ruido/lógica confusa | Eliminado |

## Coherencia añadida

- **HUD**: hora y día en vivo (`Nueva Malaga · Dia 1 11:08`) + **barra de estamina**
  (la estamina existía pero no se veía).
- **Calidad**: la etiqueta del móvil indica `(auto)` cuando está en modo adaptativo.
- **DebugBridge**: estado ampliado (respeto, hora, misión) y `travel` por defecto al
  distrito actual.

## Sistemas revisados y su estado

| Sistema | Estado |
|---------|--------|
| Economía (productos, precios dinámicos, placas, mejoras, banda, garaje) | OK y coherente |
| Rangos/XP/respeto | OK |
| Clientes/NPCs (compra), peatones (estados), tráfico (semáforos) | OK |
| Policía (fases persecución→búsqueda→evasión, barricadas, arresto) | OK (bug #1/#2 corregidos) |
| Vehículos (física, anti-vuelco, luces, garaje, mecánico) | OK |
| Mundo (día/noche, props, calles), minimapa/mapa/GPS, misiones | OK |
| Guardado (dinero, XP, upgrades, vehículos, distrito, misión, reloj) | OK |

## Pendiente / conocido (no corregido en esta pasada)

- **Salud y daño** del jugador (hospital): no existe todavía. Es el siguiente
  sistema grande de mecánicas; encaja cuando se hagan misiones/combate.
- **`player_name`**: se guarda pero no se usa (perfil sin definir).
- **Interiores/tiendas físicas**, **pickups**, **armas**: ver `BENCHMARK_OSS.md`.
- **Multijugador**: fuera de alcance.

## Notas de arquitectura

- Autoloads y su orden: `Assets · Audio · Fx · Clock · Quality · SaveManager ·
  GameState · Wanted · Economy · Missions · RoadGraph · Controls · DebugBridge`.
- `GameState.load_game()` restaura dinero/XP/vehículos/distrito/**misión/reloj** y
  sincroniza `Wanted`.
- `Economy._process` centraliza mercado dinámico + banda pasiva.
- El save es **v3** (los v<3 se descartan para empezar limpio).
