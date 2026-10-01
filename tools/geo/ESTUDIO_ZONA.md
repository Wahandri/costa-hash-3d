# Estudio de la zona real — Nueva Málaga (Málaga)

> Estudio **previo a tocar código** (2026-09-29) para construir una maqueta lo más
> parecida posible a la zona real. Fuentes: **OpenStreetMap** (Overpass, ODbL) y
> **OpenTopoData/EU-DEM 25 m**. BBox: `36.7170, -4.4520, 36.7295, -4.4350`
> (~1,5 × 1,4 km, barrio de **Nueva Málaga / Bailén–Miraflores**).

## 1. Relieve (lo más importante)

Muestreo de elevación en una malla 12×12 sobre la zona:

- **Altitud**: mín. **10 m**, máx. **87 m**, media **38 m** → **76 m de desnivel**.
- **Pendiente máxima** entre celdas (~126 m): **~16 %**.
- La zona está en una **ladera**: baja hacia el **sur** (hacia el centro/ciudad,
  ~10-20 m) y sube hacia el **norte** (Bailén–Miraflores, ~70-87 m).

```
(elevaciones en metros; fila superior = norte)
  87  70  55  53  54  60  62  50  48  41  35  29
  78  68  48  43  50  58  57  50  48  41  34  32
  70  64  47  43  58  58  51  47  44  45  39  37
  63  57  51  48  54  49  43  40  37  35  36  35
  58  54  55  47  42  43  41  37  33  29  26  27
  52  50  50  43  37  40  41  34  31  27  24  26
  50  48  46  44  38  37  35  33  30  29  28  23
  47  44  40  41  40  36  31  27  25  25  24  19
  46  44  38  36  35  28  24  22  25  22  22  17
  46  45  38  34  31  26  22  21  23  19  16  18
  41  36  35  32  30  29  24  21  25  21  15  21
  39  35  33  29  26  27  25  21  23  19  10  13
```

➡️ **El juego actual es totalmente plano (y=0).** Para parecerse a la realidad hay
que introducir **terreno con altura** (malla + colisión) y asentar calles,
edificios, props y spawn sobre él. Es el cambio con mayor impacto visual.

## 2. Edificios

- **2.909 edificios**; **2.846 con `building:levels`** (altura real disponible).
- Niveles: mín. 1, **máx. 17, media 3,3, mediana 2** → barrio **de baja altura**.
  - Reparto: 1 planta (905), 2 (753), 3 (396), 4 (165), 5-12 (resto).
- **`height` explícito: 0** (usar `levels × ~3 m`).
- Materiales: **plaster (142)**, brick (36), concrete/metal/glass/stone.
- **`building:colour`** (p.ej. `#FFFFFF`, `#A08558`, `#EDF0F5`, `#E7AE9C`…).
- **`roof:colour`** (`#8F6C5A`, `#1B1B31`, `#AC7859`…) y **`roof:shape`**:
  **flat (125)**, gabled (34), hipped (17), skillion, mansard, pyramidal, round.

➡️ Los edificios actuales usan una **heurística** que da alturas de hasta 55 m: **mal**.
Hay que usar **`levels`** (mediana 2 → ~6 m) y, cuando existan, **colores de fachada
y tejado** (y tejados inclinados en vez de todos planos).

## 3. Calles

| Clase | Nº | Notas |
|-------|----|-------|
| footway | 851 | aceras/senderos (sin coches) |
| residential | 404 | calles de barrio (la mayoría) |
| service | 188 | vías de servicio/parking |
| steps | 121 | **escaleras** (indican desnivel fuerte) |
| secondary | 120 | |
| primary | 113 | |
| tertiary | 69 | |
| pedestrian | 57 | **calles peatonales** (sin coches) |
| living_street | 32 | |
| primary_link | 29 | |
| motorway_link | 1 | enlace de autovía en el borde |

- **`oneway=yes` en 627** vías (de 2.014) → muchas **direcciones únicas**.
- `maxspeed` presente en 867; `lanes` 1 (473), 2 (265), 3-4 (78).
- `surface` en 966; `sidewalk`/`sidewalk:*:width` en cientos → **aceras modeladas**.
- Avenidas principales: **Avenida de Andalucía**, **Avenida Carlos de Haya**,
  Miraflores de los Ángeles, Obispo Ángel Herrera Oria, Valle-Inclán…

➡️ Hay que **diferenciar** peatonales (57) y no meter coches por ellas; respetar
**oneway** para el tráfico; y ensanchar primary/secondary.

## 4. Zonas verdes

- **`leisure=garden` (409)** y **`leisure=park` (18)** → muchos jardines de barrio.
- Actualmente se dibujan como praderas planas; deben seguir el **relieve**.

## 5. Conclusiones y plan de maqueta fiel (orden de impacto)

1. **Terreno con elevación** (malla + colisión) desde DEM; asentar todo sobre él.
   → cambio #1 para parecerse a la zona.
2. **Alturas reales** de edificios por `building:levels` (mediana 2) en vez de la
   heurística actual.
3. **Colores** de fachada/tejado y **tejados inclinados** (`roof:shape`).
4. **Peatonales y aceras**: no enrutar coches por `pedestrian`; aceras a las calles.
5. **`oneway`** para la dirección del tráfico (una sola dirección donde toque).
6. **Parques/jardines** como zonas verdes reales sobre el relieve.
7. Landmarks/avenidas con más detalle (fachada comercial en planta baja).

## 6. Cómo regenerar los datos

```bash
cd /opt/server/apps/costa3d/tools/geo
# plano + grafo (cachea raw_osm.json)
.venv/bin/python build_blueprint.py --district nuevamalaga
# elevaciones (malla) -> out/nuevamalaga/elevacion.json  (script de muestreo DEM)
```

> Atribución obligatoria: datos de **OpenStreetMap (ODbL)**; elevación de **EU-DEM**
> (OpenTopoData, uso justo/atribución).

## 7. Cómo conseguir las "cuestas" y más realismo (estado y plan)

**Ya implementado**
- **Relieve real** (DEM) → hay **cuestas** de verdad (76 m de desnivel, hasta ~16 %).
  Todo (calles, edificios, props, spawn, jugador/NPCs/coches) se asienta sobre él.
- **Alturas reales** por `building:levels` (mediana 2 plantas) y **tejados
  inclinados** según `roof:shape` (gabled/hipped) con `roof:colour`.
- **Aceras** a ambos lados de cada calle + bordillos + línea central.
- **Peatonales** (57) excluidas del tráfico.

**Plan para acercarse aún más al mapa real**
1. **Escaleras reales (`steps`, 121 tramos)**: modelar como escalones con colisión
   transitable (o rampa de colisión + peldaños visuales). Hoy no se dibujan.
2. **Sentido único (`oneway`, 627)**: guardar `oneway` por arista del grafo y que
   el tráfico respete la dirección (rutas dirigidas).
3. **Jerarquía de vías**: avenidas más anchas con isletas y carril bici;
   diferenciar asfalto por `surface`.
4. **Parques y jardines** (409 + 18): césped con bordillo, caminos y árboles
   (ya hay árboles; falta delimitar y añadir caminos `footway`).
5. **Landmarks**: hitos del barrio (iglesia, mercado, colegio, pabellón) tomados
   de OSM (`amenity`, `building=church/school`) para orientarse.
6. **Materiales/colores** de fachada (`building:material`, `building:colour`) más
   finos (ladrillo vs revoco) y toldos/portales en planta baja.
7. **Continuidad de acera** en las intersecciones (hoy las aceras se cruzan).
8. **Agua/costa**: fuera de esta zona; si se amplía, usar `natural=coastline`.

> Regenerar tras cambios: `.venv/bin/python build_blueprint.py --district nuevamalaga`
> y copiar `blueprint.json`/`road_graph.json` a `game/data/`.
