# Auditoría de DISEÑO — Costa Hash 3D

> Revisión de dirección de arte, mundo, UI y experiencia, y **cómo un agente puede
> mejorarlo de forma autónoma** (bucle medir → proponer → aplicar → verificar).
> Estado a 2026-09-29.

## 1. Identidad y objetivo

- **Tema**: Costa del Sol (Málaga), barrio de **Nueva Málaga**. Open-world arcade
  de trapicheo, tercera persona, **web/móvil primero** (WebGL2/Compatibility).
- **Estilo**: low-poly, colores planos, **mediterráneo claro** (blanco/crema/
  arena), cielo luminoso, sombras suaves.
- **Pilares**: mundo creíble y vivo · conducción arcade satisfactoria · progresión
  clara (rango, dinero, respeto) · coste ligero en móvil.

## 2. Estado actual (diseño)

| Área | Estado | Nota |
|------|--------|------|
| Mundo | 🟢 **relieve real (76 m)**, edificios de **mediana 2 plantas**, fachadas con ventanas, tejados inclinados, aceras/bordillos/líneas | gran salto de fidelidad |
| Iluminación | 🟢 día/noche con sol, cielo procedural, niebla; **noche clara** | sombras off en móvil (coste) |
| Prop "vivo" | 🟢 farolas (encendidas de noche), árboles, semáforos, tráfico y peatones por aceras | falta variedad y densidad |
| Suelo | 🟡 terreno con relieve + plancha base; falta textura/variación de suelo | aspecto "verde liso" |
| UI | 🟢 HUD (dinero, hora/día, vida, estamina, radar+GPS, mapa M), móvil (producto/placa/mejoras/garaje/mecánico/viaje/calidad) | texto aún genérico |
| Audio | 🟡 CC0 + motor/sirena procedurales; audio 2D (+3D en motor/sirena) | falta música dinámica y ambiente |
| Personajes | 🟢 misma biblioteca (mini/blocky), variedad por rol/ropa, animaciones cruzadas | ver `NPCS_AUDITORIA.md` |
| Vehículos | 🟢 coches Kenney + **moto procedural**; física anti-vuelco; luces | falta variedad de motos/camiones propios |

## 3. Diagnóstico (qué "canta" todavía)

1. **Suelo demasiado liso/verde**: uniforme; falta rotura visual (parterres,
   asfalto más oscuro, manchas, sombras de contacto).
2. **Falta de landmarks**: todo se parece; conviene hitos (una plaza, una iglesia,
   el mercado, el polideportivo) que ayuden a orientarse.
3. **Legibilidad urbana**: manzanas muy densas; falta jerarquía de vías
   (ensanchar avenidas, carriles bici, isletas).
4. **Densidad de props**: aceras vacías; faltan bancos, papeleras, paradas de bus,
   señales, contenedores, toldos (ya hay modelos en `city/`).
5. **UI genérica**: la fuente por defecto y textos planos; falta estilo.
6. **Audio plano**: sin ambiente de ciudad (tráfico lejano, gaviotas, gente).
7. **Interiores/tejados habitables**: todo cerrado; no hace falta aún, pero da vida.

## 4. Plan de diseño priorizado (impacto/esfuerzo)

**Quick wins**
1. **Paleta de suelo**: asfalto más oscuro + acera más clara + zonas verdes con
   leve variación por vértice → rompe el "verde liso".
2. **Landmarks**: 6-10 hitos (plaza, iglesia, mercado, pabellón, colegio) con un
   modelo distinto y algo de detalle; se ven desde lejos y guían.
3. **Densidad de props por acera**: bancos, papeleras, paradas, señales, toldos,
   contenedores (modelos ya descargados). Instanciado por `MultiMesh`.
4. **Jerarquía de calles**: avenidas más anchas + isletas + carril bici (colores).
5. **UI con estilo**: tipografías y paleta propias (estilo móvil/servilleta).
6. **Ambiente sonoro**: capas de tráfico lejano, viento, gaviotas; radio de coche.

**Medio plazo**
7. **Verticalidad**: azoteas transitables, muros/barandillas en pendientes,
   escaleras reales (`steps` de OSM, 121 tramos).
8. **Clima**: lluvia + carretera mojada (shader), atardeceres marcados.
9. **Vistas**: miradores en las cotas altas (la zona sube 76 m → hay vistas al mar).
10. **Vida social**: grupos de peatones charlando, terrazas con gente.

## 5. Cómo puede ayudarte el agente de forma autónoma

El agente **ya tiene un bucle objetivo** para iterar diseño sin pedir permiso:

1. **Instrumentación**: `tools/smoke|look|move|drive|cam|turn|flip|touchui|moto-map-test.mjs`
   (Playwright + Chrome software) generan capturas y cuentan errores de consola.
2. **Métricas automáticas**: errores JS, FPS, draw calls (vía `Performance`),
   cobertura de paleta, contraste de sombras, nº de props/NPCs.
3. **Criterios de diseño** (checklist que el agente aplica a cada captura):
   - ¿Se distinguen avenidas de calles? ¿Hay hitos memorables?
   - ¿El suelo tiene rotura visual? ¿Sombras de contacto?
   - ¿Los NPCs parecen vivos y variados? ¿Están en la acera?
   - ¿La paleta es coherente (mediterránea) y el contraste legible?
   - ¿La UI se lee a 720p y en móvil?
4. **Bucle**: captura → crítica (checklist) → parche de código → reexport →
   verificación (smoke + capturas) → commit del cambio solo si mejora métricas.
5. **A/B**: para decisiones dudosas (p. ej. densidad de props) genera dos builds
   y compara capturas/métricas.
6. **Guardarraíles**: el agente mantiene el estilo low-poly/mediterráneo, no sube
   el coste en móvil (respeta la calidad adaptativa) y documenta en PENDIENTES.md.

> En resumen: el agente puede **autoaplicar** mejoras de diseño (paleta de suelo,
> props, landmarks, UI) validadas por capturas, y avisarte solo de lo ambiguo.

## 6. Referencias de estilo (gratuitas y legales)

- Packs **CC0 de Kenney** (city/car/characters) ya integrados.
- **Quaternius** (CC0) para más personajes/animaciones (`Universal Animation
  Library`, 120+ anims) si se quiere ampliar.
- Principios: lectura por **silueta**, **paleta limitada**, **contraste de valor**,
  **detalle cerca / simple lejos** (LOD).
