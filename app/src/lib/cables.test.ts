import { describe, expect, it } from 'vitest';
import { cableList, estimateLengthCm, lengthSummary, orient, patchWarnings, standardLength, validateCable, withoutInstance } from './cables';
import { db, rackWith } from './fixtures';
import type { Patch } from './types';

const rack = rackWith([
  { instance: 'm1', module: 'mutable-marbles', row: 0, x_hp: 0 },
  { instance: 'm2', module: 'mutable-rings', row: 0, x_hp: 18 },
  { instance: 'm3', module: 'mutable-plaits', row: 1, x_hp: 0 },
]);
const base = rack.patches[0];
const withCable = (p: Patch, from: [string, string], to: [string, string]): Patch => ({
  ...p,
  cables: [...p.cables, { id: `${from}-${to}`, from: { instance: from[0], jack: from[1] }, to: { instance: to[0], jack: to[1] }, color: '#e5484d' }],
});

describe('Kabelvalidierung', () => {
  it('erlaubt Ausgang → Eingang', () => {
    const r = validateCable(rack, db, base, { instance: 'm1', jack: 't1' }, { instance: 'm2', jack: 'strum' });
    expect(r).toEqual({ ok: true, warnings: [] });
  });

  it('dreht die Klickreihenfolge um', () => {
    const o = orient(rack, db, { instance: 'm2', jack: 'strum' }, { instance: 'm1', jack: 't1' });
    expect(o.from).toEqual({ instance: 'm1', jack: 't1' });
  });

  it('lehnt Eingang → Eingang und Ausgang → Ausgang ab', () => {
    expect(validateCable(rack, db, base, { instance: 'm2', jack: 'in' }, { instance: 'm2', jack: 'strum' }).ok).toBe(false);
    expect(validateCable(rack, db, base, { instance: 'm2', jack: 'odd' }, { instance: 'm3', jack: 'out' }).ok).toBe(false);
  });

  it('erlaubt höchstens ein Kabel pro Eingang', () => {
    const p = withCable(base, ['m1', 't1'], ['m2', 'strum']);
    const r = validateCable(rack, db, p, { instance: 'm1', jack: 't3' }, { instance: 'm2', jack: 'strum' });
    expect(r.ok).toBe(false);
  });

  it('weist auf Mult hin, wenn ein Ausgang mehrfach genutzt wird', () => {
    const p = withCable(base, ['m1', 't1'], ['m2', 'strum']);
    const r = validateCable(rack, db, p, { instance: 'm1', jack: 't1' }, { instance: 'm3', jack: 'trig' });
    expect(r.ok && r.warnings.some((w) => w.includes('Mult'))).toBe(true);
    const p2 = withCable(p, ['m1', 't1'], ['m3', 'trig']);
    expect(patchWarnings(rack, db, p2).filter((w) => w.text.includes('Mult'))).toHaveLength(2);
  });

  it('warnt bei Typ-Mismatch (Audio in Clock)', () => {
    const r = validateCable(rack, db, base, { instance: 'm3', jack: 'out' }, { instance: 'm1', jack: 't_clock' });
    expect(r.ok && r.warnings.some((w) => w.includes('Audio'))).toBe(true);
  });
});

describe('Kabelliste', () => {
  it('schätzt Längen und gruppiert', () => {
    let p = withCable(base, ['m1', 't1'], ['m2', 'strum']);
    p = withCable(p, ['m2', 'odd'], ['m3', 'fm']);
    const rows = cableList(rack, db, p);
    expect(rows[0].from).toBe('Marbles T1');
    expect(rows[0].to).toBe('Rings STRUM');
    expect(rows.every((r) => r.lengthCm !== null)).toBe(true);
    expect(lengthSummary(rows).reduce((s, x) => s + x.count, 0)).toBe(2);
  });

  it('rundet auf Standardlängen', () => {
    expect(standardLength(12)).toBe(15);
    expect(standardLength(30)).toBe(30);
    expect(standardLength(500)).toBe(120);
    expect(estimateLengthCm(0)).toBeGreaterThan(0);
  });

  it('entfernt Kabel eines gelöschten Moduls', () => {
    const p = withCable(withCable(base, ['m1', 't1'], ['m2', 'strum']), ['m2', 'odd'], ['m3', 'fm']);
    expect(withoutInstance(p, 'm1').cables).toHaveLength(1);
  });
});
