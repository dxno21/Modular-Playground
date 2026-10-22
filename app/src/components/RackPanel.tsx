import { RAILS, maxDepth, powerStatus, totalPrice } from '../lib/power';
import { usedHpPerRow } from '../lib/layout';
import type { CaseConfig, ModuleDb, Rack } from '../lib/types';

interface Props {
  rack: Rack;
  db: ModuleDb;
  onCaseChange: (c: CaseConfig) => void;
}

const LEVEL_TEXT = { ok: '', warn: ' – über 80 %', over: ' – Budget überschritten!' };

export function RackPanel({ rack, db, onCaseChange }: Props) {
  const status = powerStatus(rack.modules, db, rack.case.power);
  const used = usedHpPerRow(rack, db);
  const total = rack.case.rows * rack.case.hp;
  const usedTotal = used.reduce((a, b) => a + b, 0);
  const num = (v: string, min = 0) => Math.max(min, Math.round(Number(v) || 0));

  return (
    <section className="panel-box">
      <h2>Case</h2>
      <div className="form-grid">
        <label>
          Reihen
          <input type="number" min={1} max={8} value={rack.case.rows} onChange={(e) => onCaseChange({ ...rack.case, rows: num(e.target.value, 1) })} />
        </label>
        <label>
          HP je Reihe
          <input type="number" min={4} max={168} value={rack.case.hp} onChange={(e) => onCaseChange({ ...rack.case, hp: num(e.target.value, 4) })} />
        </label>
        {RAILS.map((r) => (
          <label key={r.key}>
            Budget {r.label} (mA)
            <input
              type="number"
              min={0}
              step={50}
              value={rack.case.power[r.key]}
              onChange={(e) => onCaseChange({ ...rack.case, power: { ...rack.case.power, [r.key]: num(e.target.value) } })}
            />
          </label>
        ))}
      </div>

      <h3>HP</h3>
      <p>
        {usedTotal} / {total} HP belegt · {total - usedTotal} HP frei
      </p>
      <ul className="plain">
        {used.map((u, i) => (
          <li key={i}>
            Reihe {i + 1}: {u} / {rack.case.hp} HP ({rack.case.hp - u} frei)
          </li>
        ))}
      </ul>

      <h3>Strom</h3>
      {RAILS.map((r) => {
        const s = status[r.key];
        const pct = s.budget > 0 ? Math.min(100, s.ratio * 100) : s.used > 0 ? 100 : 0;
        return (
          <div key={r.key} className={`meter level-${s.level}`}>
            <div className="meter-label">
              {r.label}: {s.used} / {s.budget} mA{s.budget > 0 ? ` (${Math.round(s.ratio * 100)} %)` : ''}
              {LEVEL_TEXT[s.level]}
            </div>
            <div className="meter-track">
              <div className="meter-fill" style={{ width: `${pct}%` }} />
            </div>
          </div>
        );
      })}

      <h3>Summe</h3>
      <p>
        {rack.modules.length} Module · ca. {totalPrice(rack.modules, db).toLocaleString('de-DE')} € · max. Tiefe{' '}
        {maxDepth(rack.modules, db)} mm
      </p>
    </section>
  );
}
