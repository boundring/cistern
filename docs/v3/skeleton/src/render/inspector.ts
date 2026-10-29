/**
 * SKELETON -- no implementation. Target path: src/render/inspector.ts
 * Owning slice: E -- render-inspector
 *
 * Responsibility: own the inspector panel -- filling the tile, key and text
 * slots, the sprite image, and the two v3 rows `[data-slot="terrain"]` and
 * `[data-slot="figure"]` -- from a Selection, and hiding the panel when
 * there is no selection. It must NOT own the selection itself, the copy
 * table, the scene, the camera or the game layer; it reads the optional
 * terrain and figure fields defensively because they may be absent.
 *
 * Signatures are verbatim from CONTRACT.md ("Frozen: slice E") and
 * src/render/inspector.ts.
 */

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

/** Fills the inspector panel (slot elements live in index.html). */
export class Inspector {
  constructor(panel: HTMLElement, donors: Donors) {
    throw new Error("not implemented: Inspector");
  }
  /** Show the selection, or hide the panel when null. */
  show(sel: Selection | null): void {
    throw new Error("not implemented: Inspector.show");
  }
}
