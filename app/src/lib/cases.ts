import type { CaseConfig } from './types';

export interface CasePreset {
  id: string;
  label: string;
  config: CaseConfig;
  note?: string;
}

/** Werte laut Händlerangaben – vor dem Kauf mit dem Herstellerhandbuch abgleichen. */
export const CASE_PRESETS: CasePreset[] = [
  {
    id: 'behringer-eurorack-go',
    label: 'Behringer Eurorack Go (2 × 140 HP)',
    config: { rows: 2, hp: 140, power: { p12: 3000, m12: 1000, p5: 1000 } },
    note: 'Netzteil in 3 Zonen à 1 A aufgeteilt; Modultiefe max. 40 mm (unten) / 62 mm (oben).',
  },
];
