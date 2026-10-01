#!/usr/bin/env python3
"""
COSTA HASH 3D - Herramienta GEO (design-time)

Descarga datos reales de OpenStreetMap (Overpass API) de un distrito de Malaga
y genera un "plano de diseno" (blueprint) que sirve de guia para construir el
mapa low-poly del juego. NO se usa en runtime: el juego solo lleva geometria
pre-horneada.

Salidas (tools/geo/out/<slug>/):
  blueprint.json    - calles, edificios, agua, parques y costa en metros locales
  road_graph.json   - grafo de calles (nodos + aristas) para navegacion horneada
  blueprint.svg     - vista previa del plano para revisar el diseno
  stats.json        - contadores y metadatos

Uso:
  python build_blueprint.py                      # distrito por defecto
  python build_blueprint.py --district centro    # otro distrito de districts.json
  python build_blueprint.py --bbox S W N E --name "Mi zona"

Datos: OpenStreetMap, licencia ODbL (atribucion obligatoria).
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import unary_union

OVERPASS_ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://lz4.overpass-api.de/api/interpreter",
]

ROAD_CLASSES = {
    "motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link",
    "secondary", "secondary_link", "tertiary", "tertiary_link", "unclassified",
    "residential", "living_street", "service", "pedestrian", "road",
}

MIN_BUILDING_AREA_M2 = 12.0


def project(lon: float, lat: float, lat0: float, lon0: float) -> tuple[float, float]:
    """Equirectangular local: devuelve (x, y) en metros con origen (lat0, lon0)."""
    x = (lon - lon0) * 111320.0 * math.cos(math.radians(lat0))
    y = (lat - lat0) * 110540.0
    return (x, y)


def overpass_query(query: str, retries: int = 4) -> dict:
    last_err: Exception | None = None
    for attempt in range(retries):
        url = OVERPASS_ENDPOINTS[attempt % len(OVERPASS_ENDPOINTS)]
        try:
            data = urllib.parse.urlencode({"data": query}).encode()
            req = urllib.request.Request(
                url, data=data, headers={"User-Agent": "costa-hash-3d/0.1 (geo design-time)"}
            )
            with urllib.request.urlopen(req, timeout=180) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
            last_err = exc
            wait = 5 * (attempt + 1)
            print(f"  aviso: fallo Overpass ({exc}); reintento en {wait}s...", file=sys.stderr)
            time.sleep(wait)
    raise RuntimeError(f"Overpass no responde: {last_err}")


def build_query(bbox: tuple[float, float, float, float]) -> str:
    s, w, n, e = bbox
    box = f"{s},{w},{n},{e}"
    return f"""
[out:json][timeout:180];
(
  way["highway"]({box});
  way["building"]({box});
  way["natural"="water"]({box});
  way["natural"="coastline"]({box});
  way["waterway"]({box});
  way["leisure"~"^(park|garden|nature_reserve)$"]({box});
);
out geom;
"""


POI_AMENITY = ("place_of_worship|school|college|university|hospital|clinic|doctors|"
               "pharmacy|marketplace|police|townhall|fire_station|library|"
               "community_centre|bank|post_office|fuel")
POI_TOURISM = "hotel|museum|attraction|viewpoint"
POI_SHOP = "supermarket|mall|department_store"
POI_LEISURE = "sports_centre|stadium"

# amenity -> tipo de landmark (para darle una forma/signo reconocible)
AMENITY_KIND = {
    "place_of_worship": "church",
    "hospital": "health", "clinic": "health", "doctors": "health",
    "pharmacy": "pharmacy",
    "school": "school", "college": "school", "university": "school",
    "marketplace": "market",
    "police": "police",
    "townhall": "townhall",
    "fire_station": "fire",
    "library": "library",
    "bank": "bank",
    "post_office": "post",
    "fuel": "fuel",
    "community_centre": "community",
}


def build_poi_query(bbox: tuple[float, float, float, float]) -> str:
    s, w, n, e = bbox
    box = f"{s},{w},{n},{e}"
    return f"""
[out:json][timeout:120];
(
  nwr["amenity"~"^({POI_AMENITY})$"]({box});
  nwr["tourism"~"^({POI_TOURISM})$"]({box});
  nwr["shop"~"^({POI_SHOP})$"]({box});
  nwr["leisure"~"^({POI_LEISURE})$"]({box});
);
out center tags;
"""


def process_pois(elements: list[dict], lat0: float, lon0: float,
                 bbox: tuple) -> list[dict]:
    """Extrae puntos de interes con su posicion local y un tipo reconocible."""
    s, w, n, e = bbox
    xs = [project(w, s, lat0, lon0)[0], project(e, n, lat0, lon0)[0]]
    ys = [project(w, s, lat0, lon0)[1], project(e, n, lat0, lon0)[1]]
    clip = box(min(xs), min(ys), max(xs), max(ys))
    out = []
    for el in elements:
        tags = el.get("tags", {})
        if el.get("type") == "node":
            lat, lon = el.get("lat"), el.get("lon")
        elif "center" in el:
            lat, lon = el["center"]["lat"], el["center"]["lon"]
        else:
            continue
        if lat is None:
            continue
        kind = ""
        if "amenity" in tags:
            kind = AMENITY_KIND.get(tags["amenity"], "")
        elif "tourism" in tags:
            kind = {"hotel": "hotel", "museum": "museum"}.get(tags["tourism"], "")
        elif tags.get("shop") in ("supermarket", "mall", "department_store"):
            kind = "supermarket"
        elif tags.get("leisure") in ("sports_centre", "stadium", "pitch", "swimming_pool"):
            kind = "sports"
        if not kind:
            continue
        x, y = project(lon, lat, lat0, lon0)
        if not clip.contains(Point(x, y)):
            continue
        out.append({"kind": kind, "name": tags.get("name", ""),
                    "x": round(x, 1), "y": round(y, 1)})
    # Limitar secundarios (evita cientos de farmacias/bancos) conservando hitos.
    major = {"church", "health", "school", "market", "police", "townhall",
             "fire", "library", "museum", "hotel", "community"}
    cap = 6
    counts: dict[str, int] = {}
    filtered = []
    for lm in out:
        if lm["kind"] in major:
            filtered.append(lm)
            continue
        counts[lm["kind"]] = counts.get(lm["kind"], 0) + 1
        if counts[lm["kind"]] <= cap:
            filtered.append(lm)
    return filtered


def parse_levels(tags: dict) -> float:
    """Plantas del edificio (building:levels) o altura directa. -1 si no hay."""
    for key in ("building:levels", "levels"):
        if key in tags:
            try:
                return max(1.0, float(str(tags[key]).split(";")[0]))
            except ValueError:
                pass
    if "height" in tags:
        try:
            return max(1.0, float(str(tags["height"]).replace("m", "").strip()) / 3.0)
        except ValueError:
            pass
    return -1.0


def _norm_color(v: str) -> str:
    v = str(v).strip()
    if v.startswith("#"):
        v = v[1:]
    return v.upper() if len(v) == 6 else ""


def sample_elevation(bbox, nx: int = 26, ny: int = 26,
                     cache_path: str = "", refresh: bool = False) -> dict:
    """Muestrea elevacion (EU-DEM 25m via OpenTopoData) en una malla lat/lon y la
    devuelve en coordenadas locales (metros) lista para el bilineal del juego."""
    if cache_path and os.path.exists(cache_path) and not refresh:
        with open(cache_path, encoding="utf-8") as fh:
            return json.load(fh)
    s, w, n, e = bbox
    lat0 = (s + n) / 2.0
    lon0 = (w + e) / 2.0
    lats = [s + (n - s) * iy / (ny - 1) for iy in range(ny)]
    lons = [w + (e - w) * ix / (nx - 1) for ix in range(nx)]
    locs = [(la, lo) for la in lats for lo in lons]
    heights: list[float] = []
    for i in range(0, len(locs), 100):
        chunk = locs[i:i + 100]
        q = "|".join(f"{la:.5f},{lo:.5f}" for la, lo in chunk)
        url = "https://api.opentopodata.org/v1/eudem25m?locations=" + urllib.parse.quote(q)
        req = urllib.request.Request(url, headers={"User-Agent": "costa3d-geo/1.0"})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(req, timeout=40) as r:
                    res = json.load(r)["results"]
                heights.extend(float(x["elevation"]) for x in res)
                break
            except Exception as ex:
                print(f"    elevacion intento {attempt + 1} fallo: {ex}", file=sys.stderr)
                time.sleep(2.0)
        time.sleep(1.1)
    x0 = (w - lon0) * 111320.0 * math.cos(math.radians(lat0))
    x1 = (e - lon0) * 111320.0 * math.cos(math.radians(lat0))
    y0 = (s - lat0) * 110540.0
    y1 = (n - lat0) * 110540.0
    terr = {
        "nx": nx, "ny": ny,
        "x0": round(x0, 2), "y0": round(y0, 2),
        "step_x": round((x1 - x0) / (nx - 1), 3),
        "step_y": round((y1 - y0) / (ny - 1), 3),
        "min": round(min(heights), 1), "max": round(max(heights), 1),
        "h": [round(v, 2) for v in heights],
    }
    if cache_path:
        with open(cache_path, "w", encoding="utf-8") as fh:
            json.dump(terr, fh)
    return terr


def geometry_to_meters(geom, lat0: float, lon0: float) -> list[list[float]]:
    return [[round(x, 2), round(y, 2)] for x, y in
            (project(pt["lon"], pt["lat"], lat0, lon0) for pt in geom)]


def simplify_pts(coords, tol: float) -> list[list[float]]:
    if len(coords) < 2:
        return coords
    line = LineString(coords)
    return [[round(x, 2), round(y, 2)] for x, y in line.simplify(tol, preserve_topology=True).coords]


def line_parts(geom) -> list:
    """Extrae LineStrings de una geometria (recursivo)."""
    if geom.is_empty:
        return []
    t = geom.geom_type
    if t in ("LineString", "LinearRing"):
        return [geom]
    if t == "MultiLineString" or t == "GeometryCollection":
        out = []
        for g in geom.geoms:
            out.extend(line_parts(g))
        return out
    # Polygon -> contorno
    if t == "Polygon":
        return [geom.exterior]
    if t == "MultiPolygon":
        return [g.exterior for g in geom.geoms]
    return []


def poly_parts(geom) -> list:
    """Extrae Polygonos de una geometria."""
    if geom.is_empty:
        return []
    t = geom.geom_type
    if t == "Polygon":
        return [geom]
    if t in ("MultiPolygon", "GeometryCollection"):
        out = []
        for g in geom.geoms:
            out.extend(poly_parts(g))
        return out
    return []


def process(elements: list[dict], lat0: float, lon0: float, bbox: tuple):
    s, w, n, e = bbox
    xs = [project(w, s, lat0, lon0)[0], project(e, n, lat0, lon0)[0]]
    ys = [project(w, s, lat0, lon0)[1], project(e, n, lat0, lon0)[1]]
    clip = box(min(xs), min(ys), max(xs), max(ys))

    roads, buildings, water, parks, coastline = [], [], [], [], []
    rivers = []
    stairs = []
    for el in elements:
        if el.get("type") != "way" or not el.get("geometry"):
            continue
        tags = el.get("tags", {})
        raw = geometry_to_meters(el["geometry"], lat0, lon0)
        if len(raw) < 2:
            continue

        road_cls = tags.get("highway")
        # Escaleras (steps): se guardan aparte para dibujarlas como peldaños.
        if road_cls == "steps":
            geom = LineString(raw).intersection(clip)
            for part in line_parts(geom):
                if part.length < 1.5:
                    continue
                stairs.append({"id": el["id"],
                               "pts": simplify_pts([[x, y] for x, y in part.coords], 0.6)})
            continue
        if road_cls in ROAD_CLASSES:
            geom = LineString(raw).intersection(clip)
            for part in line_parts(geom):
                if part.length < 2.0:
                    continue
                pts = simplify_pts([[x, y] for x, y in part.coords], 1.2)
                if len(pts) >= 2:
                    roads.append({"id": el["id"], "class": road_cls,
                                  "name": tags.get("name", ""),
                                  "oneway": tags.get("oneway", "no") in ("yes", "1", "true"),
                                  "pts": pts})
        elif tags.get("building"):
            if len(raw) >= 4:
                poly = Polygon(raw)
                if not poly.is_valid:
                    poly = poly.buffer(0)
                for part in poly_parts(poly.intersection(clip)):
                    if part.area < MIN_BUILDING_AREA_M2:
                        continue
                    b = {"id": el["id"],
                         "pts": simplify_pts(list(part.exterior.coords), 0.5)}
                    lv = parse_levels(tags)
                    if lv > 0:
                        b["levels"] = lv
                    col = _norm_color(tags.get("building:colour", ""))
                    if col:
                        b["colour"] = col
                    rcol = _norm_color(tags.get("roof:colour", ""))
                    if rcol:
                        b["roof_colour"] = rcol
                    rs = tags.get("roof:shape", "")
                    if rs:
                        b["roof_shape"] = rs
                    buildings.append(b)
        elif tags.get("natural") == "coastline":
            geom = LineString(raw).intersection(clip)
            for part in line_parts(geom):
                if part.length < 2.0:
                    continue
                coastline.append({"id": el["id"],
                                  "pts": simplify_pts([[x, y] for x, y in part.coords], 3.0)})
        elif tags.get("waterway"):
            geom = LineString(raw).intersection(clip)
            for part in line_parts(geom):
                if part.length < 3.0:
                    continue
                rivers.append({"id": el["id"],
                               "pts": simplify_pts([[x, y] for x, y in part.coords], 3.0)})
        elif tags.get("natural") == "water":
            if len(raw) >= 4:
                poly = Polygon(raw)
                if not poly.is_valid:
                    poly = poly.buffer(0)
                for part in poly_parts(poly.intersection(clip)):
                    if part.area < 100.0:
                        continue
                    water.append({"id": el["id"],
                                  "pts": simplify_pts(list(part.exterior.coords), 2.0)})
        elif tags.get("leisure") in ("park", "garden", "nature_reserve"):
            if len(raw) >= 4:
                poly = Polygon(raw)
                if not poly.is_valid:
                    poly = poly.buffer(0)
                for part in poly_parts(poly.intersection(clip)):
                    if part.area < 50.0:
                        continue
                    parks.append({"id": el["id"],
                                  "pts": simplify_pts(list(part.exterior.coords), 2.0)})

    return roads, buildings, water, parks, coastline, rivers, stairs


def _tangent(line, pt, span: float = 0.6) -> tuple[float, float]:
    """Direccion unitaria de `line` en el punto mas cercano a `pt`."""
    p = line.project(pt)
    a = line.interpolate(max(0.0, p - span))
    b = line.interpolate(min(line.length, p + span))
    dx, dy = b.x - a.x, b.y - a.y
    norm = math.hypot(dx, dy) or 1.0
    return (dx / norm, dy / norm)


def build_graph(roads: list[dict]) -> dict:
    """Grafo de calles (noda intersecciones). Cada arista lleva si es de sentido
    unico y su clase; las de sentido unico se orientan segun la via real."""
    road_geoms = []
    for r in roads:
        if len(r["pts"]) >= 2:
            try:
                road_geoms.append((LineString(r["pts"]),
                                   bool(r.get("oneway", False)),
                                   str(r.get("class", ""))))
            except Exception:
                continue
    if not road_geoms:
        return {"nodes": [], "edges": []}

    merged = unary_union([g for g, _, _ in road_geoms])
    segs = list(merged.geoms) if merged.geom_type == "MultiLineString" else [merged]

    index: dict[tuple[int, int], int] = {}
    nodes: list[list[float]] = []
    edges: list[dict] = []

    def node_id(pt) -> int:
        key = (round(pt[0] * 2), round(pt[1] * 2))  # ~0.5 m
        if key not in index:
            index[key] = len(nodes)
            nodes.append([round(pt[0], 2), round(pt[1], 2)])
        return index[key]

    for seg in segs:
        cs = list(seg.coords)
        if len(cs) < 2:
            continue
        length = seg.length
        if length < 3.0:
            continue
        a = node_id(cs[0])
        b = node_id(cs[-1])
        if a == b:
            continue
        # Atributos de la via original mas cercana al punto medio.
        mid = seg.interpolate(0.5, normalized=True)
        ow = False
        cls = ""
        best_d = 6.0
        best_road = None
        for g, o, c in road_geoms:
            d = g.distance(mid)
            if d < best_d:
                best_d = d
                ow, cls, best_road = o, c, g
        if ow and best_road is not None:
            st = _tangent(seg, mid)
            rt = _tangent(best_road, mid)
            if (st[0] * rt[0] + st[1] * rt[1]) < 0.0:
                a, b = b, a  # invertir para seguir la via real
        edges.append({"a": a, "b": b, "len": round(length, 1),
                      "oneway": ow, "class": cls})

    return {"nodes": [{"id": i, "p": p} for i, p in enumerate(nodes)], "edges": edges}


def write_svg(path: str, roads, buildings, water, parks, coastline, rivers) -> tuple[float, float]:
    all_pts = []
    for group in (roads, buildings, water, parks, coastline, rivers):
        for item in group:
            all_pts.extend(item["pts"])
    if not all_pts:
        return 0.0, 0.0
    minx = min(p[0] for p in all_pts); maxx = max(p[0] for p in all_pts)
    miny = min(p[1] for p in all_pts); maxy = max(p[1] for p in all_pts)
    w = max(maxx - minx, 1.0); h = max(maxy - miny, 1.0)
    pad = 20

    def sx(x): return pad + (x - minx)
    def sy(y): return pad + (maxy - y)

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w + 2*pad:.0f}" '
        f'height="{h + 2*pad:.0f}" viewBox="0 0 {w + 2*pad:.0f} {h + 2*pad:.0f}">',
        '<rect width="100%" height="100%" fill="#0e1020"/>',
    ]

    def poly(item, fill, stroke="none", sw=0):
        pts = " ".join(f"{sx(x):.1f},{sy(y):.1f}" for x, y in item["pts"])
        parts.append(f'<polygon points="{pts}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')

    def line(item, stroke, sw):
        pts = " ".join(f"{sx(x):.1f},{sy(y):.1f}" for x, y in item["pts"])
        parts.append(f'<polyline points="{pts}" fill="none" stroke="{stroke}" stroke-width="{sw}"/>')

    for it in water: poly(it, "#123a6b")
    for it in parks: poly(it, "#1d4d2b")
    for it in buildings: poly(it, "#2b2f45", "#3a405c", 0.4)
    for it in roads: line(it, "#6b7280", 1.4 if it["class"] not in ("primary", "secondary", "tertiary") else 2.4)
    for it in rivers: line(it, "#2f7fd6", 1.6)
    for it in coastline: line(it, "#2ea3ff", 2.0)

    parts.append("</svg>")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(parts))
    return w, h


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "districts.json"), encoding="utf-8") as fh:
        districts = json.load(fh)

    ap = argparse.ArgumentParser(description="Genera el plano de diseno desde OSM")
    ap.add_argument("--district", default="centro")
    ap.add_argument("--bbox", nargs=4, type=float, metavar=("S", "W", "N", "E"))
    ap.add_argument("--name")
    ap.add_argument("--slug")
    ap.add_argument("--refresh", action="store_true", help="Ignora la cache y vuelve a descargar")
    args = ap.parse_args()

    if args.bbox:
        bbox = tuple(args.bbox)
        name = args.name or "Zona personalizada"
        slug = args.slug or "custom"
    else:
        if args.district not in districts:
            print(f"distrito desconocido: {args.district}. Opciones: {', '.join(districts)}", file=sys.stderr)
            return 2
        d = districts[args.district]
        bbox = tuple(d["bbox"])
        name = args.name or d["name"]
        slug = args.slug or args.district

    s, w, n, e = bbox
    lat0 = (s + n) / 2.0
    lon0 = (w + e) / 2.0

    outdir = os.path.join(here, "out", slug)
    os.makedirs(outdir, exist_ok=True)

    print(f"[{name}] bbox={bbox}")
    raw_path = os.path.join(outdir, "raw_osm.json")
    if os.path.exists(raw_path) and not args.refresh:
        print("  usando cache raw_osm.json")
        with open(raw_path, encoding="utf-8") as fh:
            data = json.load(fh)
    else:
        print("  consultando Overpass...")
        data = overpass_query(build_query(bbox))
        with open(raw_path, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False)
    elements = data.get("elements", [])
    print(f"  elementos recibidos: {len(elements)}")

    roads, buildings, water, parks, coastline, rivers, stairs = process(elements, lat0, lon0, bbox)
    print(f"  calles={len(roads)} edificios={len(buildings)} agua={len(water)} "
          f"parques={len(parks)} costa={len(coastline)} rios={len(rivers)} escaleras={len(stairs)}")

    terrain = sample_elevation(bbox, cache_path=os.path.join(outdir, "terrain.json"),
                               refresh=args.refresh)
    print(f"  relieve: {terrain['min']}..{terrain['max']} m ({terrain['max'] - terrain['min']:.0f} m)")

    # Puntos de interes (iglesias, salud, colegios, mercados...) con su posicion.
    poi_path = os.path.join(outdir, "raw_poi.json")
    if os.path.exists(poi_path) and not args.refresh:
        print("  usando cache raw_poi.json")
        with open(poi_path, encoding="utf-8") as fh:
            pdata = json.load(fh)
    else:
        print("  consultando POIs...")
        pdata = overpass_query(build_poi_query(bbox))
        with open(poi_path, "w", encoding="utf-8") as fh:
            json.dump(pdata, fh, ensure_ascii=False)
    landmarks = process_pois(pdata.get("elements", []), lat0, lon0, bbox)
    from collections import Counter
    print(f"  landmarks={len(landmarks)} {dict(Counter(l['kind'] for l in landmarks))}")

    # El trafico NO debe circular por calles peatonales.
    drivable = [r for r in roads if r["class"] not in ("pedestrian",)]
    graph = build_graph(drivable)
    print(f"  grafo: {len(graph['nodes'])} nodos, {len(graph['edges'])} aristas")

    meta = {
        "district": name,
        "slug": slug,
        "source": "OpenStreetMap (ODbL) - https://www.openstreetmap.org/copyright",
        "bbox": list(bbox),
        "origin": [lat0, lon0],
        "units": "meters (local equirectangular, origin=bbox center)",
        "generated": datetime.now(timezone.utc).isoformat(),
    }

    blueprint = {"meta": meta, "roads": roads, "buildings": buildings,
                 "water": water, "parks": parks, "coastline": coastline,
                 "rivers": rivers, "stairs": stairs, "terrain": terrain,
                 "landmarks": landmarks}
    with open(os.path.join(outdir, "blueprint.json"), "w", encoding="utf-8") as fh:
        json.dump(blueprint, fh, ensure_ascii=False)
    with open(os.path.join(outdir, "road_graph.json"), "w", encoding="utf-8") as fh:
        json.dump({"meta": meta, **graph}, fh, ensure_ascii=False)

    w_m, h_m = write_svg(os.path.join(outdir, "blueprint.svg"),
                         roads, buildings, water, parks, coastline, rivers)
    stats = {
        "roads": len(roads), "buildings": len(buildings), "water": len(water),
        "parks": len(parks), "coastline": len(coastline), "rivers": len(rivers),
        "graph_nodes": len(graph["nodes"]), "graph_edges": len(graph["edges"]),
        "terrain_m": [terrain["min"], terrain["max"]],
        "stairs": len(stairs), "landmarks": len(landmarks),
        "buildings_with_levels": sum(1 for b in buildings if "levels" in b),
        "extent_m": [round(w_m, 1), round(h_m, 1)],
        "bbox": list(bbox), "district": name, "generated": meta["generated"],
    }
    with open(os.path.join(outdir, "stats.json"), "w", encoding="utf-8") as fh:
        json.dump(stats, fh, ensure_ascii=False, indent=2)

    print(f"  OK -> {outdir}")
    print(f"  extension: {w_m:.0f} x {h_m:.0f} m")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
