import type { Jack, ModuleDef, Placed, Rack, ModuleDb } from './types';

/** Eurorack-Maße in mm */
export const HP_MM = 5.08;
export const ROW_MM = 128.5;

const HEADER_MM = 20;
const JACK_AREA_MM = ROW_MM - HEADER_MM - 6;
const MIN_COL_MM = 12.5;

export interface Point {
  x: number;
  y: number;
}

/** Position jedes Jacks relativ zur linken oberen Ecke des Moduls (mm). */
export function jackLayout(def: ModuleDef): Record<string, Point> {
  const width = def.hp * HP_MM;
  const cols = Math.max(1, Math.floor(width / MIN_COL_MM));
  const rows = Math.ceil(def.jacks.length / cols);
  const colW = width / cols;
  const rowH = Math.min(20, JACK_AREA_MM / Math.max(rows, 1));
  const top = HEADER_MM + (JACK_AREA_MM - rowH * rows) / 2;
  const out: Record<string, Point> = {};
  def.jacks.forEach((j: Jack, i) => {
    const c = i % cols;
    const r = Math.floor(i / cols);
    out[j.id] = { x: colW * (c + 0.5), y: top + rowH * (r + 0.5) };
  });
  return out;
}

export function moduleOrigin(p: Pick<Placed, 'row' | 'x_hp'>): Point {
  return { x: p.x_hp * HP_MM, y: p.row * ROW_MM };
}

/** Absolute Jack-Position im Case (mm) oder null, wenn unbekannt. */
export function jackPosition(rack: Rack, db: ModuleDb, instance: string, jack: string): Point | null {
  const placed = rack.modules.find((m) => m.instance === instance);
  const def = placed && db[placed.module];
  if (!placed || !def) return null;
  const rel = jackLayout(def)[jack];
  if (!rel) return null;
  const o = moduleOrigin(placed);
  return { x: o.x + rel.x, y: o.y + rel.y };
}

export function distanceMm(a: Point, b: Point): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}
