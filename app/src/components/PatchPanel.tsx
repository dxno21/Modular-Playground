import { useState } from 'react';
import { cableLabel, patchWarnings } from '../lib/cables';
import { CABLE_COLORS } from '../lib/patch';
import type { ModuleDb, Patch, Rack } from '../lib/types';

interface Props {
  rack: Rack;
  db: ModuleDb;
  patch: Patch;
  color: string;
  selectedCable: string | null;
  selectedInstance: string | null;
  onColor: (c: string) => void;
  onPatchChange: (p: Patch) => void;
  onSelectPatch: (id: string) => void;
  onNewPatch: () => void;
  onDeletePatch: () => void;
  onDeleteCable: (id: string) => void;
  onRemoveModule: (instance: string) => void;
  onExport: () => void;
  onImport: (file: File) => void;
}

export function PatchPanel(p: Props) {
  const { rack, db, patch } = p;
  const warnings = patchWarnings(rack, db, patch);
  const cable = patch.cables.find((c) => c.id === p.selectedCable);
  const placed = rack.modules.find((m) => m.instance === p.selectedInstance);
  const def = placed && db[placed.module];
  const params = (placed && patch.params[placed.instance]) ?? {};
  const [paramName, setParamName] = useState('');

  const setParams = (next: Record<string, number>) =>
    p.onPatchChange({ ...patch, params: { ...patch.params, [placed!.instance]: next } });

  return (
    <section className="panel-box">
      <h2>Patch</h2>
      <div className="row-gap">
        <select value={patch.id} onChange={(e) => p.onSelectPatch(e.target.value)}>
          {rack.patches.map((x) => (
            <option key={x.id} value={x.id}>{x.name}</option>
          ))}
        </select>
        <button className="small" onClick={p.onNewPatch}>Neu</button>
        <button className="small" onClick={p.onDeletePatch} disabled={rack.patches.length < 2}>Löschen</button>
      </div>
      <div className="form-grid one">
        <label>
          Name
          <input value={patch.name} onChange={(e) => p.onPatchChange({ ...patch, name: e.target.value })} />
        </label>
        <label>
          Beschreibung
          <textarea rows={2} value={patch.description} onChange={(e) => p.onPatchChange({ ...patch, description: e.target.value })} />
        </label>
        <label>
          Tags (Komma-getrennt)
          <input
            value={patch.tags.join(', ')}
            onChange={(e) => p.onPatchChange({ ...patch, tags: e.target.value.split(',').map((t) => t.trim()).filter(Boolean) })}
          />
        </label>
        <label>
          Regler-Notizen
          <textarea rows={3} value={patch.notes} onChange={(e) => p.onPatchChange({ ...patch, notes: e.target.value })} />
        </label>
      </div>

      <h3>Kabelfarbe</h3>
      <div className="swatches">
        {CABLE_COLORS.map((c) => (
          <button
            key={c}
            className={`swatch${p.color === c ? ' active' : ''}`}
            style={{ background: c }}
            aria-label={`Farbe ${c}`}
            onClick={() => {
              p.onColor(c);
              if (cable) p.onPatchChange({ ...patch, cables: patch.cables.map((x) => (x.id === cable.id ? { ...x, color: c } : x)) });
            }}
          />
        ))}
      </div>
      <p className="muted small-text">
        Ausgang anklicken, dann Eingang. Kabel anklicken zum Auswählen. {patch.cables.length} Kabel im Patch.
      </p>

      {cable && (
        <div className="callout">
          <div>{cableLabel(rack, db, cable)}</div>
          <button className="small danger" onClick={() => p.onDeleteCable(cable.id)}>Kabel entfernen</button>
        </div>
      )}

      {warnings.length > 0 && (
        <>
          <h3>Hinweise</h3>
          <ul className="warnings">
            {warnings.map((w, i) => (
              <li key={i}>{w.text}</li>
            ))}
          </ul>
        </>
      )}

      {placed && def && (
        <>
          <h3>
            {def.name} <span className="muted">({placed.instance})</span>
          </h3>
          <p className="muted small-text">Regler 0.0–1.0, Namen wie in Tool 1 (M4L-Rack).</p>
          {Object.entries(params).map(([k, v]) => (
            <div key={k} className="param-row">
              <span>{k}</span>
              <input
                type="range"
                min={0}
                max={1}
                step={0.01}
                value={v}
                onChange={(e) => setParams({ ...params, [k]: Number(e.target.value) })}
              />
              <span className="mono">{v.toFixed(2)}</span>
              <button
                className="small"
                onClick={() => {
                  const next = { ...params };
                  delete next[k];
                  setParams(next);
                }}
              >
                ×
              </button>
            </div>
          ))}
          <form
            className="row-gap"
            onSubmit={(e) => {
              e.preventDefault();
              const name = paramName.trim().toLowerCase().replace(/\s+/g, '_');
              if (!name) return;
              setParams({ ...params, [name]: params[name] ?? 0.5 });
              setParamName('');
            }}
          >
            <input placeholder="Parameter, z.B. rate" value={paramName} onChange={(e) => setParamName(e.target.value)} />
            <button className="small" type="submit">+ Regler</button>
          </form>
          <button className="small danger" onClick={() => p.onRemoveModule(placed.instance)}>Modul aus Rack entfernen</button>
        </>
      )}

      <h3>Austausch (Tool 1 / Tool 2)</h3>
      <div className="row-gap">
        <button onClick={p.onExport}>Patch-JSON exportieren</button>
        <label className="button">
          Importieren
          <input
            type="file"
            accept="application/json,.json"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) p.onImport(f);
              e.target.value = '';
            }}
          />
        </label>
      </div>
    </section>
  );
}
