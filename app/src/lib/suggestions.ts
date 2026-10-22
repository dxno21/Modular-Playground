import { MY_CASE } from './cases';
import { MODULE_DB } from './modules';
import { fromPatchFile } from './patch';
import type { Rack } from './types';

const files = import.meta.glob('../../../data/patches/*.patch.json', { eager: true, import: 'default' });

/** Rack-Vorschläge aus data/patches, jeweils im eigenen Behringer-Case */
export const SUGGESTIONS = Object.entries(files)
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([path, json]) => ({
    id: path.split('/').pop()!.replace('.patch.json', ''),
    name: (json as { name: string }).name,
    load(): Rack {
      const res = fromPatchFile(json, MODULE_DB, MY_CASE.config);
      if (!res.ok) throw new Error(`Vorschlag ${path} ungültig: ${res.errors.join('; ')}`);
      return res.rack;
    },
  }));
