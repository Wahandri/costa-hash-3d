# COSTA HASH 3D — Pendientes y decisiones (revisar tras cada fase)

> Este archivo recoge **decisiones tomadas de forma autónoma** (recomendadas por el
> agente) y **tareas pendientes** marcadas para discutir y cambiar cuando termine el
> plan de fases, tal y como pidió el usuario.

## Estado

- **Fase 0 — Infra: COMPLETADA** (2026-09-28).
  - Godot 4.7.2 instalado en `/opt/server/tools/godot/godot`.
  - Tool GEO en `tools/geo/` (OSM → plano de diseño) + distrito `centro`.
  - Proyecto Godot en `/opt/server/apps/costa3d/` con blockout low-poly de
    *Málaga Centro – Puerto – La Malagueta*.
  - Export web publicado en **`https://costa.wahandri.com`** (reemplaza al Costa
    Hash 2D antiguo, que sigue en `apps/costa-hash/` y contenedor `costa-hash` :3016).
  - Verificado en Chrome headless: carga sin errores, WebGL2, movimiento y cámara OK.

- **Fase 1 — Núcleo 3D: COMPLETADA** (2026-09-28).
  - Jugador en tercera persona (caminar/correr con estamina, saltar).
  - Vehículo propio (coche) con física `VehicleBody3D`, entrar/salir con ACCION
    y cámara de persecución.
  - HUD y controles táctiles (joystick + arrastre de cámara + botones).
  - Verificado en navegador: carga sin errores, movimiento, cámara, conducir y
    entrar/salir (capturas en `tools/out/`).
  - **Fix importante**: entrada con *buffer de eventos* (una pulsación corta ya no
    se pierde en frames lentos; evita doble flanco al entrar/salir).

- **Fase 2 — Vehículos + Policía: COMPLETADA** (2026-09-28).
  - Vehículos por tipo: **coche, moto, furgoneta** (`vtype`), aparcados junto al spawn.
  - **Grafo de calles** `RoadGraph` (1466 nodos / 1565 aristas) con **A\*** para navegación.
  - **Policía por estrellas**: aparecen coches azules que siguen el grafo y, de cerca,
    van directos al jugador; **arresto** (multa + reinicio en el spawn) confirmado.
  - Colisiones por capas: suelo(1) / jugador(2) / edificios(4) / vehículos(8).
  - Verificado headless (DebugBridge) y en navegador sin errores.

- **Fase 3 — Economía y progresión: COMPLETADA** (2026-09-28).
  - **Economía**: 3 productos (hash/costilla/perico) con precio de compra/venta y calor;
    **comprar placa** (20 posturas) y **vender** posturas.
  - **Clientes NPC** que pasean por las calles y compran al pulsar ACCION (cada tipo
    compra una cantidad y genera un calor distinto).
  - **Rango/fases** por XP (Chivato → Leyenda) y **respeto**; los productos se
    desbloquean por rango.
  - **Mejoras** (Labia I/II, Pitillo, Vigía) y **banda** con ingreso pasivo
    (Primillo, Moto) que vende solo sin calor.
  - **Menú MOVIL** táctil: producto, comprar placa, mejoras y progreso.
  - Verificado: playtest headless (comprar placa + 8 ventas + XP) y capturas de UI.

- **Fase 4 — Más distritos: COMPLETADA** (2026-09-28).
  - Segundo distrito GEO: **Pedregalejo – El Palo** (888 nodos de grafo, 3694 edificios).
  - Mundo y grafo de calles **según distrito** (blueprint/road_graph por slug).
  - **Viaje entre zonas** desde el menú MOVIL (recarga de escena manteniendo dinero/XP).
  - Verificado headless: centro ↔ pedregalejo (1466 ↔ 888 nodos) y clientes por distrito.

- **Fase 5 — Playtest + agente LLM: COMPLETADA** (2026-09-28).
  - **Autopiloto** en el juego (`goto`/`stop`) para bots.
  - **Bot de reglas** (`tools/bot.mjs`): juega solo (compra, va a clientes, vende, huye).
  - **Agente LLM DeepSeek** (`tools/llm-agent.mjs`): decide acciones de alto nivel
    (con modo `--dry` sin API para pruebas).
  - **Analizador** (`tools/analyze.mjs`) → `INFORME.md` con métricas y recomendaciones.
  - Runner `tools/playtest.sh`. Verificado: bot 85 s → 306 EUR/min, rango 1→3, informe OK.

- **Fase 6 — Librería de assets CC0 + rediseño: COMPLETADA** (2026-09-29).
  - **Librería reutilizable** `Assets` (autoload) + `game/assets/` con packs **CC0**:
    Kenney *Mini Characters* (12 personas skinned, 32 animaciones), *Blocky
    Characters* (18), *Car Kit* (13 vehículos), *City Kit* (props: farolas,
    semáforos, árboles, señales, contenedores), *Watercraft* (barca) y audio
    (*Impact/Interface/Music Jingles*). Ver `game/assets/CREDITS.md`.
  - `AssetLibrary`: carga perezosa con caché, variantes, tinte, `fit_height`/
    `fit_length`, animaciones y `build_scatter` (MultiMesh).
  - **Rediseño**: jugador/clientes/policía con personajes animados (idle/walk/
    sprint), vehículos Kenney manteniendo `VehicleBody3D`, barca disponible.
  - **Mundo**: props urbanos instanciados por MultiMesh (farolas, árboles,
    semáforos), textura procedural de fachadas (triplanar) y entorno mejorado
    (cielo procedural, niebla, tonemap filmic, sombras solares).

- **Fase 7 — Jugabilidad + audio + calidad: COMPLETADA** (2026-09-29).
  - **Minimapa/radar** con calles cercanas, blips (clientes/policía/tráfico),
    **GPS** hacia la misión activa y HUD de misión.
  - **Misiones** enganchadas a las ventas (`Economy.sell_to → Missions.add_progress`),
    encadenadas y con destino en el grafo.
  - **Tráfico rodado** (`traffic.gd` + `traffic_car.gd`) y **peatones**
    (`pedestrians.gd` + `pedestrian.gd`) con pooling/despawn por distancia.
  - **Colisión real** de NPCs/policía con edificios (mask 1|4) + detección de
    atasco y replanificación.
  - **Garaje**: compra/selección de vehículos (`economy.json → vehicles`) con UI
    en el MÓVIL y persistencia en el guardado.
  - **Audio**: efectos CC0 (pasos, clics, jingles) + **motor y sirena generados
    proceduralmente** (AudioStreamWAV), con actualización por velocidad.
  - **Calidad adaptativa**: `Quality` detecta móvil (bajo) vs PC (alto) y ajusta
    sombras, niebla y nº de NPCs/tráfico; botón para cambiarla en el MÓVIL.

- **Fase 8 — Zona Nueva Málaga + NPCs + guiado: COMPLETADA** (2026-09-29).
  - **Distrito por defecto = `nuevamalaga`** (barrio real de Málaga, bbox
    `36.7170,-4.4520,36.7295,-4.4350`, ~1,5 × 1,4 km): 2765 edificios, 1021
    calles, 1284 nodos de grafo. Mapa **más pequeño** que `centro`.
  - **Mundo ajustado al distrito**: el suelo y su colisión se calculan de los
    límites reales del plano (+220 m de margen) en vez de 2,5 km fijos.
  - **NPCs**: menos compradores (máx 6) y más **peatones** que solo pasean
    (8/14/20 según calidad) + tráfico. Quien **compra** lleva un **marcador
    dorado flotante** para distinguirlo de los que solo andan.
  - **Minimapa de guiado**: distancia al objetivo en el HUD de misión y
    **flecha al borde** del radar cuando el objetivo está fuera de rango.
  - Guardado **v3** (los guardados antiguos se descartan para empezar en el barrio).

- **Fase 9 — Revisión de jugabilidad + mecánicas de referencia: COMPLETADA** (2026-09-29).
  - **Colisiones**: capas reordenadas (1 suelo / 2 jugador / 4 edificios / 8
    vehículos / 16 NPCs). Los coches ya chocan entre sí y frenan en barricadas;
    los NPCs respetan edificios y coches; el jugador choca con los vehículos.
  - **Conducción**: centro de masa bajo, dirección progresiva por velocidad,
    suspensión más firme, **anti-vuelco** automático, **freno de mano**
    (SALTAR/Espacio) y tope de giro. Ya no vuelca al girar.
  - **Cámara**: al conducir **se puede rotar/mirar** (ratón, stick o arrastre
    táctil) con recentrado automático; FOV sube con la velocidad. Verificado en
    navegador (ratón y touch).
  - **Animaciones**: se elimina el *root motion* de los clips (causaba
    deslizamiento) y se reproduce con **crossfade** + velocidad según
    movimiento. Todos los NPCs son del **mismo estilo (mini)**.
  - **Entrada/UI**: layout táctil reordenado (sin solapes) y textos de ayuda.
  - **Mundo más detallado**: **aceras, bordillos y líneas centrales** en calles;
    fachadas con ventanas.
  - **Mecánicas de referencia** (ver `BENCHMARK_OSS.md`):
    - **Mundo vivo**: ciclo **día/noche** (`game_clock.gd`) con sol/cielo/ambiente;
      menos gente y tráfico de noche.
    - **IA de peatones**: estados `WALK/IDLE/FLEE/CHAT`; huyen de la policía o
      del jugador buscado (ref. re3 PedAI).
    - **Policía por fases**: `persecución → búsqueda → evasión` con última
      posición conocida y temporizador; **barricadas** a 4-5 estrellas (ref.
      OpenRW Chase / re3 Wanted).
    - **Semáforos funcionales**: los coches de tráfico **frenan en rojo** y
      evitan chocar con el coche de delante (ref. gta2_re TrafficLights).
    - **Economía dinámica**: precios de venta oscilan con **eventos** de calle y
      bonus por zona (ref. DopeWars).
    - **Audio 3D**: motor y sirena son `AudioStreamPlayer3D` (posicional).
    - **FX**: humo al derrapar y chispas al chocar.

- **Fase 10 — Motor/mundo: estabilidad, moto, mapa y noche: COMPLETADA** (2026-09-29).
  - **Física de vehículos arreglada**: la causa de los vuelcos era un
    `wheel_rest_length` enorme (rebotaba) → ahora valores tipo demo oficial de
    Godot (rest_length 0.15, recorrido 0.2, amortiguación alta), centro de masa
    muy bajo y **estabilizador activo** (par de enderezado + amortiguación de
    balanceo). Coches y moto dejan de volcar.
  - **Vehículo inicial = moto antigua** (`Assets.motorcycle()`, modelo procedural
    reutilizable, CC0 propio). Los coches se compran en el garaje.
  - **Mecánico**: en el MÓVIL, pagando 40 EUR te trae tu vehículo a tu posición.
  - **Mapa completo**: tecla **M** (PC) o **clic/tap en el minimapa**; dibuja
    todas las calles, misión, clientes, policía, tráfico y tus vehículos.
  - **Minimapa**: la flecha del jugador ya apunta hacia donde mira la cámara
    (antes iba al revés y quedaba obsoleta al conducir); blip cian del vehículo.
  - **Escala**: personajes ~1,55-1,68 m (antes 1,8) para cuadrar con calles y
    edificios.
  - **Noche "leve oscuro"**: sol/cielo/ambiente azulados y claros (no negro),
    **farolas encendidas** y **luces de coche** (pilotos + foco) de noche.
  - **Orientación de modelos**: los modelos Kenney miran a +Z; se giran 180° para
    que el morro coincida con el avance (-Z) del vehículo (ya no circulan al revés).
  - **Calidad adaptativa**: si el FPS cae por debajo de ~24, baja un nivel solo.
  - **Anti-vuelco DEFINITIVO**: los vehículos bloquean la rotación de balanceo y
    cabeceo (`axis_lock_angular_x/z`, ejes del mundo) → **no pueden volcar**
    (nunca; rumbo libre). Más centro de masa bajo, suspensión suave y reset de
    emergencia si quedaran inclinados. Verificado con slalom a fondo (moto y coche).

- **Fase 11 — Maqueta fiel a la zona real: COMPLETADA** (2026-09-29).
  - **Estudio previo sin tocar código** en `tools/geo/ESTUDIO_ZONA.md` (OSM + DEM):
    relieve de **76 m**, edificios de **mediana 2 plantas**, 627 one-way, 57
    peatonales, 121 escaleras, jardines/parques, colores de fachada/tejado.
  - **Terreno con relieve real**: la tool GEO muestrea elevación (EU-DEM 25 m) y el
    juego genera **malla + colisión trimesh**; calles, edificios, props y spawn se
    asientan sobre el terreno. Autoload `Terrain` (bilineal). **Antes era plano.**
  - **Alturas reales** de edificios por `building:levels` (×3,2 m) en vez de la
    heurística (que daba hasta 55 m). Paleta **mediterránea** clara.
  - **Colores reales** de fachada (`building:colour`) y tejado (`roof:colour`).
  - **Peatonales** (57) excluidas del grafo de tráfico (los coches no circulan).
  - **NPCs por la acera**: clientes y peatones caminan con offset lateral a la
    acera en vez de por el eje de la calzada.
  - **Bug de formato** en el evento de economía (`% name` sin `%s`) corregido.
  - **Caché**: `nginx.conf` ahora sirve `index.pck`/`index.wasm` con
    `no-cache` → el navegador ya no juega una versión vieja del build.

- **Fase 12 — Dirección, NPCs y tejados: COMPLETADA** (2026-09-29).
  - **Dirección de avance ARREGLADA**: medido con el bridge que `engine_force`
    positivo empuja a **+Z** (hacia la cámara) → se invierte el acelerador
    (`vehicle.gd::_drive_input`). Ahora **W avanza** y el jinete mira al frente.
  - **Jinete al subir** (`sit` en moto, `drive` en coche) con orientación correcta
    y altura ajustada (ya no hundido).
  - **Colisión de props**: farolas, árboles y semáforos ya no se atraviesan
    (`_add_prop_collision`, cilindros en un StaticBody).
  - **Biblioteca de NPCs** (`npc_library.gd`, autoload `Npc`): roles
    (civil/turista/obrero/niño/comprador/cop), estilo mini/blocky, ropa y
    velocidad variables; peatones por rol. Ver `NPCS_AUDITORIA.md`.
  - **Tejados inclinados** (gabled/hipped) según `roof:shape` real; colores de
    tejado reales.
  - **Caché**: `index.pck`/`wasm` con `no-cache` (ya no se sirve build viejo).
  - Auditorías escritas: `DISENO_AUDITORIA.md`, `NPCS_AUDITORIA.md`,
    plan de mapa realista en `tools/geo/ESTUDIO_ZONA.md` §7.

- **Fase 13 — Vida de NPCs + escaleras: COMPLETADA** (2026-09-29).
  - **Peatones**: al pararse a "charlar" reproducen **emotes** ocasionales
    (`interact-right`/`emote-yes`) → dejan de ser estatuas.
  - **Clientes**: al vender hacen el gesto de **coger el producto**
    (`holding-right`).
  - **Escaleras reales** (`steps` de OSM, 95 tramos): la tool GEO las extrae y el
    mundo las dibuja como **pasillo + peldaños** transversales sobre el relieve.

- **Fase 14 — AnimationTree + sentido único: COMPLETADA** (2026-09-29).
  - **Locomoción con `AnimationTree`** (BlendSpace1D idle↔walk↔sprint) en jugador,
    peatones y clientes → transiciones suaves sin "tic"; sustituye el crossfade
    manual. Activable/desactivable para gestos (`sit`/`drive`/emotes).
  - **Sentido único real**: la tool GEO orienta y marca las aristas one-way
    (857 de 1257) según `oneway` de OSM y el rumbo de la vía; `RoadGraph` respeta
    la dirección en A* → el tráfico y la policía circulan en sentido correcto.

- **Fase 15 — Landmarks reales + PWA móvil: COMPLETADA** (2026-09-29).
  - **Landmarks en su sitio real** desde OSM (`raw_poi.json`): **69 POIs**
    (7 iglesias, 21 colegios, 6 centros de salud, 6 farmacias, mercado, policía,
    biblioteca, supermercado, deportes...). Cada uno se construye con una forma
    reconocible (torre+cruz en iglesias, cruz roja en salud, etc.), un color
    propio y un **letrero 3D** con su nombre. Aparecen en **minimapa** (cuadros) y
    en el **mapa** (con nombre).
  - **Altura/cuestas/escaleras**: terreno DEM, alturas reales, escaleras de OSM y
    sentido único ya integrados (fases 11/14).
  - **PWA instalable en móvil**: `manifest.webmanifest` (display fullscreen,
    **orientation landscape**), `sw.js`, iconos 192/512 y bloqueo horizontal al
    cargar. `nginx.conf` sirve sw.js/manifest con MIME correcto.
  - **Export con PWA**: usar `tools/export_web.sh` (exporta + reaplica la PWA).

- **Fase 16 — Fidelidad visual (sin nombres): COMPLETADA** (2026-09-29).
  - **Landmarks sin letreros ni nombres** (ni en mundo ni en mapa): solo importa
    la forma/color y su ubicacion real (iglesia como iglesia, salud como salud).
  - **Carretera vs acera bien diferenciadas**: asfalto **oscuro** (`#2f3238`),
    acera **clara** (`#c4c0b4`), **bordillo** elevado y oscuro, linea central
    **blanca**.
  - **Terreno urbano árido** (tierra/arena que se aclara con la altura) en vez de
    verde liso: hace legibles las **cuestas** y la **altitud**. Los parques siguen
    verdes.
  - **Alturas/fachadas**: edificios con `building:levels` reales, asentados en el
    relieve (sin flotar), con textura de ventanas.

- **Fase 17 — Densidad de props en aceras: COMPLETADA** (2026-09-29).
  - **Jardineras** (~130), **contenedores** (~55) y **señales** (~80) repartidos
    por las aceras a intervalos, con **colisión** (ya no se atraviesan). Usan
    MultiMesh (barato) y refuerzan la sensación de calle real.

## Decisiones autónomas (candidatas a cambiar)

| # | Decisión | Motivo | Alternativa |
|---|----------|--------|-------------|
| D1 | Renderizador **Compatibility (WebGL2)** | Único soportado en web | N/A (obligatorio) |
| D2 | Export web **sin hilos** (`thread_support=false`) | Evita necesitar COOP/COEP y problemas en iOS Safari | Activar hilos + cabeceras COOP/COEP |
| D3 | Contenedor `costa3d` con **nginx:alpine + volumen** al build | Re-exportar en host y ver cambios al instante, sin reconstruir imagen | Dockerfile que copia el build |
| D4 | Mapa generado **al cargar** desde `blueprint_centro.json` | Rápido de iterar con IA | Hornear a `.tscn`/`.glb` estático |
| D5 | Colisión de edificios por **caja AABB** | Simple y barato | Trimesh exacta por edificio |
| D6 | Altura de edificios **heurística** (área + hash) | OSM no trae alturas en el plano actual | Extraer `building:levels`/`height` de OSM |
| D7 | Sin mar/agua del lado de la costa salvo franja generada | No hay polígono de mar en OSM | Construir polígono de tierra/mar con coastline |
| D8 | HUD/jostick **siempre visibles** (también en PC) | Facilitar pruebas | Ocultar joystick si no hay pantalla táctil |
| D9 | Echar los containers antiguos `costa-hash` siguen **encendidos** | No borrar nada sin permiso | Pararlos para liberar recursos |
| D10 | Grafo de calles **horneado** en `road_graph_centro.json` (aún sin usar) | Pedido por el usuario | Usarlo en F2 para tráfico/policía |
| D11 | El coche propio aparece **a ~4 m del spawn** | Poder probarlo rápido sin buscarlo | Garaje/compra con el coche aparcado lejos |
| D12 | Entrada por **buffer de eventos** (no por flanco de `_process`) | Evita perder pulsaciones y dobles flancos | N/A |
| D13 | Coche `collision_layer=1`, jugador `layer=2` (no colisionan entre sí) | Evitar quedarse atascado al entrar/salir | Colisión real jugador-coche |
| D14 | Capas: suelo=1, jugador=2, edificios=4, vehículos=8 | Control fino de qué choca con qué | N/A |
| D15 | **Policía = agente cinemático** (`CharacterBody3D`) | La conducción física con `VehicleBody` se atascaba; la IA debe ser fiable | Volver a física de vehículo con mejor tuning |
| D16 | La policía **ignora los edificios** (solo choca con el suelo) | Evita atascos; en arcade low-poly es aceptable | Colisión real + pathfinding estricto |
| D17 | Colisión de edificios **convexa** (antes caja AABB) | La AABB invadía la calzada | N/A |
| D18 | Botón **DELITO** (tecla R) sube el calor | Placeholder para poder probar la policía antes de la economía | Sustituir por ventas/acciones reales (F3) |
| D19 | **Barca pendiente** | El agua es una lámina plana sin volumen; falta nivel/volumen de agua | Implementar con volumen de agua en F4 |
| D20 | Clientes/NPC usan solo colisión con el suelo (pueden cruzar por edificios) | Evitar atascos de IA en la primera versión | Colisión real + navegación por acera |
| D21 | Cliente desaparece 4 s después de comprar | Evitar reventas infinitas al mismo NPC | Sistema de fidelidad/consultas como el original |
| D22 | Banda pasiva vende sin calor | Recompensa por invertir (más simple) | Añadir calor reducido de la banda |
| D23 | El botón **DELITO** se mantiene para probar persecuciones | Atajo de test | Eliminar cuando haya delitos reales |
| D24 | Bot/LLM usan un **autopiloto** del juego (`goto`) | El bot no ve píxeles; navega por coordenadas | Control por joystick simulado |
| D25 | Agente LLM con **DeepSeek** y salida JSON; `--dry` sin API | Reutiliza la API ya configurada en el servidor | Otro modelo |
| D26 | El reparto de **calor por venta** es alto (llega a 5 estrellas rápido) | Pendiente de balance con más sesiones | Ajustar `heat_mult`/`risk` |
| D27 | Librería de assets **CC0 externa** (Kenney), formato **GLB** | Sin Blender en el servidor; glTF es nativo en Godot 4 | Añadir Quaternius/KayKit (requieren itch.io) o assets propios |
| D28 | Personajes **mini** para jugador/NPCs y **blocky** para peatones | Equilibrio detalle/rendimiento | Unificar en un solo estilo |
| D29 | Sin **moto** (Kenney no tiene) → se usa coche deportivo | Evitar assets FBX-only | Añadir pack de motos glTF |
| D30 | **MultiMesh** para props estáticos (farolas/árboles/semáforos) | Cientos de instancias con pocas draw calls | Instanciación normal si hace falta culling |
| D31 | Fachadas con **textura procedural triplanar** (ventanas) | Sin depender de texturas externas; 0 coste de memoria | Extraer alturas/colores reales de OSM (D6) |
| D32 | **Motor/sirena procedurales** (AudioStreamWAV) | No hay pack CC0 de motor/sirena descargado | Añadir SFX reales CC0 |
| D33 | **Sin navmesh runtime**; NPCs usan grafo + colisión + unstuck | Web sin hilos; navmesh de 2.4k edificios es caro | Navmesh horneado en design-time |
| D34 | **Preset de calidad** por plataforma (móvil=bajo, PC=alto) | Evitar que móvil se arrastre con sombras | Detección por FPS dinámica |
| D35 | Pantalla de carga y PWA: se usa el **shell por defecto de Godot** | Un shell custom es frágil de mantener | Shell propio + service worker |
| D36 | Distrito inicial **`nuevamalaga`** (barrio pequeño) | Petición del usuario: mapa más pequeño y empezar ahí | Volver a `centro` u otro barrio |
| D37 | Marcha atrás de compatibilidad: **save v3** descarta partidas previas | Cambian distrito por defecto y mapa | Migrar guardados |
| D38 | Compradores con **marcador** y menos clientes (6) | El jugador debe ver quién compra y no saturar de vendedores | NPCs "mixtos" (peatón que a veces compra) |
| D39 | **Moto antigua** como vehículo inicial (modelo procedural propio) | Kenney no tiene motos; se mantiene estilo y CC0 | Importar un pack CC0 de motos (glTF) |
| D40 | **Estabilizador arcade** de vehículos (par + amortiguación de balanceo) | Arcade > simulación; evita frustración con vuelcos | Física más realista sin ayuda |
| D41 | Modelos Kenney girados **180°** (verificado por nodos `wheel-front`/`grill` a +Z) | El morro está a +Z y el vehículo avanza a -Z | Reorientar en el import |
| D42 | **Terreno con relieve** (DEM) + todo asentado sobre él | Fidelidad con la zona real (76 m de desnivel) | Terreno plano si hubiera problemas de físicas |
| D43 | Altura de edificios por **`building:levels`** | Realidad del barrio (mediana 2 plantas) | Heurística por área |
| D44 | `index.pck`/`wasm` con **no-cache** | Evitar que el navegador sirva builds viejos | Nombres con hash |

## Trampa importante (Caddy + ficheros montados)

Caddy monta `/opt/server/Caddyfile` **como fichero**. Si se edita con una herramienta
que **reemplaza el inodo** (editores que hacen rename), el contenedor sigue viendo el
fichero antiguo. Para que Caddy vea los cambios hay que **recrear** el contenedor:

```bash
docker compose -f /opt/server/docker-compose.yml up -d --no-deps --force-recreate caddy
```

## Pendientes técnicos

### GEO / mundo
- [ ] Extraer `building:levels`/`height` y colores/uso de OSM (D6).
- [ ] Construir tierra/mar reales desde `coastline` (D7) en vez de franja.
- [ ] Hornear el blockout a escena estática y/o glTF por chunks (D4).
- [ ] Añadir más distritos (Pedregalejo, El Palo, Torremolinos, Marbella) en `districts.json`.
- [ ] Separar por chunks + LOD para móvil (rendimiento).

### Jugabilidad (futuro)
- [x] Vehículo propio con entrar/salir (F1).
- [x] Más vehículos: coche, moto, furgoneta (F2).
- [x] Policía por estrellas, persecuciones y evasión (F2).
- [x] Economía: producto, clientes, venta, XP/ranks, mejoras y banda (F3).
- [x] Segundo distrito + viaje entre zonas (F4).
- [x] Playtest automático + agente LLM + informe (F5).
- [x] Librería de assets CC0 reutilizable + rediseño visual (F6).
- [x] Minimapa + GPS + misiones en UI; tráfico y peatones; garaje; audio; calidad (F7).
- [ ] Barca jugable (el modelo ya está; falta volumen/nivel de agua y física acuática).
- [ ] Navmesh real (D33) para que la IA rodee edificios con más elegancia.
- [ ] Misiones de historia y encargos con NPCs concretos (campaña hasta capo).
- [ ] Negocios/propiedades y control de territorio.
- [ ] Balance de calor/dificultad con varias sesiones de playtest.
- [ ] Extender el garaje (mejoras por coche, repintado, daño).
- [ ] PWA instalable + service worker + shell de carga propio.
- [ ] Añadir más packs de la librería (Quaternius/KayKit) si se quiere más variedad.

### Playtest + LLM
- [ ] Replicar bot de reglas + agente DeepSeek adaptados a Godot.
- [ ] `DebugBridge` ya existe (solo escritorio, `--debug-bridge`, puerto 9099);
      falta el cliente/autopilot y el informe.

### Web / UX
- [ ] Preset de calidad adaptativa (baja en móvil, alta en PC).
- [ ] Ocultar controles táctiles sin pantalla táctil (D8).
- [ ] PWA instalable y pantalla completa.
- [ ] Comprimir/precargar wasm (39 MB) y mostrar pantalla de carga.

## Referencias externas y backlog de mejoras

Se han estudiado GTA-likes y mundos abiertos de código abierto (OpenRW, re3,
gta-reversed, gta2_re, DopeWars.js, addon Godot Open-World-Database) para detectar
qué le falta a Costa Hash. Análisis completo, comparativa y backlog priorizado en
**`BENCHMARK_OSS.md`**.

Siguientes mejoras recomendadas (quick wins, ver el doc para el detalle):

1. Ciclo **día/noche** y clima.
2. **Tráfico** con carriles y que **respeta semáforos**.
3. **Estados de peatón** (huir/charlar/observar) además de andar.
4. **Búsqueda policial** por fases: persecución → búsqueda → evasión; refuerzos y
   barricadas a 4-5 estrellas.
5. **FX**: humo de derrape, chispas de choque, partículas.
6. **Audio 3D** posicional (motor, sirena, pasos).
7. **Economía dinámica** (precios min/max por zona + eventos).
8. **Salud** del jugador + hospital.
9. **Pausa/menú** y **guardado con ranuras**.
10. **Streaming/LOD** por celdas (base para mundos grandes).

## Cómo trabajar en el proyecto

```bash
# Importar recursos tras crear/editar escenas
/opt/server/tools/godot/godot --headless --path /opt/server/apps/costa3d --import

# Probar en local (arranca una ventana si hay DISPLAY; si no, headless)
/opt/server/tools/godot/godot --path /opt/server/apps/costa3d

# Exportar web CON PWA (regenera build/web; el contenedor lo sirve al instante)
bash /opt/server/apps/costa3d/tools/export_web.sh

# Regenerar el plano GEO de un distrito (cachea la descarga de OSM)
cd /opt/server/apps/costa3d/tools/geo && .venv/bin/python build_blueprint.py --district centro

# Copiar el plano al proyecto
cp /opt/server/apps/costa3d/tools/geo/out/centro/blueprint.json \
   /opt/server/apps/costa3d/game/data/blueprint_centro.json

# Verificacion en navegador (Chrome headless, software GL)
cd /opt/server/apps/costa3d/tools && node smoke.mjs http://localhost:3017/
node move-test.mjs http://localhost:3017/
node drive-test.mjs http://localhost:3017/
node police-visual.mjs http://localhost:3017/
node ui-test.mjs http://localhost:3017/

# Playtest headless (DebugBridge en 127.0.0.1:9099)
/opt/server/tools/godot/godot --headless --path /opt/server/apps/costa3d -- --debug-bridge &
cd /opt/server/apps/costa3d/tools
node police-test.mjs    # delitos -> policia -> arresto
node economy-test.mjs   # comprar placa -> ventas -> XP
```

## Estructura

```
/opt/server/apps/costa3d/
├── project.godot              # Compatibility (WebGL2), autoloads
├── export_presets.cfg         # preset "Web"
├── nginx.conf                 # servidor estatico del build
├── icon.svg
├── game/
│   ├── scenes/main.tscn       # monta entorno + mundo + jugador + HUD
│   ├── assets/                # LIBRERIA CC0: characters/, vehicles/, city/,
│   │                          # watercraft/, audio/ (ver assets/CREDITS.md)
│   ├── data/                  # blueprint_centro.json, road_graph, economia, misiones
│   └── scripts/               # main, world_builder, asset_library, player, vehicle,
│                              # police_car, police, client, clients, pedestrian,
│                              # pedestrians, traffic, traffic_car, minimap,
│                              # audio_manager, quality_preset, controls, touch_controls,
│                              # phone_ui, road_graph, game_state, economy, wanted,
│                              # missions, save_manager, debug_bridge, probe (test)
├── build/web/                 # salida del export (montada en el contenedor)
└── tools/
    ├── assets_cache/          # zips CC0 descargados (no versionados como assets del juego)
    ├── look.mjs               # capturas del jugador/modelos (verificacion visual)
    ├── geo/                   # tool OSM (Python venv) + out/centro/
    ├── smoke.mjs              # test de carga en navegador
    ├── move-test.mjs          # test de movimiento/camara
    ├── drive-test.mjs         # test de vehiculo (entrar/conducir/salir)
    ├── police-visual.mjs      # delitos + persecucion (capturas)
    ├── police-test.mjs        # playtest headless (persecucion + arresto)
    ├── economy-test.mjs       # playtest headless (compra/venta/XP)
    ├── ui-test.mjs            # prueba del menu MOVIL
    ├── bot.mjs                # bot de reglas (juega solo)
    ├── llm-agent.mjs          # agente LLM DeepSeek (--dry sin API)
    ├── analyze.mjs            # genera INFORME.md
    └── playtest.sh            # lanza bot/LLM + informe
```

## Libreria de assets (CC0)

Los modelos viven en `game/assets/` y se catalogan en `game/assets/assets_manifest.json`.
El autoload `Assets` (`game/scripts/asset_library.gd`) los carga, los instancia y
ofrece utilidades (variantes, tinte, `fit_height`/`fit_length`, animaciones,
`build_scatter` con MultiMesh). Créditos y licencias en `game/assets/CREDITS.md`.

Fuentes (zips originales en `tools/assets_cache/`):

- Kenney (CC0): `car-kit`, `city-kit-roads`, `city-kit-commercial`,
  `city-kit-suburban`, `watercraft-kit`, `mini-characters`, `blocky-characters`,
  `impact-sounds`, `interface-sounds`, `music-jingles` — <https://kenney.nl/assets>

**Para añadir un modelo nuevo:**

```bash
# 1) Copia el .glb (y su carpeta Textures/ si la trae) a la subcarpeta que toque
# 2) Anade su id al manifest (game/assets/assets_manifest.json)
# 3) Reimporta (genera .godot/imported)
/opt/server/tools/godot/godot --headless --path /opt/server/apps/costa3d --import
# 4) Si cambiaste texturas y no se aplican, borra la cache y reimporta:
#    rm -rf /opt/server/apps/costa3d/.godot/imported
```

> Nota: los GLB de Kenney referencian `Textures/colormap.png` por ruta relativa;
> hay que copiar tambien esa carpeta junto a los `.glb` (ya está en el repo).

## Playtest automatico

```bash
cd /opt/server/apps/costa3d/tools
./playtest.sh 120        # bot de reglas 120s + INFORME.md  -> out/bot/
./playtest.sh 120 llm    # agente LLM DeepSeek 120s       -> out/llm/
```

Atribución obligatoria: datos de **OpenStreetMap (ODbL)** usados como referencia de diseño.
