/**
 * Wire tile id -> existing copy.ron key. The donor copy table has no
 * per-tile rows, so the web side resolves each of the 14 tile ids to an
 * existing key (no new strings); unknown tiles fail closed to the
 * generic interact hint.
 */

export const TILE_COPY_KEY: Record<string, string> = {
  floor: "item_none_here",
  wall: "move_blocked_wall",
  gate: "move_blocked_occupied",
  rubble: "dig/cracked-wall",
  soil: "dig/failed",
  grass: "vista/surface",
  stream_water: "ecology/drank",
  conduit: "cyber/terminal_wall_jack",
  settlement: "shrine/white-cistern",
  gantry: "shop/bought",
  nest_mark: "ecology/starved",
  drain_grate: "tell/geyser_vent",
  elevator_up: "elevator_top",
  elevator_down: "tutorial/descend",
};

export function copyForTile(tile: string, copy: Record<string, string>): { key: string; text: string } {
  const key = TILE_COPY_KEY[tile];
  if (key !== undefined && copy[key] !== undefined) return { key, text: copy[key]! };
  return { key: "hint/interact", text: copy["hint/interact"] ?? "" };
}
