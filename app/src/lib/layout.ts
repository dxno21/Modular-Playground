import type { ModuleDb, Placed, Rack } from './types';

export interface PlaceCheck {
  ok: boolean;
  reason?: string;
}

/** Prüft, ob ein Modul an (row, x_hp) passt. `ignore` = Instanz, die gerade verschoben wird. */
export function canPlace(
  rack: Rack,
  db: ModuleDb,
  moduleId: string,
  row: number,
  x_hp: number,
  ignore?: string,
): PlaceCheck {
  const def = db[moduleId];
  if (!def) return { ok: false, reason: `Unbekanntes Modul: ${moduleId}` };
  if (row < 0 || row >= rack.case.rows) return { ok: false, reason: 'Reihe existiert nicht' };
  if (x_hp < 0 || x_hp + def.hp > rack.case.hp) return { ok: false, reason: 'Passt nicht in die Reihe' };
  for (const m of rack.modules) {
    if (m.instance === ignore || m.row !== row) continue;
    const other = db[m.module];
    if (!other) continue;
    if (x_hp < m.x_hp + other.hp && m.x_hp < x_hp + def.hp) {
      return { ok: false, reason: `Kollision mit ${other.name}` };
    }
  }
  return { ok: true };
}

/** Erster freier Platz (Reihe für Reihe von links), bevorzugt in `preferRow`. */
export function findFreeSpot(
  rack: Rack,
  db: ModuleDb,
  moduleId: string,
  preferRow?: number,
): { row: number; x_hp: number } | null {
  const def = db[moduleId];
  if (!def) return null;
  const rows = [...Array(rack.case.rows).keys()];
  if (preferRow !== undefined && preferRow >= 0 && preferRow < rack.case.rows) {
    rows.splice(rows.indexOf(preferRow), 1);
    rows.unshift(preferRow);
  }
  for (const row of rows) {
    for (let x = 0; x + def.hp <= rack.case.hp; x++) {
      if (canPlace(rack, db, moduleId, row, x).ok) return { row, x_hp: x };
    }
  }
  return null;
}

/** Nächster freier Platz in einer Reihe, ausgehend von einer Wunschposition. */
export function nearestSpotInRow(
  rack: Rack,
  db: ModuleDb,
  moduleId: string,
  row: number,
  wantX: number,
  ignore?: string,
): number | null {
  const def = db[moduleId];
  if (!def) return null;
  for (let d = 0; d <= rack.case.hp; d++) {
    for (const x of [wantX - d, wantX + d]) {
      if (canPlace(rack, db, moduleId, row, x, ignore).ok) return x;
    }
  }
  return null;
}

export function usedHpPerRow(rack: Rack, db: ModuleDb): number[] {
  const used = Array(rack.case.rows).fill(0);
  for (const m of rack.modules) {
    if (m.row < used.length) used[m.row] += db[m.module]?.hp ?? 0;
  }
  return used;
}

export function nextInstanceId(modules: Placed[]): string {
  let n = 1;
  const taken = new Set(modules.map((m) => m.instance));
  while (taken.has(`m${n}`)) n++;
  return `m${n}`;
}
