# Auditoría de PERSONAJES (NPCs) — biblioteca, animaciones y variedad

> Estado a 2026-09-29. Objetivo: que **todos** los personajes salgan de **una
> misma biblioteca** pero con variedad real (aspecto + comportamiento), y que las
> animaciones dejen de ser "caminar y ya".

## 1. Fuente de assets (una sola biblioteca, CC0)

| Pack | Contenido | Anims | Licencia |
|------|-----------|-------|----------|
| Kenney **Mini Characters** | 12 humanos (skinned) + sillas de ruedas/bastones | **32 clips** | CC0 |
| Kenney **Blocky Characters** | 18 humanos (ligeros) | 27 clips | CC0 |
| (opcional) Quaternius **Universal Base Characters + Animation Library** | 6 bases + 120 anims (glTF) | — | CC0 |

Todos viven en `game/assets/characters/` y se sirven por el autoload `Assets`
(`fit_height`, `tint`, `play_anim`, `neutralize_root_motion`).

## 2. Lo implementado en esta fase

- **`Npc` (autoload `npc_library.gd`)**: fábrica única de personajes con **roles**:
  `civil`, `buyer`, `cop`, `tourist`, `worker`, `kid`. Cada rol decide estilo
  (mini/blocky), género, **altura**, **color de ropa** (paleta aleatoria) y
  **velocidad de paseo**. Los personajes ya no son clones.
- **Peatones** (`pedestrian.gd`): eligen rol → civil/turista/obrero/niño, con su
  velocidad y su tinte; caminan **por la acera** (offset lateral) y tienen estados
  `WALK/IDLE/FLEE/CHAT` (huyen de policía o del jugador buscado).
- **Clientes** (`client.gd`): rol `buyer` (variedad de ropa) + **marcador dorado**
  para distinguirlos de los que solo pasean.
- **Root motion** de los clips eliminado → caminan sin deslizarse; **crossfade** y
  **velocidad de anim sincronizada** con el movimiento (menos "patinaje").
- **Jinete**: al subir a un vehículo el personaje se **sienta/conduce**
  (`sit`/`drive`) en vez de desaparecer.

> Resultado: 12+18 modelos, 4 roles de civil, ropa aleatoria, 4 velocidades.

## 3. Gaps y plan para "mejores animaciones y más variedad"

**a) Usar más clips que ya tenemos (coste 0)**
- Idle con *emotes* ocasionales (`emote-yes/no`, `interact-right`) al estar parados.
- En tienda/venta, `holding-right`/`interact-right` en vez de idle.
- Al recibir un golpe/atropello: `die`/`fall` para peatones (impacto creíble).
- `sprint` cuando huyen (ya), `crouch`/`sit` en parques y bancos.

**b) Blending real con `AnimationTree`**
- Mezcla 1D `idle→walk→sprint` por velocidad (transiciones suaves, sin "tic").
- Capa superior para saludos mientras caminan.

**c) Más modelos y variedad**
- Combinar mini + blocky por rol (hecho en civil); añadir **proporciones** (niño
  más bajo, hecho) y **peinados/ropa** por variante de material.
- Opción: importar Quaternius (glTF) y enriquecer con sus 120 animaciones.

**d) Comportamiento / población**
- **Schedules** por hora (menos gente de noche; ya se reduce el presupuesto).
- **Grupos** de 2-3 charlando en la calle (reusar `CHAT`).
- **Reacciones** a tiroteos/atropellos (huir en estampida).
- **Rutas por acera** (hoy se dirigen a nodos de calle con offset; se puede
  precalcular carriles peatonales).

**e) Rendimiento**
- Los `mini` son **skinned** (más caros): limitar nº por calidad (ya: 8/14/20) y
  usar **blocky** (sin skin) para multitudes.
- `visibility_range`/LOD por distancia; congelar animación lejos.

## 4. Cómo añadir un personaje nuevo (flujo)

```bash
# 1) Copia el .glb (+ Textures/) a game/assets/characters/<estilo>/
# 2) Anadelo al manifest (assets_manifest.json)
# 3) /opt/server/tools/godot/godot --headless --path /opt/server/apps/costa3d --import
# 4) Usalo con Npc.character("rol") o Assets.character(estilo, genero, idx)
```

## 5. Prioridad recomendada

1. **Idle con emotes + reacciones** (coste 0, mucha vida).
2. **AnimationTree** (suavidad de movimiento).
3. **Grupos y schedules** por hora.
4. Importar Quaternius si se quiere salto de variedad/animaciones.
