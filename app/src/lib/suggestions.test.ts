import { describe, expect, it } from 'vitest';
import { patchWarnings } from './cables';
import { MY_CASE } from './cases';
import { db } from './fixtures';
import { fromPatchFile } from './patch';
import { powerStatus } from './power';
import { SUGGESTIONS } from './suggestions';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const dir = join(__dirname, '../../../data/patches');

describe('Rack-Vorschläge', () => {
  it('werden geladen', () => {
    expect(SUGGESTIONS.length).toBeGreaterThanOrEqual(2);
  });

  for (const f of readdirSync(dir).filter((x) => x.endsWith('.patch.json'))) {
    it(`${f} passt ohne Umbau in ein Behringer-Case`, () => {
      const res = fromPatchFile(JSON.parse(readFileSync(join(dir, f), 'utf8')), db, MY_CASE.config);
      expect(res.ok).toBe(true);
      if (!res.ok) return;
      expect(res.warnings).toEqual([]);
      expect(res.rack.case).toEqual(MY_CASE.config);
      const st = powerStatus(res.rack.modules, db, res.rack.case.power);
      expect(Object.values(st).every((r) => r.level === 'ok')).toBe(true);
      expect(patchWarnings(res.rack, db, res.rack.patches[0])).toEqual([]);
    });
  }
});
