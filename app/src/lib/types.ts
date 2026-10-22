export type JackType = 'audio' | 'cv' | 'gate' | 'trigger' | 'clock' | 'pitch';
export type JackDir = 'in' | 'out';

export interface Jack {
  id: string;
  label: string;
  dir: JackDir;
  type: JackType;
}

export interface Power {
  p12: number;
  m12: number;
  p5: number;
}

export interface DigitalCounterpart {
  kind: 'vcv' | 'plugin' | 'm4l' | 'max-external';
  ref: string;
  match: 'original' | 'aehnlich' | 'ersatz';
}

export interface ModuleDef {
  id: string;
  manufacturer: string;
  name: string;
  category: string[];
  tags: string[];
  description?: string;
  hp: number;
  depth_mm?: number;
  power_ma: Power;
  price_eur?: number;
  status: 'erhältlich' | 'eingestellt' | 'gebraucht';
  verified?: boolean;
  jacks: Jack[];
  digital: DigitalCounterpart[];
  links?: { manufacturer?: string; manual?: string };
}

export type ModuleDb = Record<string, ModuleDef>;

export interface CaseConfig {
  rows: number;
  hp: number;
  /** Netzteil-Budget je Schiene in mA */
  power: Power;
}

export interface Placed {
  instance: string;
  module: string;
  row: number;
  x_hp: number;
}

export interface Endpoint {
  instance: string;
  jack: string;
}

export interface Cable {
  id: string;
  from: Endpoint;
  to: Endpoint;
  color: string;
}

export interface Patch {
  id: string;
  name: string;
  description: string;
  tags: string[];
  notes: string;
  /** Normalisierte Reglerwerte 0.0–1.0 je Instanz */
  params: Record<string, Record<string, number>>;
  cables: Cable[];
}

export interface Rack {
  id: string;
  name: string;
  case: CaseConfig;
  modules: Placed[];
  patches: Patch[];
  activePatch: string;
}

export interface AppState {
  racks: Rack[];
  activeRack: string;
}

/** Gemeinsames Patch-Format (schema/patch.schema.json) */
export interface PatchFile {
  format: 'modular-playground.patch';
  version: 1;
  name: string;
  description?: string;
  tags?: string[];
  modules: { instance: string; module: string; row?: number; x_hp?: number; params?: Record<string, number> }[];
  cables: { from: Endpoint; to: Endpoint; color?: string }[];
  notes?: string;
}
