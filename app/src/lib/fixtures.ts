import { MODULE_DB } from './modules';
import { emptyPatch } from './patch';
import type { Placed, Rack } from './types';

export const db = MODULE_DB;

export function rackWith(modules: Placed[], rows = 2, hp = 84): Rack {
  const p = emptyPatch();
  return {
    id: 'r1',
    name: 'Test',
    case: { rows, hp, power: { p12: 1000, m12: 500, p5: 0 } },
    modules,
    patches: [p],
    activePatch: p.id,
  };
}
