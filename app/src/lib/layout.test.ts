import { describe, expect, it } from 'vitest';
import { db, rackWith } from './fixtures';
import { canPlace, findFreeSpot, nearestSpotInRow, nextInstanceId, usedHpPerRow } from './layout';
import { powerStatus, railStatus, totalPrice } from './power';

describe('Case-Layout', () => {
  const rack = rackWith([{ instance: 'm1', module: 'mutable-rings', row: 0, x_hp: 10 }]); // 14 HP: 10–23

  it('erkennt Kollisionen', () => {
    expect(canPlace(rack, db, 'mutable-plaits', 0, 0).ok).toBe(false); // 0–11 überlappt 10
    expect(canPlace(rack, db, 'mutable-plaits', 0, 24).ok).toBe(true);
    expect(canPlace(rack, db, 'mutable-plaits', 1, 0).ok).toBe(true);
  });

  it('prüft Ränder und Reihen', () => {
    expect(canPlace(rack, db, 'mutable-plaits', 0, 73).ok).toBe(false); // 73 + 12 > 84
    expect(canPlace(rack, db, 'mutable-plaits', 0, 72).ok).toBe(true);
    expect(canPlace(rack, db, 'mutable-plaits', 2, 0).ok).toBe(false);
    expect(canPlace(rack, db, 'mutable-plaits', 0, -1).ok).toBe(false);
  });

  it('ignoriert das verschobene Modul selbst', () => {
    expect(canPlace(rack, db, 'mutable-rings', 0, 12, 'm1').ok).toBe(true);
  });

  it('findet freie Plätze', () => {
    expect(findFreeSpot(rack, db, 'mutable-plaits')).toEqual({ row: 0, x_hp: 24 });
    expect(findFreeSpot(rack, db, 'mutable-plaits', 1)).toEqual({ row: 1, x_hp: 0 });
    expect(nearestSpotInRow(rack, db, 'mutable-plaits', 0, 8)).toBe(24);
    const full = rackWith([], 1, 10);
    expect(findFreeSpot(full, db, 'mutable-plaits')).toBeNull();
  });

  it('zählt HP und vergibt Instanz-IDs', () => {
    expect(usedHpPerRow(rack, db)).toEqual([14, 0]);
    expect(nextInstanceId(rack.modules)).toBe('m2');
  });
});

describe('Strom und Preis', () => {
  it('summiert je Schiene', () => {
    const rack = rackWith([
      { instance: 'm1', module: 'mutable-rings', row: 0, x_hp: 0 },
      { instance: 'm2', module: 'makenoise-maths', row: 0, x_hp: 14 },
    ]);
    const st = powerStatus(rack.modules, db, rack.case.power);
    expect(st.p12.used).toBe(180);
    expect(st.m12.used).toBe(55);
    expect(st.p12.level).toBe('ok');
    expect(totalPrice(rack.modules, db)).toBe(580);
  });

  it('warnt ab 80 % und bei Überschreitung', () => {
    expect(railStatus(79, 100).level).toBe('ok');
    expect(railStatus(80, 100).level).toBe('warn');
    expect(railStatus(101, 100).level).toBe('over');
    expect(railStatus(10, 0).level).toBe('over');
    expect(railStatus(0, 0).level).toBe('ok');
  });
});
