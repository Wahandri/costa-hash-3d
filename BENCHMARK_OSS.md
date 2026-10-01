# Costa Hash 3D vs. juegos de código abierto similares — qué le falta

> Estudio de referencia (2026-09-29). Se han revisado repositorios de GTA-likes de
> código abierto y de mundo abierto en Godot para detectar sistemas que Costa Hash
> todavía no tiene, y priorizar mejoras de **aspecto**, **jugabilidad** y **lógica**.
>
> ⚠️ **Licencias**: casi todos los GTA-likes (OpenRW, re3, gta-reversed, gta2_re) son
> **GPL/GPLv3** y están basados en ingeniería inversa. Sirven como **referencia
> conceptual**, NO se puede copiar código a Costa Hash. DopeWars.js es **MIT** y el
> addon de Godot es **MIT**. Regla: ideas sí, código no (salvo MIT/CC0 con crédito).

## 1. Proyectos de referencia

| Proyecto | Qué es | Stack | Interés |
|----------|--------|-------|---------|
| [rwengine/openrw](https://github.com/rwengine/openrw) | Reimplementación de GTA III | C++/OpenGL/Bullet | Arquitectura de sistemas de un GTA |
| [hottabxp/re3](https://github.com/hottabxp/re3) (mirror de GTAmodding/re3) | Código de GTA III/VC | C++/RenderWare | IA de peatones, tráfico, armas |
| [gta-reversed/gta-reversed](https://github.com/gta-reversed/gta-reversed) | Reversing de GTA:SA | C++ | Documentación de mecánicas |
| [CriminalRETeam/gta2_re](https://github.com/CriminalRETeam/gta2_re) | Reimplementación de GTA2 | C++ | CarAI, PedGroup, semáforos |
| [316k/DopeWars.js](https://github.com/316k/DopeWars.js) | Juego de trapicheo | JS/MIT | **Economía de drogas** (precios dinámicos, deudas, hospital) |
| [DigitallyTailored/Godot-Open-World-Database](https://github.com/DigitallyTailored/Godot-Open-World-Database) | Addon de *streaming* por chunks | Godot/GDScript | Mundo sin cargar todo |
| [redhoot-dev/Godot-Open-World-Demo](https://github.com/redhoot-dev/Godot-Open-World-Demo) | Demo de terreno grande + lluvia | Godot | Terreno, cámara, clima |
| [sanjaymeherdev/Godot-Open-World](https://github.com/sanjaymeherdev/Godot-Open-World) | Open world con inventario/armas/NPC | Godot | Lista de features |

## 2. Mapa de subsistemas (lo que tienen ellos)

**OpenRW** (`rwengine/src/`): `ai` (AIGraph, CharacterController, DefaultAIController,
TrafficDirector) · `data` (AnimGroup, **Chase**, CollisionModel, CutsceneData,
InstanceData, ModelData, PathData, PedData, **VehicleGenerator**, WeaponData,
**Weather**, **ZoneData**) · `objects` (Character, Vehicle, Instance, **Pickup**,
**Projectile**, Cutscene) · `script` (ScriptMachine SCM) · `items` (Weapon) ·
`render` (MapRenderer, ObjectRenderer, WaterRenderer, VisualFX, ViewFrustum) ·
`audio` (SoundManager, SoundSource, buffers *streamed*) · `engine` (GameWorld,
**Garage**, **Payphone**, **SaveGame**, Animator) · `rwgame/states` (Menu, Loading,
Ingame, **Pause**, Debug).

**re3** (`src/`): `peds` (CivilianPed, **CopPed**, EmergencyPed, **Gangs**, PedAI,
**PedChat**, PedFight, PedIK, **PedPlacement**, **PedRoutes**, **Population**,
PlayerPed) · `control` (**AutoPilot**, **CarAI**, CarCtrl, **PathFind**, Pickups,
**Garages**, **Phones**) · `weapons` (Bullet, Explosion, Projectile, ShotInfo,
WeaponEffects) · `audio` (**MusicManager**, **PolRadio**, AudioCollision) ·
`renderer` (**Clouds**, **Coronas**, Glass, MBlur, **Particle**, Hud).

**gta2_re**: `CarAI`, `Ped`, `PedGroup`, `TrafficLights`, `Weapon`.

**DopeWars.js**: drogas con **precio mínimo/máximo** por zona, **eventos**, policía,
**banco**, **usurero (deuda)**, **hospital**, **escondite (stash)**, **capacidad
(abrigos)**, tienda de armas.

## 3. Comparativa con Costa Hash (estado actual)

Leyenda: ✅ lo tenemos · 🟡 parcial · ❌ falta.

| Área | Sistema de referencia | Costa Hash | Prioridad |
|------|----------------------|-----------|-----------|
| **Tech** | Streaming por chunks / LOD / culling (OWDB, OpenRW MapRenderer) | 🟡 todo se construye de golpe; MultiMesh para props; sin LOD/culling | Alta |
| | Perfilado y logging (OpenRW Profiler/Logger) | 🟡 `fps` en HUD + `--debug-bridge` | Media |
| | Save con ranuras/versión (OpenRW SaveGame) | ✅ JSON v3 mono-slot | Baja |
| | Estados Menú/Carga/Pausa (rwgame/states) | 🟡 hay MÓVIL, sin pausa ni menú inicial | Media |
| **Mundo** | Clima + ciclo día/noche (Weather, Clouds, Coronas) | ❌ cielo estático, sin hora ni lluvia | Alta |
| | Zonas y *streaming* por zona (ZoneData) | 🟡 distritos por recarga de escena | Media |
| | Agua con shader (WaterRenderer) | 🟡 lámina plana; barca pendiente | Media |
| | Generadores de vehículos (VehicleGenerator) | 🟡 spawn aleatorio por grafo | Media |
| | Semáforos funcionales (gta2_re TrafficLights) | ❌ son decorativos | Media |
| | *Pickups* en el mapa (PickupObject) | ❌ no hay objetos recogibles | Media |
| **IA** | Tipos de peatón: civil/cop/emergencia/bandas (re3 peds) | 🟡 civil (compra) + civil (pasea) | Alta |
| | Estados de IA: huir/pelear/charlar/observar (PedAI, PedChat, PedFight) | ❌ solo caminar/comprar | Alta |
| | Director de población (Population) | 🟡 spawns por distancia fijos | Media |
| | CarAI con carril, adelantamiento, frenado (re3 CarAI/CarCtrl) | 🟡 siguen nodos, sin carriles | Alta |
| | Director de tráfico (TrafficDirector) | 🟡 simple | Media |
| | Rutas/schedules de peatones (PedRoutes) | ❌ sin rutas ni horarios | Media |
| **Jugabilidad** | Máquina de misiones tipo SCM (script) | 🟡 misiones por contador | Alta |
| | Persecución: refuerzos, roadblocks, helicóptero (ChaseCoordinator) | 🟡 solo coches que siguen | Alta |
| | Buscado: fases *persecución→búsqueda→evasión* con temporizador | 🟡 solo estrellas que suben/bajan | Alta |
| | Armas y proyectiles, daño, explosiones (weapons) | ❌ no hay combate | Media |
| | Garajes y “payphones” de misión (Garages, Phones) | 🟡 garaje de compra sí | Media |
| | Interiores/tiendas/uso (compra-venta) | ❌ sin interiores ni tiendas físicas | Media |
| | Vida/daño del jugador (salud) | ❌ sin salud | Media |
| **Economía** | Precios dinámicos min/max por zona + eventos (DopeWars) | 🟡 precio fijo por producto | Alta |
| | Banco / usurero / hospital / escondite / capacidad | ❌ | Media |
| | Demanda por cliente y reputación | 🟡 `qty`/`risk` por tipo | Media |
| **Audio** | Radio y gestión de música (MusicManager, PolRadio) | 🟡 jingles + motor/sirena procedural | Media |
| | Audio 3D con oclusión (AudioCollision) | ❌ todo es 2D (no posicional) | Media |
| **Visual** | FX: partículas, humo, derrape, explosiones (VisualFX/Particle) | 🟡 algunos (sirena visible) | Alta |
| | Post-proceso (SSAO/SSIL/bloom/DOF) | ❌ Compatibility (WebGL2) no lo soporta | Nota |
| | Animación con *blending*/árbol (Animator, AnimGroup) | 🟡 `AnimationPlayer` clip suelto | Media |
| | Corona/luces y cristales rotos (Coronas, Glass) | ❌ | Baja |
| **UX** | Minimapa + GPS + brújula | ✅ | — |
| | Menú inicial/pausa/ajustes globales | 🟡 solo panel MÓVIL | Media |
| | Diálogos/charla con NPC | ❌ | Baja |

## 4. Backlog priorizado (impacto vs. esfuerzo)

### Quick wins (alto impacto, bajo esfuerzo) — recomendado primero
1. **Ciclo día/noche**: rotar `DirectionalLight3D` y colorear `ProceduralSkyMaterial`
   con un `GameClock` (autoload). Da muchísima vida (OpenRW `Weather`, re3 `Clouds`).
2. **Tráfico que frena y respeta semáforos**: `traffic_car.gd` consulta el estado del
   semáforo del nodo (gta2_re `TrafficLights`) y frena; añade carriles con *offset*
   lateral al avanzar por la arista (re3 `CarAI`). Mejora enorme de “sensación GTA”.
3. **Estados de peatón**: ampliar `pedestrian.gd` con máquina de estados
   `walk/idle/flee/chat/spectate`; al oír sirenas o ver una pelea, huir (re3 `PedAI`,
   `PedChat`). Barato y añade lógica.
4. **Fases de búsqueda policial**: sustituir “estrellas = nº de coches” por
   `persecución → búsqueda (última posición conocida) → evasión (temporizador)` con
   radio de búsqueda (OpenRW `Chase`, re3 `Wanted`).
5. **Refuerzos y roadblock simple**: al llegar a 4-5 estrellas, spawnear una barricada
   (nuestro prop `barrier`) bloqueando una calle cerca del jugador (OpenRW
   `ChaseCoordinator`).
6. **FX básicos**: humo de neumático al derrapar, chispas al chocar, partículas de
   impacto (re3 `WeaponEffects`/`Particle`). Reutiliza `GPUParticles3D`.
7. **Audio 3D**: pasar motor/sirena/pasos a `AudioStreamPlayer3D` para que haya
   direccionalidad (re3 `AudioCollision`, OpenRW `SoundSource`).
8. **Precios dinámicos de economía**: por zona y con oscilación (min/max) + eventos
   (“redada policial: el hash sube”) (DopeWars.js). Añade profundidad con poco código.
9. **Salud y daño**: barra de vida + atropellos/multas; hospital = respawn con pérdida
   (re3/reVC, DopeWars `hospital`).
10. **Pausa y menú**: estado de pausa con ajustes (calidad, audio, controles) (OpenRW
    `PauseState`, `MenuState`).
11. **Objetos recogibles** (pickups) de dinero/posturas/armas por el mapa (OpenRW
    `PickupObject`, re3 `Pickups`).
12. **Guardado con ranuras + miniatura** y autoguardado por eventos (OpenRW `SaveGame`).

### Medio plazo (impacto alto, esfuerzo medio)
13. **Streaming/LOD por chunks**: dividir el mundo GEO en celdas con
    `visibility_range_begin/end` + `MultiMesh` por celda, o adoptar el patrón del
    addon OWDB (carga/descarga por posición de cámara). Es la base para mundos grandes.
14. **Arbol de animación** (`AnimationTree`) para *blending* idle↔walk↔run y
    transiciones suaves (OpenRW `Animator`, `AnimGroup`).
15. **Misiones tipo “script”**: pasos con disparadores (`Area3D`), diálogos, vehículos
    marcados, cámaras de cinemática — emular un subconjunto de SCM (OpenRW
    `ScriptMachine`). Sustituye las misiones por contador.
16. **CarAI completo**: mantenerse en el carril, adelantar, parar por obstáculo/peatón,
    velocidades por clase de vía (re3 `CarAI`/`CarCtrl`, gta2_re `CarAI`).
17. **Director de población/tráfico**: presupuesto de entidades por zona y hora del día
    (más gente de día, menos de noche) (re3 `Population`).
18. **Rutinas de peatones**: nodos con rutas y horarios (re3 `PedRoutes`).
19. **Armas y combate**: cuerpo a cuerpo, pistola, proyectiles, explosiones, daño por
    zona; reacciones de peatones (re3 `weapons`, gta2_re `Weapon`).
20. **Interiores/tiendas**: comprar en tienda física (armas, ropa = capacidad) (DopeWars
    `stash`/`coats`, re3 `Garages`/`Phones`).
21. **Clima**: lluvia con `GPUParticles3D` + niebla + carreteras mojadas (shader)
    (OpenRW `Weather`, Godot demo `Rain.tscn`).
22. **Barca jugable**: volumen/nivel de agua y física acuática (OpenRW `WaterRenderer`).

### Largo plazo / pulido
23. Semáforos con ciclo real y colas; atascos.
24. Gangs/territorio y reputación por facción (re3 `Gangs`).
25. Radio de música por emisoras + radio policial (re3 `MusicManager`, `PolRadio`).
26. Trampas de cine/cutscenes (OpenRW `CutsceneObject`).
27. Helicóptero de policía con foco y tirador (Chase).
28. *Ragdolls* con `PhysicalBone3D` para muertes/atropellos.
29. Reflejos/cristales, coronas de farolas, desenfoque de movimiento.
30. Multijugador/cooperativo (Godot OWDB tiene sync de red).

## 5. Nota técnica importante: renderizador y límites

Costa Hash usa **GL Compatibility** (obligatorio para WebGL2/móvil). Ese camino
**no soporta** SSAO/SSIL/SSR ni niebla volumétrica, así que mucho “pulido visual” de
OpenRW/re3 (post-proceso) no aplica directamente. Alternativas reales en web:
- Iluminación/ambiente y *baked* por vértices, *vertex colors*, *materials* con
  texturas (ya usamos fachadas triplanar).
- Partículas y *shaders* propios (compatibles), transparencias simples.
- LOD/culling y MultiMesh para densidad sin coste de draw calls.
- Si algún día se prioriza PC, un preset **Forward+** abre SSAO/bloom/fog volumétrico.

## 6. Mapeo a archivos de Costa Hash (dónde tocar)

| Mejora | Archivo(s) |
|--------|-----------|
| Día/noche, clima | nuevo `game/scripts/game_clock.gd` + `main.gd::_setup_environment` |
| Estados de peatón / huir | `pedestrian.gd`, `pedestrians.gd` |
| Carriles + semáforos | `traffic_car.gd`, `world_builder.gd` (estado por nodo) |
| Fases de búsqueda/roadblocks | `police.gd`, `police_car.gd`, `wanted.gd` |
| FX derrape/choque/humo | `vehicle.gd`, nuevo `game/scripts/fx.gd` |
| Audio 3D | `audio_manager.gd` (usar `AudioStreamPlayer3D`) |
| Economía dinámica | `economy.gd`, `game/data/economy.json` |
| Salud/daño/hospital | `player.gd`, `game_state.gd`, nuevo `health.gd` |
| Pausa/menú/ajustes | nuevo `game/scripts/pause_menu.gd` |
| Pickups | nuevo `game/scripts/pickups.gd` + `wanted/clients` |
| Streaming/LOD | `world_builder.gd` (celdas) o addon OWDB |
| Misiones scriptadas | `missions.gd` + `game/data/missions.json` (pasos/triggers) |
| Armas/combate | nuevo `game/scripts/weapons.gd`, `projectile.gd` |

## 7. Recomendación de siguiente iteración

Atacar primero el bloque **“sensación de mundo vivo”** (quick wins 1-7): día/noche,
tráfico con semáforos y carriles, estados de peatón, fases de búsqueda policial,
FX, y audio 3D. Es lo que más cambia la percepción de “verse y jugarse mejor” con
esfuerzo moderado y sin tocar la base del mapa. Después, economía dinámica y
misiones scriptadas para **mejor lógica**.
