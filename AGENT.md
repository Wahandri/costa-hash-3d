# AGENT.md — Costa Hash 3D (guía para agentes IA)

> Contexto completo para que un agente pueda **entrar a trabajar** en este proyecto
> sin romperlo. Léelo entero antes de tocar nada. Documentos de apoyo:
> `PENDIENTES.md` (bitácora de fases), `DISENO_AUDITORIA.md`, `NPCS_AUDITORIA.md`,
> `BENCHMARK_OSS.md`, `tools/geo/ESTUDIO_ZONA.md`.

---

## 0. Qué es y quién lo usa

**Costa Hash 3D** es un **open-world arcade 3D** ambientado en la Costa del Sol
(barrio real de **Nueva Málaga**, Málaga). Se juega en el navegador (web) y en
**móvil como PWA instalable**, en **horizontal**. Servidor propio, sin backend de
juego (todo corre en el cliente Godot).

- **URL**: https://costa.wahandri.com
- **Contenedor**: `costa3d` (nginx:alpine sirviendo `build/web` en el puerto 3017).
- **Motor**: Godot **4.7.2** (`/opt/server/tools/godot/godot`), render
  **Compatibility (WebGL2)** obligatorio para web.
- **Idioma del contenido**: español.

---

## 1. Lo que QUEREMOS (visión de producto)

1. **Fidelidad a la zona real**: el mapa debe parecerse a Nueva Málaga de verdad
   — **relieve y cuestas (DEM), alturas reales de edificios, escaleras, sentido
   único de calles, landmarks reales** (iglesia donde hay iglesia, centro de salud
   donde hay uno…), pero **sin nombres** en pantalla (solo fidelidad de estilo).
2. **Lectura visual clara**: distinguir **carretera (asfalto oscuro) de acera
   (clara)** con bordillo; que se lean **cuestas y altitud**; estilo **low-poly
   mediterráneo** (claro, luminoso), día/noche.
3. **Mundo vivo**: tráfico que respeta **semáforos y sentido único**, **peatones
   por la acera** con variedad y animaciones, **policía por fases**
   (persecución→búsqueda→evasión), clientes que compran.
4. **Conducción arcade satisfactoria**: sin vuelcos, cámara controlable,
   **vehículo inicial = moto antigua**, **mecánico** que te la trae, garaje.
5. **Progresión de trapicheo**: economía dinámica (precios/eventos), rangos,
   respeto, misiones por contador, salud y **hospital**.
6. **Web/móvil primero**: PWA instalable, horizontal, calidad adaptativa, tacto.
7. **Todo generado por código y reutilizable**: el mundo no es una escena
   artesanal; se construye al cargar desde `game/data/*.json` + biblioteca de
   assets CC0 (`game/assets/`), para que la IA pueda iterarlo fácil.

---

## 2. Lo que FALTA (roadmap priorizado)

1. **Audio ambiente/ciudad** (tráfico lejano, gaviotas, gente) y **radio** de coche.
2. **Reacciones de multitud** (estampida al oír sirenas/atropellos; `die`/`fall`).
3. **Más vehículos propios** (motos/camiones) y **toldos/portales** en planta baja.
4. **Clima** (lluvia + asfalto mojado) y atardeceres.
5. **Escaleras con colisión transitable** fina; **continuidad de acera** en cruces.
6. **Interiores/tiendas físicas**, pickups, armas.
7. **Landmarks con geometría más rica** (torres, cúpulas) sin nombres.
8. **Rendimiento**: streaming/LOD por celdas, culling, presets por dispositivo.
9. **Pantalla de carga propia** (hoy el loader por defecto de Godot).
10. **Más distritos** y multijugador (fuera de alcance actual).

> Ver `PENDIENTES.md` para la lista viva y `BENCHMARK_OSS.md` para ideas de otros
> GTA-likes de código abierto (GPL: solo referencia conceptual, no copiar código).

---

## 3. Arquitectura (cómo está montado)

### 3.1 Escena única generada por código
`game/scenes/main.tscn` es casi vacío: contiene un `Node3D` con `main.gd`, que en
`_ready()` monta **todo**: entorno, luz, mundo (`world_builder.gd`), jugador,
vehículo del garaje, policía, tráfico, peatones, clientes, HUD, minimapa, mapa y
móvil. **No hay escenas .tscn artesanales** de NPCs/coches: se instancian por código.

### 3.2 Autoloads (orden IMPORTANTE)
```
Assets → Npc → Terrain → Audio → Fx → Clock → Quality → SaveManager → GameState
→ Wanted → Health → Economy → Missions → RoadGraph → Controls → DebugBridge
```
Dependencias clave: `RoadGraph.node_world()` usa `Terrain`; `GameState.load_game()`
usa `Clock` y `Health`; `Terrain` debe configurarse **antes** de construir el mundo
(lo hace `world_builder._ready`).

### 3.3 Mapa de sistemas → archivos (`game/scripts/`)

| Sistema | Archivos |
|---|---|
| Bootstrap/entorno/HUD root | `main.gd` |
| Mundo (terreno, calles, edificios, props, landmarks) | `world_builder.gd`, `terrain.gd`, `night_glow.gd`, `traffic_light.gd` |
| Jugador | `player.gd` |
| Vehículos | `vehicle.gd`, `car_lights.gd` |
| Tráfico | `traffic.gd`, `traffic_car.gd` |
| Policía | `police.gd`, `police_car.gd`, `wanted.gd` |
| NPCs | `client.gd`/`clients.gd`, `pedestrian.gd`/`pedestrians.gd`, `npc_library.gd` |
| Economía/garaje | `economy.gd` (+ `game/data/economy.json`) |
| Estado/save | `game_state.gd`, `save_manager.gd`, `health.gd` |
| Misiones/GPS | `missions.gd`, `minimap.gd`, `map_screen.gd` |
| UI | `phone_ui.gd` (móvil), `touch_controls.gd` (HUD+joystick) |
| Entrada | `controls.gd` |
| Reloj/día-noche | `game_clock.gd` |
| Audio/FX/calidad | `audio_manager.gd`, `fx.gd`, `quality_preset.gd` |
| Assets | `asset_library.gd` (+ `game/assets/assets_manifest.json`) |
| Playtest/LLM | `debug_bridge.gd` (TCP 127.0.0.1:9099) |

### 3.4 Capas de colisión (¡respetar!)
`1 = suelo/mundo · 2 = jugador · 4 = edificios/props/landmarks · 8 = vehículos · 16 = NPCs`
- Jugador: layer 2, mask `1|4|8`.
- Vehículos: layer 8, mask `1|4|8|2`.
- NPCs (clientes/peatones): layer 16, mask `1|4|8`.
- Edificios/props/barreras: layer 4.
- **Anti-vuelco**: los `VehicleBody3D` usan `axis_lock_angular_x/z` + COM bajo.

### 3.5 Grupos útiles
`world_builder`, `player`, `vehicles`, `traffic`, `police`, `police_manager`,
`clients`, `clients_manager`, `pedestrians`, `pedestrians_manager`,
`traffic_lights`, `landmarks`, `phone_ui`, `map_screen`, `minimap`, `main`.

### 3.6 Assets (biblioteca CC0)
- Carpeta `game/assets/` (characters/vehicles/city/watercraft/audio) + manifest.
- Autoload **`Assets`**: `character(style,gender,index)`, `vehicle(name)`,
  `prop(name)`, `watercraft`, `streams(key)`, `fit_height/fit_length`,
  `tint`, `enable_locomotion/set_locomotion`, `build_scatter` (MultiMesh),
  `play_anim` (crossfade), `motorcycle()` (moto procedural propia).
- Autoload **`Npc`**: `character(role)` con roles `civil/buyer/cop/tourist/worker/kid`
  (variedad de estilo, ropa, altura, velocidad).
- Licencias y créditos en `game/assets/CREDITS.md`. **Todo CC0**.

---

## 4. Pipeline del MAPA (OSM + DEM) — `tools/geo/`

La escena se construye desde planos reales generados por la tool GEO (Python venv):

```bash
cd /opt/server/apps/costa3d/tools/geo
.venv/bin/python build_blueprint.py --district nuevamalaga   # usa caché raw_osm/raw_poi
# Salidas en out/nuevamalaga/: blueprint.json, road_graph.json, terrain.json,
# stats.json, blueprint.svg, raw_osm.json, raw_poi.json
cp out/nuevamalaga/blueprint.json   ../../game/data/blueprint_nuevamalaga.json
cp out/nuevamalaga/road_graph.json  ../../game/data/road_graph_nuevamalaga.json
```

Qué extrae: **relieve** (EU-DEM vía OpenTopoData), **edificios** (`building:levels`,
`building:colour`, `roof:colour`, `roof:shape`), **calles** (clase/oneway),
**escaleras** (`steps`), **parques**, **landmarks** (`amenity`/`tourism`/`shop`/
`leisure`, en `raw_poi.json`). El **tráfico excluye peatonales** y las aristas
`oneway` van dirigidas. Ver `tools/geo/ESTUDIO_ZONA.md`.

⏳ Si Overpass da **504**, reintentar (la tool rota endpoints y cachea).

---

## 5. Flujo de trabajo del agente

### 5.1 Importar recursos (tras añadir/editar escenas o assets)
```bash
/opt/server/tools/godot/godot --headless --path /opt/server/apps/costa3d --import
```

### 5.2 Exportar web + PWA (USAR SIEMPRE ESTE)
```bash
bash /opt/server/apps/costa3d/tools/export_web.sh   # export + reaplica PWA
# Equivale a: godot --export-release "Web" build/web/index.html + tools/pwa_apply.sh
```
El contenedor monta `build/web`, así que **re-exportar publica al instante**.
`index.pck`/`index.wasm` van con `Cache-Control: no-cache` (nunca servir viejo).

### 5.3 Probar rápido (headless, sin navegador)
```bash
/opt/server/tools/godot/godot --headless --path /opt/server/apps/costa3d
# buscar SCRIPT ERROR / Parse Error / Invalid call en la salida
```
> **Cuidado**: los **warnings de inferencia de tipo son errores** (Godot
> `warnings_as_errors` está activo en la práctica). Tipa siempre (`var x: float = …`).

### 5.4 Pruebas en navegador (Playwright + Chrome software)
```bash
cd /opt/server/apps/costa3d/tools   # requiere `npm i` (ya hecho)
node smoke.mjs   http://localhost:3017/          # carga sin errores
node look.mjs    http://localhost:3017/ out/      # captura jugador/modelos
node move.mjs? (move-test.mjs) ...                # movimiento
node drive-test.mjs / turn-test.mjs / flip-test.mjs / cam-test.mjs
node moto-map-test.mjs / touchui-test.mjs / police-visual.mjs / ui-test.mjs
```
Salen capturas en `tools/out/`; **revisa SIEMPRE las imágenes** además del `errores:`.

### 5.5 Playtest headless (DebugBridge) + informe
```bash
cd /opt/server/apps/costa3d/tools
./playtest.sh 60          # bot de reglas 60s + INFORME.md (out/bot/)
./playtest.sh 60 llm      # agente LLM DeepSeek (out/llm/)
node health-test.mjs      # (necesita bridge abierto; valida hospital)
```
El bridge (`debug_bridge.gd`) expone `state/move/goto/stop/look/action/crime/
travel/buy_placa/sell/damage/heal/ping` por JSON-línea en `127.0.0.1:9099`.

### 5.6 Checklist antes de dar un cambio por bueno
- [ ] Headless sin errores (ni warnings-as-errors).
- [ ] `smoke.mjs` → `errores (0)`.
- [ ] Captura visual coherente (revisar imagen, no solo el contador).
- [ ] Si toca economía/policía: `playtest.sh` funciona (dinero/XP/rango suben).
- [ ] `bash tools/export_web.sh` (reaplica PWA) y `docker exec costa3d nginx -s reload` si se tocó `nginx.conf`.
- [ ] Actualizar `PENDIENTES.md` (nueva fase) y/o el doc de auditoría que toque.

---

## 6. Convenciones y TRAMPAS (leer antes de tocar)

1. **Sin comentarios innecesarios en el código** (el proyecto evita ruido); sí se
   documentan decisiones en `PENDIENTES.md`.
2. **GDScript tipado**: los `var x := algo_que_devuelve_Variant` rompen la compilación.
3. **Modelos Kenney**: el **morro es +Z** (`wheel-front`/`grill` en +Z). Los
   `VehicleBody3D` avanzan a **-Z** con `engine_force` positivo... pero medido en
   este proyecto el `engine_force` positivo empuja a **+Z**; por eso
   `vehicle.gd::_drive_input()` **invierte el acelerador** y el modelo se gira 180°
   (los coches Kenney sí; la **moto procedural va a -Z** y **no** se gira). No
   cambiar esto sin medirlo con el bridge.
4. **Root motion**: los clips de personaje traen translación de raíz; `Assets`
   la **elimina** al instanciar. No la reintroduzcas.
5. **Animación**: usa `Assets.enable_locomotion(node)` (AnimationTree idle/walk/
   sprint) + `set_locomotion(node, 0/0.5/1)`. Para gestos (sit/drive/emote)
   `set_locomotion_active(node,false)` + `play_anim(...)`.
6. **Terreno**: TODO se asienta con `Terrain.height_at_bp(x, y)` (coords de plano;
   mundo = `(x, y, -y_plano)`). La colisión del terreno es **trimesh con
   `backface_collision=true`** (sin esto el jugador cae atravesándolo).
7. **Assets**: añadir un `.glb` = copiar (con su `Textures/`) a `game/assets/…` +
   entrada en `assets_manifest.json` + reimportar. Si cambian texturas y no se
   aplican: `rm -rf .godot/imported` y reimportar.
8. **Nginx/Caddy**: `nginx.conf` está **bind-mounted** (aplica con
   `docker exec costa3d nginx -s reload`). `Caddyfile` montado como fichero: si el
   editor reemplaza el inodo hay que **recrear** caddy. `index.pck/wasm` SIEMPRE
   `no-cache`.
9. **Warnings de API** (p. ej. `add_blend_point` sin nombre) salen como errores en
   consola y hacen fallar `smoke`; pásale el `StringName` del nombre.
10. **`Npc.character()`** solo tinte (seguro fuera del árbol). **`Npc.apply(node)`**
    tras `add_child` (usa transforms; si no, error `is_inside_tree`).
11. **NO** ejecutar `docker compose up -d --remove-orphans` en `/opt/server`.
12. **Licencias**: OpenRW/re3/gta-* son **GPL** (solo referencia de ideas). Lo que
    se integra aquí es **CC0** (Kenney). Mantenerlo así.

---

## 7. Datos y guardado

- `game/data/`: `blueprint_<slug>.json`, `road_graph_<slug>.json`,
  `districts.json`, `economy.json` (productos, rangos, mejoras, vehículos,
  dealers), `missions.json`.
- **Save** (JSON en `user://costa3d_save.json`, en web IndexedDB): versión **3**;
  guarda dinero, posturas, XP, respeto, día/hora, distrito, vehículos,
  **salud**, **misión**. Saves < v3 se descartan (empezar limpio).
- Distrito por defecto: **`nuevamalaga`**. Viajar entre distritos recarga la
  escena manteniendo el estado.

---

## 8. Comandos de referencia rápida

```bash
# Import
/opt/server/tools/godot/godot --headless --path /opt/server/apps/costa3d --import
# Run (headless, detectar errores)
/opt/server/tools/godot/godot --headless --path /opt/server/apps/costa3d
# Export + PWA (publica al instante en el contenedor)
bash /opt/server/apps/costa3d/tools/export_web.sh
# GEO (regenerar plano real de un distrito)
cd /opt/server/apps/costa3d/tools/geo && .venv/bin/python build_blueprint.py --district nuevamalaga
# Nginx del contenedor
docker exec costa3d nginx -s reload
# Logs
docker logs -f costa3d
```

---

## 9. Estilo de trabajo que se espera del agente

- **Valida con datos** antes de "arreglar" algo visual/físico (usa el bridge y
  capturas; no asumas la orientación/altura).
- **Itera en pequeño**: un cambio → headless → export → captura → siguiente.
- **No rompas móvil**: respeta la calidad adaptativa y el tamaño del `pck`.
- **Documenta**: cada bloque va a `PENDIENTES.md`; las decisiones discutibles a la
  tabla de "Decisiones autónomas".
- **Pide solo lo ambiguo**; para lo demás, aplica el criterio de este documento.
