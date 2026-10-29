/**
 * SKELETON -- no implementation. Target path: src/main.ts
 * Owning slice: integration (orchestrator)
 *
 * Responsibility: own the page entry point -- read the canvas and the panel
 * from the DOM, dress the town from the baked donors, install the Game and
 * publish it as `window.game` before the first frame, push the theme palette
 * into the CSS custom properties, drive the resize handler, run the
 * requestAnimationFrame loop and the ambient tick interval. It must NOT own
 * any game logic: it wires the pieces the other modules provide.
 *
 * Signatures are taken from src/main.ts (the orchestrator owns the
 * integration files; CONTRACT.md does not freeze this module's shape).
 *
 * The real module exports nothing -- it is a side-effect entry point. Its
 * top-level steps, in order:
 *   1. read the canvas (#gl) and the panel (#panel) from the DOM;
 *   2. dress the town from the baked DONORS;
 *   3. push the theme palette into the CSS custom properties;
 *   4. construct the Game and assign window.game BEFORE the first frame;
 *   5. fit the canvas to the window and listen for resize;
 *   6. run the requestAnimationFrame loop;
 *   7. tick the ambient sim every 400 ms.
 * There is therefore no exported symbol to declare here.
 */
