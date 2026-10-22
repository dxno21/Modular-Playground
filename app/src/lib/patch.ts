import { findJack } from './cables';
import { canPlace, findFreeSpot } from './layout';
import { formatErrors, validatePatchJson } from './schema';
import type { CaseConfig, ModuleDb, Patch, PatchFile, Placed, Rack } from './types';
import { uid } from './uid';

export const DEFAULT_CASE: CaseConfig = { rows: 2, hp: 84, power: { p12: 1200, m12: 1200, p5: 0 } };

export const CABLE_COLORS = ['#e5484d', '#f5a524', '#f2e14c', '#46a758', '#3e9bd6', '#8e4ec6', '#e2e2e2', '#222222'];

export function emptyPatch(name = 'Patch 1'): Patch {
  return { id: uid(), name, description: '', tags: [], notes: '', params: {}, cables: [] };
}

/** Rack + ein Patch → gemeinsames Patch-Format */
export function toPatchFile(rack: Rack, patch: Patch): PatchFile {
  return {
    format: 'modular-playground.patch',
    version: 1,
    name: patch.name,
    description: patch.description,
    tags: patch.tags,
    modules: rack.modules.map((m) => ({
      instance: m.instance,
      module: m.module,
      row: m.row,
      x_hp: m.x_hp,
      params: patch.params[m.instance] ?? {},
    })),
    cables: patch.cables.map((c) => ({ from: c.from, to: c.to, color: c.color })),
    notes: patch.notes,
  };
}

export type ImportResult = { ok: true; rack: Rack; warnings: string[] } | { ok: false; errors: string[] };

/** Patch-JSON → neues Rack. Unbekannte Module (z.B. `m4l-…` aus Tool 1) werden übersprungen. */
export function fromPatchFile(json: unknown, db: ModuleDb, caseCfg: CaseConfig = DEFAULT_CASE): ImportResult {
  if (!validatePatchJson(json)) return { ok: false, errors: formatErrors(validatePatchJson.errors) };
  const file = json as unknown as PatchFile;
  const warnings: string[] = [];

  const seen = new Set<string>();
  for (const m of file.modules) {
    if (seen.has(m.instance)) return { ok: false, errors: [`Instanz doppelt: ${m.instance}`] };
    seen.add(m.instance);
  }

  const known = file.modules.filter((m) => {
    if (db[m.module]) return true;
    warnings.push(`Modul „${m.module}“ (${m.instance}) ist nicht in der Datenbank – übersprungen`);
    return false;
  });

  // Case groß genug machen: Reihen und HP aus den Positionen ableiten.
  const neededRows = Math.max(caseCfg.rows, ...known.map((m) => (m.row ?? 0) + 1));
  const neededHp = Math.max(caseCfg.hp, ...known.map((m) => (m.x_hp ?? 0) + db[m.module].hp));
  const rack: Rack = {
    id: uid(),
    name: file.name,
    case: { ...caseCfg, rows: neededRows, hp: neededHp },
    modules: [],
    patches: [],
    activePatch: '',
  };

  const placedLater: typeof known = [];
  for (const m of known) {
    if (m.row !== undefined && m.x_hp !== undefined && canPlace(rack, db, m.module, m.row, m.x_hp).ok) {
      rack.modules.push({ instance: m.instance, module: m.module, row: m.row, x_hp: m.x_hp });
    } else {
      placedLater.push(m);
    }
  }
  for (const m of placedLater) {
    let spot = findFreeSpot(rack, db, m.module);
    if (!spot) {
      rack.case = { ...rack.case, rows: rack.case.rows + 1 };
      spot = findFreeSpot(rack, db, m.module)!;
    }
    if (m.row !== undefined) warnings.push(`${m.instance} überlappt – neu platziert`);
    rack.modules.push({ instance: m.instance, module: m.module, ...spot } satisfies Placed);
  }

  const patch = emptyPatch(file.name);
  patch.description = file.description ?? '';
  patch.tags = file.tags ?? [];
  patch.notes = file.notes ?? '';
  for (const m of known) if (m.params && Object.keys(m.params).length) patch.params[m.instance] = { ...m.params };

  for (const c of file.cables) {
    const jf = findJack(rack, db, c.from);
    const jt = findJack(rack, db, c.to);
    if (!jf || !jt) {
      warnings.push(`Kabel ${c.from.instance}.${c.from.jack} → ${c.to.instance}.${c.to.jack}: Jack fehlt – übersprungen`);
      continue;
    }
    if (jf.dir !== 'out' || jt.dir !== 'in') {
      warnings.push(`Kabel ${c.from.instance}.${c.from.jack} → ${c.to.instance}.${c.to.jack}: falsche Richtung – übersprungen`);
      continue;
    }
    if (patch.cables.some((x) => x.to.instance === c.to.instance && x.to.jack === c.to.jack)) {
      warnings.push(`Eingang ${c.to.instance}.${c.to.jack} doppelt belegt – zweites Kabel übersprungen`);
      continue;
    }
    patch.cables.push({ id: uid(), from: c.from, to: c.to, color: c.color ?? CABLE_COLORS[0] });
  }

  rack.patches = [patch];
  rack.activePatch = patch.id;
  return { ok: true, rack, warnings };
}
