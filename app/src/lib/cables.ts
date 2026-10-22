import { distanceMm, jackPosition } from './geometry';
import type { Endpoint, Jack, JackType, ModuleDb, Patch, Rack } from './types';

export function findJack(rack: Rack, db: ModuleDb, ep: Endpoint): Jack | undefined {
  const placed = rack.modules.find((m) => m.instance === ep.instance);
  return placed ? db[placed.module]?.jacks.find((j) => j.id === ep.jack) : undefined;
}

export function sameEndpoint(a: Endpoint, b: Endpoint): boolean {
  return a.instance === b.instance && a.jack === b.jack;
}

/** Gibt ein Paar in Richtung Ausgang → Eingang zurück (Klickreihenfolge ist egal). */
export function orient(rack: Rack, db: ModuleDb, a: Endpoint, b: Endpoint): { from: Endpoint; to: Endpoint } {
  const ja = findJack(rack, db, a);
  return ja?.dir === 'in' ? { from: b, to: a } : { from: a, to: b };
}

const GATE_FAMILY: JackType[] = ['gate', 'trigger', 'clock'];

/** Hinweis bei Typ-Mismatch (z.B. Audio in Clock), sonst null. */
export function typeMismatch(from: JackType, to: JackType): string | null {
  if (from === to) return null;
  if (from === 'audio' && GATE_FAMILY.includes(to)) return `Audio in ${to.toUpperCase()}-Eingang`;
  if (GATE_FAMILY.includes(from) && to === 'pitch') return `${from.toUpperCase()} in Pitch-Eingang (V/Oct)`;
  if (GATE_FAMILY.includes(from) && to === 'audio') return `${from.toUpperCase()} in Audio-Eingang`;
  return null;
}

export type CableCheck = { ok: true; warnings: string[] } | { ok: false; error: string };

export function validateCable(rack: Rack, db: ModuleDb, patch: Patch, from: Endpoint, to: Endpoint): CableCheck {
  if (sameEndpoint(from, to)) return { ok: false, error: 'Gleicher Jack' };
  const jf = findJack(rack, db, from);
  const jt = findJack(rack, db, to);
  if (!jf || !jt) return { ok: false, error: 'Jack nicht gefunden' };
  if (jf.dir !== 'out' || jt.dir !== 'in') return { ok: false, error: 'Nur Ausgang → Eingang erlaubt' };
  if (patch.cables.some((c) => sameEndpoint(c.to, to))) {
    return { ok: false, error: `Eingang ${jt.label} ist schon belegt` };
  }
  const warnings: string[] = [];
  if (patch.cables.some((c) => sameEndpoint(c.from, from))) {
    warnings.push(`Ausgang ${jf.label} hat schon ein Kabel – Mult nötig?`);
  }
  const mm = typeMismatch(jf.type, jt.type);
  if (mm) warnings.push(mm);
  return { ok: true, warnings };
}

/** Hinweise für alle Kabel eines Patches. */
export function patchWarnings(rack: Rack, db: ModuleDb, patch: Patch): { cableId: string; text: string }[] {
  const out: { cableId: string; text: string }[] = [];
  const fromCount = new Map<string, number>();
  for (const c of patch.cables) {
    const k = `${c.from.instance}.${c.from.jack}`;
    fromCount.set(k, (fromCount.get(k) ?? 0) + 1);
  }
  for (const c of patch.cables) {
    const jf = findJack(rack, db, c.from);
    const jt = findJack(rack, db, c.to);
    if (!jf || !jt) {
      out.push({ cableId: c.id, text: 'Kabel zeigt auf fehlenden Jack' });
      continue;
    }
    const n = fromCount.get(`${c.from.instance}.${c.from.jack}`) ?? 0;
    if (n > 1) out.push({ cableId: c.id, text: `${endpointLabel(rack, db, c.from)} geht an ${n} Ziele – Mult nötig?` });
    const mm = typeMismatch(jf.type, jt.type);
    if (mm) out.push({ cableId: c.id, text: `${cableLabel(rack, db, c)}: ${mm}` });
  }
  return out;
}

export function endpointLabel(rack: Rack, db: ModuleDb, ep: Endpoint): string {
  const placed = rack.modules.find((m) => m.instance === ep.instance);
  const def = placed && db[placed.module];
  const jack = def?.jacks.find((j) => j.id === ep.jack);
  return `${def?.name ?? ep.instance} ${jack?.label ?? ep.jack}`;
}

export function cableLabel(rack: Rack, db: ModuleDb, c: { from: Endpoint; to: Endpoint }): string {
  return `${endpointLabel(rack, db, c.from)} → ${endpointLabel(rack, db, c.to)}`;
}

/** Übliche Patchkabel-Längen in cm */
export const STANDARD_LENGTHS_CM = [10, 15, 20, 30, 45, 60, 90, 120];

/** Geschätzte Kabellänge: Luftlinie plus Durchhang und Stecker-Reserve. */
export function estimateLengthCm(distMm: number): number {
  return (distMm * 1.25) / 10 + 6;
}

export function standardLength(cm: number): number {
  return STANDARD_LENGTHS_CM.find((l) => l >= cm) ?? STANDARD_LENGTHS_CM[STANDARD_LENGTHS_CM.length - 1];
}

export interface CableListRow {
  id: string;
  from: string;
  to: string;
  color: string;
  estimateCm: number | null;
  lengthCm: number | null;
}

export function cableList(rack: Rack, db: ModuleDb, patch: Patch): CableListRow[] {
  return patch.cables.map((c) => {
    const a = jackPosition(rack, db, c.from.instance, c.from.jack);
    const b = jackPosition(rack, db, c.to.instance, c.to.jack);
    const est = a && b ? estimateLengthCm(distanceMm(a, b)) : null;
    return {
      id: c.id,
      from: endpointLabel(rack, db, c.from),
      to: endpointLabel(rack, db, c.to),
      color: c.color,
      estimateCm: est === null ? null : Math.round(est),
      lengthCm: est === null ? null : standardLength(est),
    };
  });
}

/** Anzahl Kabel je Standardlänge, aufsteigend sortiert. */
export function lengthSummary(rows: CableListRow[]): { lengthCm: number; count: number }[] {
  const m = new Map<number, number>();
  for (const r of rows) if (r.lengthCm !== null) m.set(r.lengthCm, (m.get(r.lengthCm) ?? 0) + 1);
  return [...m.entries()].sort((a, b) => a[0] - b[0]).map(([lengthCm, count]) => ({ lengthCm, count }));
}

/** Entfernt alle Kabel, die eine Instanz berühren. */
export function withoutInstance(patch: Patch, instance: string): Patch {
  const params = { ...patch.params };
  delete params[instance];
  return {
    ...patch,
    params,
    cables: patch.cables.filter((c) => c.from.instance !== instance && c.to.instance !== instance),
  };
}
