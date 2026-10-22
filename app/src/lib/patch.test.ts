import { describe, expect, it } from 'vitest';
import { db, rackWith } from './fixtures';
import { fromPatchFile, toPatchFile } from './patch';
import { validatePatchJson } from './schema';

describe('Patch-Export/-Import', () => {
  const rack = rackWith([
    { instance: 'm1', module: 'mutable-marbles', row: 0, x_hp: 0 },
    { instance: 'm2', module: 'mutable-rings', row: 0, x_hp: 18 },
  ]);
  const patch = {
    ...rack.patches[0],
    name: 'Metal Rumble 01',
    tags: ['hypnotic'],
    params: { m1: { rate: 0.4 } },
    cables: [{ id: 'c1', from: { instance: 'm1', jack: 't1' }, to: { instance: 'm2', jack: 'strum' }, color: '#e5484d' }],
  };

  it('exportiert schema-konform', () => {
    const file = toPatchFile(rack, patch);
    expect(validatePatchJson(file)).toBe(true);
    expect(file.modules[0].params).toEqual({ rate: 0.4 });
  });

  it('Rundreise erhält Module, Kabel und Regler', () => {
    const res = fromPatchFile(JSON.parse(JSON.stringify(toPatchFile(rack, patch))), db);
    expect(res.ok).toBe(true);
    if (!res.ok) return;
    expect(res.warnings).toEqual([]);
    expect(res.rack.modules).toEqual(rack.modules);
    const p = res.rack.patches[0];
    expect(p.cables.map((c) => [c.from, c.to])).toEqual([[{ instance: 'm1', jack: 't1' }, { instance: 'm2', jack: 'strum' }]]);
    expect(p.params).toEqual({ m1: { rate: 0.4 } });
  });

  it('überspringt Tool-1-Module ohne Hardware und deren Kabel', () => {
    const file = toPatchFile(rack, patch);
    file.modules.push({ instance: 'm9', module: 'm4l-metal-perc', params: {} });
    file.cables.push({ from: { instance: 'm9', jack: 'out' }, to: { instance: 'm2', jack: 'in' } });
    const res = fromPatchFile(file, db);
    expect(res.ok).toBe(true);
    if (!res.ok) return;
    expect(res.rack.modules).toHaveLength(2);
    expect(res.rack.patches[0].cables).toHaveLength(1);
    expect(res.warnings.length).toBe(2);
  });

  it('platziert überlappende oder positionslose Module neu und vergrößert das Case', () => {
    const res = fromPatchFile(
      {
        format: 'modular-playground.patch',
        version: 1,
        name: 'x',
        modules: [
          { instance: 'a', module: 'mutable-rings', row: 0, x_hp: 0 },
          { instance: 'b', module: 'mutable-rings', row: 0, x_hp: 4 },
          { instance: 'c', module: 'mutable-plaits', row: 3, x_hp: 0 },
        ],
        cables: [],
      },
      db,
    );
    expect(res.ok).toBe(true);
    if (!res.ok) return;
    expect(res.rack.case.rows).toBe(4);
    expect(res.rack.modules.find((m) => m.instance === 'b')).toMatchObject({ row: 0, x_hp: 14 });
  });

  it('meldet Schema-Fehler', () => {
    const res = fromPatchFile({ format: 'falsch' }, db);
    expect(res.ok).toBe(false);
  });
});
