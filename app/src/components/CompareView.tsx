import { useState } from 'react';
import { RAILS, powerStatus, totalPrice } from '../lib/power';
import type { ModuleDb, Rack } from '../lib/types';

interface Props {
  racks: Rack[];
  db: ModuleDb;
}

function moduleCounts(r: Rack): Map<string, number> {
  const m = new Map<string, number>();
  for (const x of r.modules) m.set(x.module, (m.get(x.module) ?? 0) + 1);
  return m;
}

/** Module, die in `b` öfter vorkommen als in `a` */
function missing(a: Rack, b: Rack): { id: string; n: number }[] {
  const ca = moduleCounts(a);
  return [...moduleCounts(b)]
    .map(([id, n]) => ({ id, n: n - (ca.get(id) ?? 0) }))
    .filter((x) => x.n > 0);
}

export function CompareView({ racks, db }: Props) {
  const [a, setA] = useState(racks[0]?.id ?? '');
  const [b, setB] = useState(racks[1]?.id ?? racks[0]?.id ?? '');
  const ra = racks.find((r) => r.id === a) ?? racks[0];
  const rb = racks.find((r) => r.id === b) ?? racks[0];
  const toBuy = missing(ra, rb);
  const buyPrice = toBuy.reduce((s, x) => s + (db[x.id]?.price_eur ?? 0) * x.n, 0);

  return (
    <section className="panel-box">
      <h2>Rack-Varianten vergleichen</h2>
      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              <th>Rack</th>
              <th>Case</th>
              <th>HP belegt</th>
              {RAILS.map((r) => (
                <th key={r.key}>{r.label}</th>
              ))}
              <th>Preis</th>
              <th>Patches</th>
            </tr>
          </thead>
          <tbody>
            {racks.map((r) => {
              const st = powerStatus(r.modules, db, r.case.power);
              const hp = r.modules.reduce((s, m) => s + (db[m.module]?.hp ?? 0), 0);
              return (
                <tr key={r.id}>
                  <td>{r.name}</td>
                  <td>
                    {r.case.rows} × {r.case.hp} HP
                  </td>
                  <td>
                    {hp} / {r.case.rows * r.case.hp}
                  </td>
                  {RAILS.map((x) => (
                    <td key={x.key} className={`level-${st[x.key].level}`}>
                      {st[x.key].used} / {st[x.key].budget}
                    </td>
                  ))}
                  <td>ca. {totalPrice(r.modules, db).toLocaleString('de-DE')} €</td>
                  <td>{r.patches.length}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <h3>Einkaufsliste</h3>
      <div className="row-gap">
        Von
        <select value={ra.id} onChange={(e) => setA(e.target.value)}>
          {racks.map((r) => (
            <option key={r.id} value={r.id}>{r.name}</option>
          ))}
        </select>
        nach
        <select value={rb.id} onChange={(e) => setB(e.target.value)}>
          {racks.map((r) => (
            <option key={r.id} value={r.id}>{r.name}</option>
          ))}
        </select>
      </div>
      {toBuy.length ? (
        <>
          <ul className="plain">
            {toBuy.map((x) => (
              <li key={x.id}>
                {x.n} × {db[x.id]?.manufacturer} {db[x.id]?.name ?? x.id}
                {db[x.id]?.price_eur ? ` (ca. ${db[x.id].price_eur} €)` : ''}
              </li>
            ))}
          </ul>
          <p>Summe: ca. {buyPrice.toLocaleString('de-DE')} €</p>
        </>
      ) : (
        <p className="muted">Nichts zu kaufen – „{rb.name}“ enthält keine zusätzlichen Module.</p>
      )}
    </section>
  );
}
