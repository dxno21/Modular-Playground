import { useEffect, useState } from 'react';
import { CaseView } from './components/CaseView';
import { CableListView } from './components/CableListView';
import { CompareView } from './components/CompareView';
import { Library } from './components/Library';
import { PatchPanel } from './components/PatchPanel';
import { RackPanel } from './components/RackPanel';
import { orient, validateCable } from './lib/cables';
import { HP_MM } from './lib/geometry';
import { canPlace, findFreeSpot, nearestSpotInRow, nextInstanceId } from './lib/layout';
import { CATEGORIES, MODULES, MODULE_DB as db } from './lib/modules';
import { CABLE_COLORS, emptyPatch, fromPatchFile, toPatchFile } from './lib/patch';
import {
  activePatch,
  activeRack,
  duplicateRack,
  loadState,
  newRack,
  removeModule,
  saveState,
  updatePatch,
  updateRack,
} from './lib/store';
import type { AppState, Endpoint, Patch, Rack } from './lib/types';
import { SUGGESTIONS } from './lib/suggestions';
import { uid } from './lib/uid';

type View = 'planer' | 'kabel' | 'vergleich';

export function App() {
  const [state, setState] = useState<AppState>(loadState);
  const [view, setView] = useState<View>('planer');
  const [zoom, setZoom] = useState(2.6);
  const [pending, setPending] = useState<Endpoint | null>(null);
  const [selectedCable, setSelectedCable] = useState<string | null>(null);
  const [selectedInstance, setSelectedInstance] = useState<string | null>(null);
  const [color, setColor] = useState(CABLE_COLORS[0]);
  const [toast, setToast] = useState<{ text: string; kind: 'info' | 'error' } | null>(null);

  useEffect(() => saveState(state), [state]);
  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(null), 4000);
    return () => clearTimeout(t);
  }, [toast]);

  const rack = activeRack(state);
  const patch = activePatch(rack);
  const info = (text: string) => setToast({ text, kind: 'info' });
  const error = (text: string) => setToast({ text, kind: 'error' });

  const setRack = (fn: (r: Rack) => Rack) => setState((s) => updateRack(s, rack.id, fn));
  const setPatch = (p: Patch) => setRack((r) => updatePatch(r, p.id, () => p));

  function resetSelection() {
    setPending(null);
    setSelectedCable(null);
    setSelectedInstance(null);
  }

  function addModule(id: string, row?: number, x?: number) {
    let spot: { row: number; x_hp: number } | null = null;
    if (row !== undefined && x !== undefined) {
      if (canPlace(rack, db, id, row, x).ok) spot = { row, x_hp: x };
      else {
        const nx = nearestSpotInRow(rack, db, id, row, x);
        spot = nx !== null ? { row, x_hp: nx } : null;
      }
    } else {
      spot = findFreeSpot(rack, db, id);
    }
    if (!spot) return error(`Kein Platz für ${db[id].name} (${db[id].hp} HP)`);
    const instance = nextInstanceId(rack.modules);
    setRack((r) => ({ ...r, modules: [...r.modules, { instance, module: id, ...spot! }] }));
    setSelectedInstance(instance);
  }

  function moveModule(instance: string, row: number, x: number) {
    const m = rack.modules.find((x) => x.instance === instance)!;
    const nx = canPlace(rack, db, m.module, row, x, instance).ok ? x : nearestSpotInRow(rack, db, m.module, row, x, instance);
    if (nx === null) return error(`Reihe ${row + 1} ist voll`);
    if (nx !== x) info(`Platz belegt – auf ${nx} HP verschoben`);
    x = nx;
    setRack((r) => ({ ...r, modules: r.modules.map((p) => (p.instance === instance ? { ...p, row, x_hp: x } : p)) }));
  }

  function jackClick(ep: Endpoint) {
    setSelectedCable(null);
    if (!pending) {
      setPending(ep);
      return;
    }
    if (pending.instance === ep.instance && pending.jack === ep.jack) {
      setPending(null);
      return;
    }
    const { from, to } = orient(rack, db, pending, ep);
    const check = validateCable(rack, db, patch, from, to);
    setPending(null);
    if (!check.ok) return error(check.error);
    setPatch({ ...patch, cables: [...patch.cables, { id: uid(), from, to, color }] });
    if (check.warnings.length) info(check.warnings.join(' · '));
  }

  function exportPatch() {
    const json = JSON.stringify(toPatchFile(rack, patch), null, 2);
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([json], { type: 'application/json' }));
    a.download = `${patch.name.replace(/[^\w\- ]+/g, '').trim() || 'patch'}.patch.json`;
    a.click();
    URL.revokeObjectURL(a.href);
  }

  async function importPatch(file: File) {
    let json: unknown;
    try {
      json = JSON.parse(await file.text());
    } catch {
      return error('Datei ist kein gültiges JSON');
    }
    const res = fromPatchFile(json, db, rack.case);
    if (!res.ok) return error(`Import fehlgeschlagen: ${res.errors.slice(0, 3).join('; ')}`);
    setState((s) => ({ racks: [...s.racks, res.rack], activeRack: res.rack.id }));
    resetSelection();
    info(res.warnings.length ? `Importiert als neues Rack. ${res.warnings.join(' · ')}` : 'Als neues Rack importiert');
  }

  return (
    <div className="app">
      <header className="topbar no-print">
        <h1>Hardware-Planer</h1>
        <div className="row-gap">
          <select
            value={rack.id}
            onChange={(e) => {
              setState((s) => ({ ...s, activeRack: e.target.value }));
              resetSelection();
            }}
          >
            {state.racks.map((r) => (
              <option key={r.id} value={r.id}>{r.name}</option>
            ))}
          </select>
          <button className="small" onClick={() => {
            const name = prompt('Name des Racks', rack.name);
            if (name) setRack((r) => ({ ...r, name }));
          }}>Umbenennen</button>
          <button className="small" onClick={() => {
            const r = newRack(`Rack ${state.racks.length + 1}`);
            setState((s) => ({ racks: [...s.racks, r], activeRack: r.id }));
            resetSelection();
          }}>Neu</button>
          <button className="small" onClick={() => {
            const r = duplicateRack(rack, `${rack.name} (Kopie)`);
            setState((s) => ({ racks: [...s.racks, r], activeRack: r.id }));
            resetSelection();
          }}>Duplizieren</button>
          <button className="small danger" disabled={state.racks.length < 2} onClick={() => {
            if (!confirm(`„${rack.name}“ löschen?`)) return;
            setState((s) => {
              const racks = s.racks.filter((r) => r.id !== rack.id);
              return { racks, activeRack: racks[0].id };
            });
            resetSelection();
          }}>Löschen</button>
          <select
            value=""
            onChange={(e) => {
              const sug = SUGGESTIONS.find((x) => x.id === e.target.value);
              if (!sug) return;
              const r = sug.load();
              setState((s) => ({ racks: [...s.racks, r], activeRack: r.id }));
              resetSelection();
            }}
          >
            <option value="">Vorschlag laden …</option>
            {SUGGESTIONS.map((x) => (
              <option key={x.id} value={x.id}>{x.name}</option>
            ))}
          </select>
        </div>
        <nav className="tabs">
          {(['planer', 'kabel', 'vergleich'] as View[]).map((v) => (
            <button key={v} className={view === v ? 'active' : ''} onClick={() => setView(v)}>
              {{ planer: 'Planer', kabel: 'Kabelliste', vergleich: 'Vergleich' }[v]}
            </button>
          ))}
        </nav>
      </header>

      {view === 'planer' && (
        <main className="layout">
          <Library modules={MODULES} categories={CATEGORIES} onAdd={(id) => addModule(id)} />
          <section className="panel-box case-box">
            <div className="row-gap case-toolbar">
              <strong>{rack.name}</strong>
              <span className="muted">· {patch.name}</span>
              <label className="zoom">
                Zoom
                <input type="range" min={1} max={5} step={0.1} value={zoom} onChange={(e) => setZoom(Number(e.target.value))} />
              </label>
              <button
                className="small"
                onClick={() => {
                  const w = document.querySelector('.case-scroll')?.clientWidth ?? 800;
                  setZoom(Math.max(1, Math.min(5, (w - 2) / (rack.case.hp * HP_MM + 8))));
                }}
              >
                Einpassen
              </button>
              {pending && (
                <span className="chip warn">
                  Kabel von {pending.instance}.{pending.jack} – Ziel-Jack anklicken
                  <button className="link" onClick={() => setPending(null)}>abbrechen</button>
                </span>
              )}
            </div>
            <CaseView
              rack={rack}
              db={db}
              patch={patch}
              zoom={zoom}
              pending={pending}
              selectedCable={selectedCable}
              selectedInstance={selectedInstance}
              onDropModule={addModule}
              onMove={moveModule}
              onJackClick={jackClick}
              onSelectCable={(id) => {
                setSelectedCable(id);
                setPending(null);
              }}
              onSelectModule={setSelectedInstance}
            />
            <p className="muted small-text">
              Module aus der Liste ins Case ziehen oder mit „+“ einfügen. Module per Ziehen verschieben, Klick wählt sie aus.
            </p>
          </section>
          <aside className="sidebar">
            <RackPanel rack={rack} db={db} onCaseChange={(c) => setRack((r) => ({ ...r, case: c }))} />
            <PatchPanel
              rack={rack}
              db={db}
              patch={patch}
              color={color}
              selectedCable={selectedCable}
              selectedInstance={selectedInstance}
              onColor={setColor}
              onPatchChange={setPatch}
              onSelectPatch={(id) => {
                setRack((r) => ({ ...r, activePatch: id }));
                resetSelection();
              }}
              onNewPatch={() => {
                const p = emptyPatch(`Patch ${rack.patches.length + 1}`);
                setRack((r) => ({ ...r, patches: [...r.patches, p], activePatch: p.id }));
                resetSelection();
              }}
              onDeletePatch={() => {
                if (!confirm(`Patch „${patch.name}“ löschen?`)) return;
                setRack((r) => {
                  const patches = r.patches.filter((p) => p.id !== patch.id);
                  return { ...r, patches, activePatch: patches[0].id };
                });
                resetSelection();
              }}
              onDeleteCable={(id) => {
                setPatch({ ...patch, cables: patch.cables.filter((c) => c.id !== id) });
                setSelectedCable(null);
              }}
              onRemoveModule={(inst) => {
                setRack((r) => removeModule(r, inst));
                resetSelection();
              }}
              onExport={exportPatch}
              onImport={importPatch}
            />
          </aside>
        </main>
      )}
      {view === 'kabel' && (
        <main className="single">
          <div className="row-gap no-print">
            Patch:
            <select value={patch.id} onChange={(e) => setRack((r) => ({ ...r, activePatch: e.target.value }))}>
              {rack.patches.map((p) => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </select>
          </div>
          <CableListView rack={rack} db={db} patch={patch} />
        </main>
      )}
      {view === 'vergleich' && (
        <main className="single">
          <CompareView racks={state.racks} db={db} />
        </main>
      )}

      {toast && <div className={`toast ${toast.kind}`} role="status">{toast.text}</div>}
    </div>
  );
}
