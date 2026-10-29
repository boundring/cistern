import type { Donors } from "../types/donors.js";
import type { Selection } from "../types/game.js";

/** Fills the inspector panel (slot elements live in index.html). */
export class Inspector {
  private readonly tile: HTMLElement | null;
  private readonly key: HTMLElement | null;
  private readonly text: HTMLElement | null;
  private readonly img: HTMLImageElement | null;

  constructor(
    private readonly panel: HTMLElement,
    private readonly donors: Donors,
  ) {
    this.tile = panel.querySelector<HTMLElement>('[data-slot="tile"]');
    this.key = panel.querySelector<HTMLElement>('[data-slot="key"]');
    this.text = panel.querySelector<HTMLElement>('[data-slot="text"]');
    this.img = panel.querySelector<HTMLImageElement>('[data-slot="sprite"]');
  }

  /** Show the selection, or hide the panel when null. */
  show(sel: Selection | null): void {
    if (!sel) {
      this.panel.hidden = true;
      return;
    }
    if (this.tile) this.tile.textContent = sel.tile;
    if (this.key) this.key.textContent = sel.copyKey;
    if (this.text) this.text.textContent = sel.text;
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
