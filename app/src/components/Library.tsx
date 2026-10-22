import { useMemo, useState } from 'react';
import type { ModuleDef } from '../lib/types';
import { setDraggingModule } from './CaseView';

interface Props {
  modules: ModuleDef[];
  categories: string[];
  onAdd: (id: string) => void;
}

const MATCH_LABEL = { original: 'original', aehnlich: 'ähnlich', ersatz: 'Ersatz' } as const;

export function Library({ modules, categories, onAdd }: Props) {
  const [q, setQ] = useState('');
  const [cat, setCat] = useState('');
  const [open, setOpen] = useState<string | null>(null);

  const list = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return modules.filter((m) => {
      if (cat && !m.category.includes(cat)) return false;
      if (!needle) return true;
      return [m.name, m.manufacturer, ...m.tags, ...m.category].some((s) => s.toLowerCase().includes(needle));
    });
  }, [modules, q, cat]);

  return (
    <section className="panel-box library">
      <h2>Module</h2>
      <div className="lib-filters">
        <input type="search" placeholder="Suche: Name, Hersteller, Tag …" value={q} onChange={(e) => setQ(e.target.value)} />
        <select value={cat} onChange={(e) => setCat(e.target.value)}>
          <option value="">Alle Kategorien</option>
          {categories.map((c) => (
            <option key={c} value={c}>{c}</option>
          ))}
        </select>
      </div>
      <ul className="lib-list">
        {list.map((m) => (
          <li
            key={m.id}
            draggable
            onDragStart={(e) => {
              e.dataTransfer.setData('text/module-id', m.id);
              e.dataTransfer.effectAllowed = 'copy';
              setDraggingModule(m.id);
            }}
            onDragEnd={() => setDraggingModule(null)}
          >
            <div className="lib-row">
              <button className="link" onClick={() => setOpen(open === m.id ? null : m.id)} title="Details">
                <strong>{m.name}</strong>
                <span className="muted"> · {m.manufacturer}</span>
              </button>
              <span className="lib-meta">
                {m.hp} HP{m.price_eur ? ` · ~${m.price_eur} €` : ''}
              </span>
              <button className="small" onClick={() => onAdd(m.id)} title="Ins Rack (erster freier Platz)">+</button>
            </div>
            <div className="chips">
              {m.status !== 'erhältlich' && <span className="chip warn">{m.status}</span>}
              {!m.verified && <span className="chip muted" title="Werte noch nicht gegen das Handbuch geprüft">ungeprüft</span>}
              {m.tags.slice(0, 4).map((t) => (
                <span key={t} className="chip">{t}</span>
              ))}
            </div>
            {open === m.id && (
              <div className="lib-details">
                {m.description && <p>{m.description}</p>}
                <p>
                  Strom: +12 V {m.power_ma.p12} mA · −12 V {m.power_ma.m12} mA · +5 V {m.power_ma.p5} mA
                  {m.depth_mm ? ` · Tiefe ${m.depth_mm} mm` : ''}
                </p>
                <p>
                  Digital:{' '}
                  {m.digital.length
                    ? m.digital.map((d) => `${d.ref} (${d.kind}, ${MATCH_LABEL[d.match]})`).join(', ')
                    : 'keins'}
                </p>
                <p className="muted">
                  Eingänge: {m.jacks.filter((j) => j.dir === 'in').map((j) => j.label).join(', ')}
                  <br />
                  Ausgänge: {m.jacks.filter((j) => j.dir === 'out').map((j) => j.label).join(', ')}
                </p>
              </div>
            )}
          </li>
        ))}
        {!list.length && <li className="muted">Keine Treffer.</li>}
      </ul>
    </section>
  );
}
