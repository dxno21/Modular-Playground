import { useRef, useState } from 'react';
import { HP_MM, ROW_MM, jackLayout, jackPosition, moduleOrigin, type Point } from '../lib/geometry';
import { canPlace } from '../lib/layout';
import { sameEndpoint } from '../lib/cables';
import type { Endpoint, ModuleDb, Patch, Rack } from '../lib/types';

interface Props {
  rack: Rack;
  db: ModuleDb;
  patch: Patch;
  zoom: number;
  pending: Endpoint | null;
  selectedCable: string | null;
  selectedInstance: string | null;
  onDropModule: (moduleId: string, row: number, x_hp: number) => void;
  onMove: (instance: string, row: number, x_hp: number) => void;
  onJackClick: (ep: Endpoint) => void;
  onSelectCable: (id: string | null) => void;
  onSelectModule: (instance: string | null) => void;
}

interface Drag {
  instance: string;
  grabHp: number;
  row: number;
  x_hp: number;
  moved: boolean;
}

const JACK_R = 3;
const EDGE_MM = 4;

function cablePath(a: Point, b: Point): string {
  const sag = Math.min(45, Math.hypot(a.x - b.x, a.y - b.y) * 0.35) + 8;
  return `M ${a.x} ${a.y} C ${a.x} ${a.y + sag}, ${b.x} ${b.y + sag}, ${b.x} ${b.y}`;
}

export function CaseView(p: Props) {
  const { rack, db, patch, zoom } = p;
  const svgRef = useRef<SVGSVGElement>(null);
  const [drag, setDrag] = useState<Drag | null>(null);
  const [mouse, setMouse] = useState<Point | null>(null);
  const [dropHint, setDropHint] = useState<{ row: number; x_hp: number; hp: number } | null>(null);

  const width = rack.case.hp * HP_MM;
  const height = rack.case.rows * ROW_MM;

  function toMm(clientX: number, clientY: number): Point {
    const svg = svgRef.current!;
    const pt = svg.createSVGPoint();
    pt.x = clientX;
    pt.y = clientY;
    const r = pt.matrixTransform(svg.getScreenCTM()!.inverse());
    return { x: r.x - EDGE_MM, y: r.y - EDGE_MM };
  }

  function slotAt(pt: Point, hp: number, grabHp: number) {
    const row = Math.min(rack.case.rows - 1, Math.max(0, Math.floor(pt.y / ROW_MM)));
    const x = Math.round(pt.x / HP_MM - grabHp);
    return { row, x_hp: Math.min(Math.max(0, x), rack.case.hp - hp) };
  }

  const connected = new Set(patch.cables.flatMap((c) => [`${c.from.instance}.${c.from.jack}`, `${c.to.instance}.${c.to.jack}`]));
  const pendingPos = p.pending ? jackPosition(rack, db, p.pending.instance, p.pending.jack) : null;
  const dragValid = drag ? canPlace(rack, db, rack.modules.find((m) => m.instance === drag.instance)!.module, drag.row, drag.x_hp, drag.instance).ok : true;

  return (
    <div className="case-scroll">
      <svg
        ref={svgRef}
        className="case-svg"
        width={(width + EDGE_MM * 2) * zoom}
        height={(height + EDGE_MM * 2) * zoom}
        viewBox={`0 0 ${width + EDGE_MM * 2} ${height + EDGE_MM * 2}`}
        onPointerMove={(e) => {
          const pt = toMm(e.clientX, e.clientY);
          if (p.pending) setMouse(pt);
          if (drag) {
            const placed = rack.modules.find((m) => m.instance === drag.instance)!;
            const slot = slotAt(pt, db[placed.module].hp, drag.grabHp);
            if (slot.row !== drag.row || slot.x_hp !== drag.x_hp) setDrag({ ...drag, ...slot, moved: true });
          }
        }}
        onPointerUp={() => {
          if (!drag) return;
          if (drag.moved) p.onMove(drag.instance, drag.row, drag.x_hp);
          else p.onSelectModule(drag.instance);
          setDrag(null);
        }}
        onPointerLeave={() => setMouse(null)}
        onDragOver={(e) => {
          e.preventDefault();
          const id = e.dataTransfer.types.includes('text/module-id') ? draggingModule : null;
          const def = id ? db[id] : null;
          if (def) setDropHint({ ...slotAt(toMm(e.clientX, e.clientY), def.hp, def.hp / 2), hp: def.hp });
        }}
        onDragLeave={() => setDropHint(null)}
        onDrop={(e) => {
          e.preventDefault();
          setDropHint(null);
          const id = e.dataTransfer.getData('text/module-id');
          const def = db[id];
          if (!def) return;
          const slot = slotAt(toMm(e.clientX, e.clientY), def.hp, def.hp / 2);
          p.onDropModule(id, slot.row, slot.x_hp);
        }}
        onClick={(e) => {
          if (e.target === e.currentTarget || (e.target as Element).classList.contains('rail-bg')) {
            p.onSelectCable(null);
            p.onSelectModule(null);
          }
        }}
      >
        <rect x={0} y={0} width={width + EDGE_MM * 2} height={height + EDGE_MM * 2} rx={3} className="case-frame" />
        <g transform={`translate(${EDGE_MM} ${EDGE_MM})`}>
          {[...Array(rack.case.rows).keys()].map((r) => (
            <g key={r}>
              <rect className="rail-bg" x={0} y={r * ROW_MM} width={width} height={ROW_MM} />
              {[...Array(Math.floor(rack.case.hp / 2) + 1).keys()].map((i) => (
                <line key={i} className="hp-tick" x1={i * 2 * HP_MM} x2={i * 2 * HP_MM} y1={r * ROW_MM} y2={r * ROW_MM + 3} />
              ))}
            </g>
          ))}

          {dropHint && (
            <rect
              className={canPlace(rack, db, draggingModule ?? '', dropHint.row, dropHint.x_hp).ok ? 'ghost ok' : 'ghost bad'}
              x={dropHint.x_hp * HP_MM}
              y={dropHint.row * ROW_MM}
              width={dropHint.hp * HP_MM}
              height={ROW_MM}
            />
          )}

          {rack.modules.map((m) => {
            const def = db[m.module];
            if (!def) return null;
            const isDrag = drag?.instance === m.instance;
            const o = moduleOrigin(isDrag ? drag! : m);
            const w = def.hp * HP_MM;
            const jacks = jackLayout(def);
            return (
              <g
                key={m.instance}
                transform={`translate(${o.x} ${o.y})`}
                className={`module${p.selectedInstance === m.instance ? ' selected' : ''}${isDrag ? (dragValid ? ' dragging' : ' dragging bad') : ''}`}
              >
                <rect
                  className="panel"
                  x={0.3}
                  y={0.5}
                  width={w - 0.6}
                  height={ROW_MM - 1}
                  rx={1}
                  onPointerDown={(e) => {
                    e.stopPropagation();
                    (e.currentTarget.ownerSVGElement as SVGSVGElement).setPointerCapture(e.pointerId);
                    const pt = toMm(e.clientX, e.clientY);
                    setDrag({ instance: m.instance, grabHp: pt.x / HP_MM - m.x_hp, row: m.row, x_hp: m.x_hp, moved: false });
                  }}
                />
                <text className="mod-maker" x={w / 2} y={6}>{def.manufacturer}</text>
                <text className="mod-name" x={w / 2} y={12}>{def.name}</text>
                <text className="mod-hp" x={w / 2} y={ROW_MM - 3}>{def.hp} HP</text>
                {def.jacks.map((j) => {
                  const pos = jacks[j.id];
                  const ep = { instance: m.instance, jack: j.id };
                  const isPending = p.pending && sameEndpoint(p.pending, ep);
                  const used = connected.has(`${m.instance}.${j.id}`);
                  return (
                    <g
                      key={j.id}
                      className={`jack ${j.dir} t-${j.type}${isPending ? ' pending' : ''}${used ? ' used' : ''}`}
                      transform={`translate(${pos.x} ${pos.y})`}
                    >
                      {j.dir === 'out' && <rect className="out-bg" x={-4.4} y={-4.4} width={8.8} height={11.6} rx={1} />}
                      <circle r={JACK_R} />
                      <circle className="hole" r={1.4} />
                      <text y={6}>{j.label}</text>
                    </g>
                  );
                })}
              </g>
            );
          })}

          <g className="cables">
            {patch.cables.map((c) => {
              const a = jackPosition(rack, db, c.from.instance, c.from.jack);
              const b = jackPosition(rack, db, c.to.instance, c.to.jack);
              if (!a || !b) return null;
              const d = cablePath(a, b);
              const sel = p.selectedCable === c.id;
              return (
                <g key={c.id} className={`cable${sel ? ' selected' : ''}`} onClick={() => p.onSelectCable(sel ? null : c.id)}>
                  <path className="cable-hit" d={d} />
                  <path className="cable-line" d={d} stroke={c.color} />
                  <circle cx={a.x} cy={a.y} r={1.8} fill={c.color} />
                  <circle cx={b.x} cy={b.y} r={1.8} fill={c.color} />
                </g>
              );
            })}
            {pendingPos && mouse && <path className="cable-pending" d={cablePath(pendingPos, mouse)} />}
          </g>

          {/* Klickflächen über den Kabeln, damit belegte Jacks erreichbar bleiben (z.B. für Mults) */}
          <g className="jack-hits">
            {rack.modules.map((m) => {
              const def = db[m.module];
              if (!def || drag?.instance === m.instance) return null;
              const o = moduleOrigin(m);
              const jacks = jackLayout(def);
              return def.jacks.map((j) => (
                <circle
                  key={`${m.instance}.${j.id}`}
                  className="jack-hit"
                  cx={o.x + jacks[j.id].x}
                  cy={o.y + jacks[j.id].y}
                  r={JACK_R + 0.4}
                  onPointerDown={(e) => e.stopPropagation()}
                  onClick={(e) => {
                    e.stopPropagation();
                    p.onJackClick({ instance: m.instance, jack: j.id });
                  }}
                >
                  <title>{`${def.name} ${j.label} (${j.dir === 'in' ? 'Eingang' : 'Ausgang'}, ${j.type})`}</title>
                </circle>
              ));
            })}
          </g>
        </g>
      </svg>
    </div>
  );
}

/** HTML5-Drag liefert die Daten erst beim Drop; für die Vorschau merken wir uns die ID hier. */
let draggingModule: string | null = null;
export function setDraggingModule(id: string | null) {
  draggingModule = id;
}
