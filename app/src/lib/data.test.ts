import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { formatErrors, validateModuleJson, validatePatchJson } from './schema';

const dir = join(__dirname, '../../../data/modules');
const files = readdirSync(dir).filter((f) => f.endsWith('.json'));

describe('Modul-Datenbank', () => {
  it('hat mindestens 10 Module', () => {
    expect(files.length).toBeGreaterThanOrEqual(10);
  });

  for (const f of files) {
    it(`${f} ist gültig`, () => {
      const m = JSON.parse(readFileSync(join(dir, f), 'utf8'));
      const ok = validateModuleJson(m);
      expect(formatErrors(validateModuleJson.errors)).toEqual([]);
      expect(ok).toBe(true);
      expect(f).toBe(`${m.id}.json`);
      const ids = m.jacks.map((j: { id: string }) => j.id);
      expect(new Set(ids).size).toBe(ids.length);
    });
  }
});

describe('Patch-Schema', () => {
  it('akzeptiert das Beispiel aus dem Briefing', () => {
    const example = {
      format: 'modular-playground.patch',
      version: 1,
      name: 'Metal Rumble 01',
      description: '',
      tags: ['hypnotic'],
      modules: [
        { instance: 'm1', module: 'mutable-marbles', row: 0, x_hp: 0, params: { rate: 0.4 } },
        { instance: 'm2', module: 'mutable-rings', row: 0, x_hp: 18, params: {} },
      ],
      cables: [{ from: { instance: 'm1', jack: 't1' }, to: { instance: 'm2', jack: 'strum' }, color: '#e5484d' }],
      notes: '',
    };
    expect(validatePatchJson(example)).toBe(true);
  });

  it('lehnt Parameter außerhalb 0–1 ab', () => {
    const bad = {
      format: 'modular-playground.patch',
      version: 1,
      name: 'x',
      modules: [{ instance: 'm1', module: 'mutable-rings', params: { damp: 1.5 } }],
      cables: [],
    };
    expect(validatePatchJson(bad)).toBe(false);
  });
});
