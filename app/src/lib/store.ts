import { withoutInstance } from './cables';
import { DEFAULT_CASE, emptyPatch } from './patch';
import type { AppState, Patch, Rack } from './types';
import { uid } from './uid';

const STORAGE_KEY = 'modular-playground.hardware-planer.v1';

export function newRack(name: string): Rack {
  const patch = emptyPatch();
  return { id: uid(), name, case: structuredClone(DEFAULT_CASE), modules: [], patches: [patch], activePatch: patch.id };
}

export function initialState(): AppState {
  const ist = newRack('Ist-Rack');
  const wunsch = newRack('Wunsch-Rack');
  return { racks: [ist, wunsch], activeRack: ist.id };
}

export function loadState(): AppState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const s = JSON.parse(raw) as AppState;
      if (Array.isArray(s.racks) && s.racks.length) return s;
    }
  } catch {
    // Kein Zugriff auf localStorage oder kaputte Daten: mit leerem Zustand starten.
  }
  return initialState();
}

export function saveState(s: AppState): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
  } catch {
    // Speichern ist nur Komfort; Export bleibt möglich.
  }
}

export function activeRack(s: AppState): Rack {
  return s.racks.find((r) => r.id === s.activeRack) ?? s.racks[0];
}

export function activePatch(r: Rack): Patch {
  return r.patches.find((p) => p.id === r.activePatch) ?? r.patches[0];
}

export function updateRack(s: AppState, id: string, fn: (r: Rack) => Rack): AppState {
  return { ...s, racks: s.racks.map((r) => (r.id === id ? fn(r) : r)) };
}

export function updatePatch(r: Rack, id: string, fn: (p: Patch) => Patch): Rack {
  return { ...r, patches: r.patches.map((p) => (p.id === id ? fn(p) : p)) };
}

export function removeModule(r: Rack, instance: string): Rack {
  return {
    ...r,
    modules: r.modules.filter((m) => m.instance !== instance),
    patches: r.patches.map((p) => withoutInstance(p, instance)),
  };
}

export function duplicateRack(r: Rack, name: string): Rack {
  const copy = structuredClone(r);
  const ids = new Map<string, string>();
  copy.patches = copy.patches.map((p) => {
    const id = uid();
    ids.set(p.id, id);
    return { ...p, id };
  });
  return { ...copy, id: uid(), name, activePatch: ids.get(r.activePatch) ?? copy.patches[0].id };
}
