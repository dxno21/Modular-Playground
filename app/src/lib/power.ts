import type { ModuleDb, Placed, Power } from './types';

export const RAILS: { key: keyof Power; label: string }[] = [
  { key: 'p12', label: '+12 V' },
  { key: 'm12', label: '−12 V' },
  { key: 'p5', label: '+5 V' },
];

export const WARN_RATIO = 0.8;

export type Level = 'ok' | 'warn' | 'over';

export interface RailStatus {
  used: number;
  budget: number;
  ratio: number;
  level: Level;
}

export function powerUsage(modules: Placed[], db: ModuleDb): Power {
  const sum: Power = { p12: 0, m12: 0, p5: 0 };
  for (const m of modules) {
    const p = db[m.module]?.power_ma;
    if (!p) continue;
    sum.p12 += p.p12;
    sum.m12 += p.m12;
    sum.p5 += p.p5;
  }
  return sum;
}

export function railStatus(used: number, budget: number): RailStatus {
  if (budget <= 0) {
    return { used, budget, ratio: used > 0 ? Infinity : 0, level: used > 0 ? 'over' : 'ok' };
  }
  const ratio = used / budget;
  const level: Level = ratio > 1 ? 'over' : ratio >= WARN_RATIO ? 'warn' : 'ok';
  return { used, budget, ratio, level };
}

export function powerStatus(modules: Placed[], db: ModuleDb, budget: Power): Record<keyof Power, RailStatus> {
  const used = powerUsage(modules, db);
  return {
    p12: railStatus(used.p12, budget.p12),
    m12: railStatus(used.m12, budget.m12),
    p5: railStatus(used.p5, budget.p5),
  };
}

export function totalPrice(modules: Placed[], db: ModuleDb): number {
  return modules.reduce((s, m) => s + (db[m.module]?.price_eur ?? 0), 0);
}

export function maxDepth(modules: Placed[], db: ModuleDb): number {
  return modules.reduce((d, m) => Math.max(d, db[m.module]?.depth_mm ?? 0), 0);
}
