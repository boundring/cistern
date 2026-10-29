import type { Donors } from "../types/donors.js";
import type { Selection } from "../types/game.js";

/** Local structural view of the selection; terrain/figure are optional until wired. */
interface TerrainInfo {
  kind: string;
  steps: number;
  height: number;
  water: boolean;
}
interface FigureInfo {
  id: number;
  kind: string;
}
interface SelView {
  x: number;
  y: number;
  tile: string;
  copyKey: string;
  text: string;
  terrain?: TerrainInfo;
  figure?: FigureInfo;
}

/** Fills the inspector panel (slot elements live in index.html). */
export class Inspector {
  private readonly tile: HTMLElement | null;
  private readonly key: HTMLElement | null;
  private readonly text: HTMLElement | null;
  private readonly img: HTMLImageElement | null;
  private readonly terrain: HTMLElement | null;
  private readonly figure: HTMLElement | null;

  constructor(
    private readonly panel: HTMLElement,
    private readonly donors: Donors,
  ) {
    this.tile = panel.querySelector<HTMLElement>('[data-slot="tile"]');
    this.key = panel.querySelector<HTMLElement>('[data-slot="key"]');
    this.text = panel.querySelector<HTMLElement>('[data-slot="text"]');
    this.img = panel.querySelector<HTMLImageElement>('[data-slot="sprite"]');
    this.terrain = panel.querySelector<HTMLElement>('[data-slot="terrain"]');
    this.figure = panel.querySelector<HTMLElement>('[data-slot="figure"]');
  }

  /** Show the selection, or hide the panel when null. */
  show(sel: Selection | null): void {
    if (!sel) {
      this.panel.hidden = true;
      return;
    }
    const s = sel as SelView;
    if (this.tile) this.tile.textContent = s.tile;
    if (this.key) this.key.textContent = s.copyKey;
    if (this.text) this.text.textContent = s.text;
    if (this.terrain) this.terrain.textContent = s.terrain ? terrainLine(s.terrain) : "";
    if (this.figure) this.figure.textContent = s.figure ? `${s.figure.kind} #${s.figure.id}` : "";
    if (this.img) {
      const png = this.donors.tilePng[sel.tile];
      if (png) {
        this.img.src = png;
        this.img.hidden = false;
      } else {
        this.img.hidden = true;
      }
    }
    this.panel.hidden = false;
  }
}

/** `hills — 7 steps (0.875 u)` or, under water, `water — 3 steps below the table`. */
function terrainLine(t: TerrainInfo): string {
  if (t.water) return `water — ${t.steps} steps below the table`;
  return `${t.kind} — ${t.steps} steps (${t.height} u)`;
}
