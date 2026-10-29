import { DONORS } from "./generated/donors.js";
import { dressedTown } from "./core/town.js";
import { Game } from "./game.js";

const canvas = document.getElementById("gl");
const panel = document.getElementById("panel");
if (!canvas || !panel) throw new Error("index.html is missing #gl or #panel");

const town = dressedTown(DONORS);

// Theme palette -> panel CSS custom properties (index.html holds fallbacks).
const rootStyle = document.documentElement.style;
const paletteVars: [string, string][] = [
  ["bg", "--bg"],
  ["panel", "--panel"],
  ["panel_edge", "--panel-edge"],
  ["accent", "--accent"],
  ["text", "--text"],
];
for (const [key, prop] of paletteVars) {
  const rgb = DONORS.theme.palette[key];
  if (rgb) rootStyle.setProperty(prop, `rgb(${rgb[0]} ${rgb[1]} ${rgb[2]})`);
}

const game = new Game(town, canvas as HTMLCanvasElement, panel);
window.game = game; // before the first frame: the harness polls for this

const fit = (): void => {
  game.resize(window.innerWidth, window.innerHeight);
};
fit();
window.addEventListener("resize", fit);

const frame = (): void => {
  game.frame();
  window.requestAnimationFrame(frame);
};
window.requestAnimationFrame(frame);
