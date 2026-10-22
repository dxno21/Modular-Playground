import { cableList, lengthSummary } from '../lib/cables';
import type { ModuleDb, Patch, Rack } from '../lib/types';

interface Props {
  rack: Rack;
  db: ModuleDb;
  patch: Patch;
}

export function CableListView({ rack, db, patch }: Props) {
  const rows = cableList(rack, db, patch);
  const summary = lengthSummary(rows);
  const params = Object.entries(patch.params).filter(([, v]) => Object.keys(v).length);

  return (
    <section className="panel-box print-area">
      <div className="row-gap no-print">
        <button onClick={() => window.print()}>Drucken</button>
      </div>
      <h2>
        {patch.name} <span className="muted">· {rack.name}</span>
      </h2>
      {patch.description && <p>{patch.description}</p>}
      {patch.tags.length > 0 && <p className="muted">Tags: {patch.tags.join(', ')}</p>}

      <ol className="cable-list">
        {rows.map((r) => (
          <li key={r.id}>
            <span className="dot" style={{ background: r.color }} />
            <span className="cable-text">
              {r.from} → {r.to}
            </span>
            <span className="mono muted">{r.lengthCm !== null ? `${r.lengthCm} cm` : '–'}</span>
          </li>
        ))}
        {!rows.length && <li className="muted">Noch keine Kabel.</li>}
      </ol>

      {summary.length > 0 && (
        <>
          <h3>Kabel nach Länge</h3>
          <p className="muted small-text">Schätzung: Abstand der Buchsen + Durchhang, aufgerundet auf übliche Längen.</p>
          <ul className="plain">
            {summary.map((s) => (
              <li key={s.lengthCm}>
                {s.count} × {s.lengthCm} cm
              </li>
            ))}
          </ul>
        </>
      )}

      {params.length > 0 && (
        <>
          <h3>Regler</h3>
          <ul className="plain">
            {params.map(([inst, vals]) => {
              const m = rack.modules.find((x) => x.instance === inst);
              return (
                <li key={inst}>
                  <strong>{(m && db[m.module]?.name) ?? inst}</strong>:{' '}
                  {Object.entries(vals).map(([k, v]) => `${k} ${v.toFixed(2)}`).join(', ')}
                </li>
              );
            })}
          </ul>
        </>
      )}
      {patch.notes && (
        <>
          <h3>Notizen</h3>
          <p className="pre">{patch.notes}</p>
        </>
      )}
    </section>
  );
}
