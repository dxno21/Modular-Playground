import type { ModuleDb, ModuleDef } from './types';

const files = import.meta.glob<ModuleDef>('../../../data/modules/*.json', { eager: true, import: 'default' });

export const MODULES: ModuleDef[] = Object.values(files).sort(
  (a, b) => a.manufacturer.localeCompare(b.manufacturer) || a.name.localeCompare(b.name),
);

export const MODULE_DB: ModuleDb = Object.fromEntries(MODULES.map((m) => [m.id, m]));

export const CATEGORIES: string[] = [...new Set(MODULES.flatMap((m) => m.category))].sort();
