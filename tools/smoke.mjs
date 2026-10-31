// Headless-Chromium smoke: the CI-equivalent (charter acceptance 2-6).
//
//   npm run smoke   ==  npm run build && node tools/smoke.mjs
//
// 1. Node-side: structural checks + golden-vector cross-checks on the BAKED
//    donors (out/generated/donors.js against tests/golden/*.txt).
// 2. Browser-side over CDP on its own isolated headless Chromium
//    (--remote-debugging-port=0, throwaway profile): loads the served page,
//    asserts the window.game test surface, captures screenshots at 1280x800
//    and 375x667, and asserts every network request is same-origin (no
//    runtime fetch beyond the vendored three.js).
//
// Node >= 22 (built-in fetch/WebSocket). No dependencies.
import { readFileSync, writeFileSync, existsSync, mkdtempSync, rmSync } from "node:fs";
import { spawn, spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const PAGE_PATH = "/index.html"; // served from the repo root
const SHOTS = [
  { width: 1280, height: 800, mobile: false },
  { width: 375, height: 667, mobile: true },
];

let server;
let chromium;
let browser;
let profileDir;
function fail(msg) {
  server?.kill();
  chromium?.kill("SIGKILL");
  if (profileDir) rmSync(profileDir, { recursive: true, force: true });
  console.error(`smoke: FAIL: ${msg}`);
  process.exit(1);
}

const goldenLine = (file, prefix) => {
  const line = readFileSync(join(ROOT, "tests/golden", file), "utf8")
    .split("\n")
    .find((l) => l.startsWith(prefix));
  if (!line) fail(`tests/golden/${file}: no ${prefix} line`);
  return JSON.parse(line.slice(prefix.length));
};

// ------------------------------------------------------------- node-side
if (!existsSync(join(ROOT, "out/generated/donors.js"))) {
  fail("out/generated/donors.js missing -- run `npm run build` first (npm run smoke does)");
}
const { DONORS } = await import(pathToFileURL(join(ROOT, "out/generated/donors.js")).href);

const goldenTown = goldenLine("town.txt", "VECT_TOWN ");
const goldenRng = goldenLine("rng.txt", "VECT_RNG ");

// Slab + mapping integrity.
for (const [id, row] of [...Object.entries(DONORS.tiles), ...Object.entries(DONORS.props)]) {
  if (!DONORS.slabs[row.slab]) fail(`tile "${id}": slab "${row.slab}" missing from DONORS.slabs`);
  const s = DONORS.slabs[row.slab];
  const bytes = Buffer.from(s.volumeB64, "base64").length;
  if (bytes !== s.side * (s.side + s.depth) * s.side) fail(`slab "${row.slab}": volumeB64 is ${bytes} bytes, expected ${s.side * (s.side + s.depth) * s.side}`);
}
if (Object.keys(DONORS.copy).length === 0) fail("DONORS.copy is empty");
for (const [key, uri] of Object.entries(DONORS.tilePng)) {
  if (!uri.startsWith("data:image/png;base64,")) fail(`tilePng "${key}": not a PNG data URI`);
}
for (const row of DONORS.townRows) {
  for (const ch of row) {
    if (!(ch in DONORS.glyphTiles)) fail(`town row glyph ${JSON.stringify(ch)} missing from glyphTiles`);
  }
}

// Baked template vs golden (the golden is the DRESSED town: its extra cells
// must all be FLAVOR grass on plain floor; anything else is donor drift).
const mapped = DONORS.townRows.map((r) => [...r].map((ch) => DONORS.glyphTiles[ch]));
const goldenGrid = goldenTown.rows.map((r) => r.split("|").filter((s) => s !== ""));
let drift = [];
for (let y = 0; y < 16; y++) {
  for (let x = 0; x < 34; x++) {
    if (mapped[y][x] !== goldenGrid[y][x]) drift.push([x, y, mapped[y][x], goldenGrid[y][x]]);
  }
}
if (!drift.every(([, , from, to]) => from === "floor" && to === "grass")) {
  fail(`baked town template drifted from tests/golden/town.txt beyond FLAVOR grass: ${JSON.stringify(drift.slice(0, 8))}`);
}
if (!Object.keys(goldenRng).includes(String(DONORS.constants.scatterSeed))) {
  fail(`constants.scatterSeed ${DONORS.constants.scatterSeed} missing from tests/golden/rng.txt seeds`);
}
console.log(`smoke: donors OK (${Object.keys(DONORS.slabs).length} slabs, template matches golden up to ${drift.length} FLAVOR grass cells)`);

// ------------------------------------------------------------- serve repo
server = spawn("python3", ["-m", "http.server", "0", "--bind", "127.0.0.1"], { cwd: ROOT, stdio: ["ignore", "pipe", "pipe"] });
const baseOrigin = await new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error("http.server did not report a port in 10s")), 10000);
  const onLine = (buf) => {
    const m = buf.toString().match(/127\.0\.0\.1:(\d+)/);
    if (m) {
      clearTimeout(timer);
      resolve(`http://127.0.0.1:${m[1]}`);
    }
  };
  server.stdout.on("data", onLine);
  server.stderr.on("data", onLine);
  server.on("exit", (code) => reject(new Error(`http.server exited early (${code})`)));
});

// ------------------------------------------------------------------- CDP
function cdp(wsUrl) {
  const ws = new WebSocket(wsUrl);
  let nextId = 1;
  const pending = new Map();
  const listeners = new Map(); // method -> [resolve,...]
  const subscribers = new Map(); // method -> [fn,...] (non-consuming)
  ws.addEventListener("message", (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) reject(new Error(`${msg.error.message} (${msg.error.data ?? ""})`));
      else resolve(msg.result ?? {});
    } else if (msg.method) {
      for (const fn of subscribers.get(msg.method) ?? []) fn(msg.params);
      const queue = listeners.get(msg.method);
      if (queue?.length) queue.shift()(msg);
    }
  });
  const openP = new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve);
    ws.addEventListener("error", () => reject(new Error("devtools websocket failed to open")));
  });
  const send = (msg) => {
    const id = nextId++;
    const p = new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
    ws.send(JSON.stringify({ ...msg, id }));
    return p;
  };
  return {
    ws,
    open: openP,
    cmd: (method, params = {}, sessionId) => send(sessionId ? { sessionId, method, params } : { method, params }),
    // Observe every event of a method without consuming it.
    on: (method, fn) => {
      const subs = subscribers.get(method) ?? [];
      subs.push(fn);
      subscribers.set(method, subs);
    },
    // Await the next event of a method; null on timeout.
    waitEvent: (method, timeoutMs = 15000) => {
      let settle;
      const p = new Promise((resolve) => {
        settle = resolve;
        const queue = listeners.get(method) ?? [];
        queue.push(resolve);
        listeners.set(method, queue);
      });
      const timer = setTimeout(() => {
        const queue = listeners.get(method) ?? [];
        const i = queue.indexOf(settle);
        if (i >= 0) queue.splice(i, 1);
        settle(null);
      }, timeoutMs);
      return p.then((msg) => {
        clearTimeout(timer);
        return msg ? msg.params : null;
      });
    },
    close: () => ws.close(),
  };
}

try {
  // Launch an isolated headless Chromium (never the user's browser).
  const bin = ["chromium", "google-chrome-stable", "google-chrome", "chromium-browser"].find((b) => {
    try {
      return spawnSync("which", [b], { encoding: "utf8" }).status === 0;
    } catch {
      return false;
    }
  });
  if (!bin) fail("no Chromium-family browser found on PATH (chromium / google-chrome-stable)");
  profileDir = mkdtempSync(join(ROOT, "out", "smoke-profile-"));
  chromium = spawn(bin, ["--headless", `--remote-debugging-port=0`, `--user-data-dir=${profileDir}`, "--no-first-run", "--no-default-browser-check", "--hide-scrollbars", "about:blank"], {
    stdio: ["ignore", "ignore", "pipe"],
  });
  const cdpPort = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("chromium never reported a DevTools port in 15s")), 15000);
    chromium.stderr.on("data", (buf) => {
      const m = buf.toString().match(/DevTools listening on ws:\/\/127\.0\.0\.1:(\d+)\//);
      if (m) {
        clearTimeout(timer);
        resolve(Number(m[1]));
      }
    });
    chromium.on("exit", (code) => reject(new Error(`chromium exited early (${code})`)));
  });
  const version = await fetch(`http://127.0.0.1:${cdpPort}/json/version`).then((r) => r.json());
  browser = cdp(version.webSocketDebuggerUrl);
  await browser.open;

  const { targetId } = await browser.cmd("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await browser.cmd("Target.attachToTarget", { targetId, flatten: true });
  const cmd = (method, params) => browser.cmd(method, params, sessionId);

  await cmd("Page.enable");
  await cmd("Network.enable");
  await cmd("Runtime.enable");

  // Acceptance 5, enforcement half: hard-fail every non-local request at the
  // network stack so "no runtime fetch" is enforced, not just observed.
  const blocked = [];
  browser.on("Fetch.requestPaused", (p) => {
    if (p.request.url.startsWith(baseOrigin + "/")) {
      cmd("Fetch.continueRequest", { requestId: p.requestId }).catch(() => {});
    } else {
      blocked.push(p.request.url);
      cmd("Fetch.failRequest", { requestId: p.requestId, errorReason: "BlockedByClient" }).catch(() => {});
    }
  });
  await cmd("Fetch.enable", { patterns: [{ urlPattern: "*", requestStage: "Request" }] });

  // Every request the page makes must be same-origin (acceptance 5).
  const requests = [];
  browser.on("Network.requestWillBeSent", (p) => requests.push(p.request.url));

  const page = await fetch(baseOrigin + PAGE_PATH);
  if (!page.ok) fail(`${PAGE_PATH} not served from the repo root (HTTP ${page.status}) -- smoke expects index.html at the root`);
  await cmd("Page.navigate", { url: baseOrigin + PAGE_PATH });
  const loaded = await browser.waitEvent("Page.loadEventFired");
  if (!loaded) fail(`page never fired loadEventFired (${baseOrigin}${PAGE_PATH})`);

  // Wait for the test surface (three.js scene boot takes a moment).
  let booted = false;
  for (let waited = 0; waited < 15000; waited += 250) {
    const res = await cmd("Runtime.evaluate", { expression: "!!window.game", returnByValue: true });
    if (res.result?.value === true) {
      booted = true;
      break;
    }
    await new Promise((r) => setTimeout(r, 250));
  }
  if (!booted) fail("window.game never appeared within 15s -- did main.ts install the test surface?");

  const evaluate = async (expression) => {
    const res = await cmd("Runtime.evaluate", { expression, returnByValue: true });
    if (res.exceptionDetails) {
      fail(`page assertion threw: ${expression}\n  ${res.exceptionDetails.exception?.description ?? res.exceptionDetails.text}`);
    }
    return res.result?.value;
  };

  // Wait for n rendered frames. Headless Chromium can stop compositing, so
  // the rAF wait races a timeout instead of hanging the smoke.
  const waitFrames = async (n) => {
    const res = await cmd("Runtime.evaluate", {
      expression: `new Promise((resolve) => {
        let left = ${n};
        const timer = setTimeout(() => resolve(false), 3000);
        const step = () => {
          if (--left <= 0) { clearTimeout(timer); resolve(true); return; }
          requestAnimationFrame(step);
        };
        requestAnimationFrame(step);
      })`,
      awaitPromise: true,
      returnByValue: true,
    });
    if (res.exceptionDetails) {
      // No frame arrived (compositing stopped): proceed, the probes below
      // assert on pixels and will fail loudly if the frame is stale.
      return;
    }
  };

  // --- state assertions (charter: assert on state, never pixels)
  const state = JSON.parse(await evaluate("JSON.stringify(window.game.state())"));
  if (state.seed !== DONORS.constants.townSeed) fail(`state.seed ${state.seed} != baked townSeed ${DONORS.constants.townSeed}`);
  if (state.width !== 34 || state.height !== 16) fail(`state dims ${state.width}x${state.height} != 34x16`);
  if (state.tiles?.length !== 34 * 16) fail(`state.tiles length ${state.tiles?.length} != 544`);
  const flat = state.tiles;
  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 34; x++) {
      if (flat[y * 34 + x] !== goldenGrid[y][x]) fail(`state tile at ${x},${y} is "${flat[y * 34 + x]}", golden says "${goldenGrid[y][x]}"`);
    }
  }
  if (state.counts.floor + state.counts.structure !== 34 * 16) {
    fail(`counts floor(${state.counts.floor}) + structure(${state.counts.structure}) != 544`);
  }
  // --- v3: the open-world law must be wired into the state
  const wb = state.world;
  if (!wb) fail("state.world missing -- v3 open world not wired into GameState");
  const wantWorld = {
    playableW: 68, playableH: 32, footprintW: 136, footprintH: 64,
    villageX: 34, villageY: 16, townX: 17, townY: 8, townW: 34, townH: 16,
  };
  for (const [k, v] of Object.entries(wantWorld)) {
    if (wb[k] !== v) fail(`state.world.${k} = ${wb[k]}, expected ${v}`);
  }
  console.log(`smoke: state OK (seed ${state.seed}, 34x16 tiles match golden, counts floor=${state.counts.floor} structure=${state.counts.structure} props=${state.counts.props})`);

  // --- dispatch: inspect one defined cell end-to-end
  const [sx, sy] = goldenTown.spawn;
  const inspect = JSON.parse(await evaluate(`JSON.stringify(window.game.dispatch({type:"inspect",x:${sx},y:${sy}}))`));
  if (!inspect.ok) fail(`dispatch(inspect ${sx},${sy}) failed: ${inspect.error}`);
  const sel = inspect.state.selection;
  if (!sel) fail("dispatch(inspect) returned ok with no selection");
  if (sel.tile !== goldenGrid[sy][sx]) fail(`selection.tile "${sel.tile}" != golden "${goldenGrid[sy][sx]}"`);
  if (!sel.text) fail("selection.text is empty -- copy table not resolved");
  if (DONORS.copy[sel.copyKey] !== sel.text) fail(`selection.text does not match DONORS.copy["${sel.copyKey}"]`);
  const stateSel = JSON.parse(await evaluate("JSON.stringify(window.game.state().selection)"));
  if (stateSel?.text !== sel.text) fail("state().selection.text differs from dispatch(inspect) result (charter: same text)");

  // --- dispatch: the other defined intents succeed
  for (const intent of [{ type: "orbit", yaw: 0.7 }, { type: "zoom", distance: 24 }, { type: "reset" }]) {
    const res = JSON.parse(await evaluate(`JSON.stringify(window.game.dispatch(${JSON.stringify(intent)}))`));
    if (!res.ok) fail(`dispatch(${JSON.stringify(intent)}) failed: ${res.error}`);
  }
  console.log(`smoke: dispatch OK (inspect ${sx},${sy} -> "${sel.copyKey}"; orbit/zoom/reset ok)`);

  // --- townsfolk (v2): the rendered billboards must match the donor event
  // stream (placement count pinned by tests/golden/townsfolk.txt), ticks
  // must advance the sim transcript, and nobody despawns.
  const goldenTf = goldenLine("townsfolk.txt", "VECT_TOWNSFOLK ");
  const spawnCount = goldenTf.place.filter((p) => p.kind === "townsfolk").length;
  const tfState = JSON.parse(await evaluate("JSON.stringify(window.game.state())"));
  if (tfState.counts.townsfolk !== spawnCount) {
    fail(`rendered townsfolk ${tfState.counts.townsfolk} != ${spawnCount} spawns in the donor stream`);
  }
  if (tfState.townsfolk.length !== spawnCount) {
    fail(`state townsfolk ${tfState.townsfolk.length} != ${spawnCount} (donor: never despawn)`);
  }
  // --- v3: the world population (villagers) + scatter figures on top of the sim
  const c3 = tfState.counts;
  if (!(c3.figures >= c3.townsfolk + 1)) fail(`counts.figures ${c3.figures} < townsfolk ${c3.townsfolk} + player`);
  if (!(c3.figures > c3.townsfolk)) fail(`counts.figures ${c3.figures} not > townsfolk ${c3.townsfolk} (world villagers missing)`);
  if (!(c3.trees > 0)) fail("counts.trees is 0 -- no scatter trees");
  if (!(c3.rocks > 0)) fail("counts.rocks is 0 -- no scatter rocks");
  if (!(c3.items > 0)) fail("counts.items is 0 -- no scatter items");
  const evBefore = tfState.eventCount;
  const tick = JSON.parse(await evaluate(`JSON.stringify(window.game.dispatch({type:"tick",n:5}))`));
  if (!tick.ok) fail(`dispatch(tick n=5) failed: ${tick.error}`);
  if (tick.state.eventCount <= evBefore) fail("dispatch(tick) did not advance the sim event stream");
  if (tick.state.counts.townsfolk !== spawnCount) fail("townsfolk count changed over ticks (donor law: never despawn)");
  console.log(`smoke: townsfolk OK (${spawnCount} billboards == donor spawn count; ticks advanced events ${evBefore} -> ${tick.state.eventCount})`);

  // Open-ground townsfolk (nearest the town centre) for the probe + close-up:
  // a figure against a wall clips the close camera into geometry.
  const centreTf = tfState.townsfolk.reduce((a, b) =>
    (b.x - 17) ** 2 + (b.y - 8) ** 2 < (a.x - 17) ** 2 + (a.y - 8) ** 2 ? b : a);

  // --- v3 acceptance: an NPC region must not read as a flat quad. Frame the
  // A flat billboard over ground yields 2-3 distinct colours and low luminance
  // variance; a shaded 3D voxel figure yields 6+ distinct and high variance.
  for (const intent of [{ type: "orbit", pitch: 0.35 }, { type: "zoom", distance: 6 }]) {
    const res = JSON.parse(await evaluate(`JSON.stringify(window.game.dispatch(${JSON.stringify(intent)}))`));
    if (!res.ok) fail(`dispatch(${JSON.stringify(intent)}) failed: ${res.error}`);
  }
  await evaluate(`window.game.focus(${centreTf.x}, ${centreTf.y})`);
  // let a frame render at the new framing (never hang: headless Chromium can
  // stop compositing, and a bare rAF promise would never settle)
  await waitFrames(2);
  const probe = await evaluate(`(() => {
    const id = ${centreTf.id};
    const pos = window.game.entityScreenPos(id);
    if (!pos) return { id, pos: null };
    // Tight 32x48 box, feet-anchored: the figure is ~0.84 world units tall,
    // ~60-100 px at orbit distance 6.
    const W = window.innerWidth, H = window.innerHeight;
    const bx = pos.x - 16, by = pos.y - 44;
    const gx = bx + 32 + 24 <= W ? bx + 56 : bx - 56; // same-size ground-only box beside it
    if (bx < 0 || by < 0 || bx + 32 > W || by + 48 > H || gx < 0 || gx + 32 > W || by + 48 > H) {
      return { id, pos, W, H, onScreen: false };
    }
    return { id, pos, W, H, onScreen: true, fig: window.game.probePixels(bx, by, 32, 48), ground: window.game.probePixels(gx, by, 32, 48) };
  })()`);
  if (!probe || !probe.pos) fail("no on-screen townsfolk to probe (entityScreenPos returned nothing)");
  if (!probe.onScreen) fail(`probe box for townsfolk ${probe.id} not fully on-screen at ${probe.W}x${probe.H} (screen pos ${probe.pos.x.toFixed(0)},${probe.pos.y.toFixed(0)})`);
  console.log(`smoke: probe townsfolk ${probe.id} at (${probe.pos.x.toFixed(0)},${probe.pos.y.toFixed(0)}): figure samples=${probe.fig.samples} distinct=${probe.fig.distinct} variance=${probe.fig.variance.toFixed(0)} mean=${probe.fig.mean.toFixed(0)} | ground baseline distinct=${probe.ground.distinct} variance=${probe.ground.variance.toFixed(0)} mean=${probe.ground.mean.toFixed(0)}`);
  if (!(probe.fig.samples > 0)) fail("probePixels returned no samples for the figure region");
  if (!(probe.fig.distinct >= 5)) fail(`figure region distinct=${probe.fig.distinct} < 5 -- reads as a flat quad, not a 3D voxel figure`);
  // Calibrated: figure region variance ~1542 vs a same-size ground-only
  // baseline of ~168 (textured terrain) -- 500 is ~3x baseline, ~1/3 figure.
  if (!(probe.fig.variance >= 500)) fail(`figure region variance=${probe.fig.variance.toFixed(0)} < 500 -- reads as a flat quad, not a 3D voxel figure`);
  console.log("smoke: figure OK (NPC region is shaded 3D geometry, not a flat quad)");

  // --- v3 info: average frame interval over ~2 s of animation (headless
  // software GL is NOT representative of Firefox on the GPU -- information only).
  const fpsRes = await cmd("Runtime.evaluate", {
    awaitPromise: true,
    returnByValue: true,
    expression: `(async () => {
    let n = 0;
    const t0 = performance.now();
    await Promise.race([
      new Promise((res) => {
        const f = () => { n++; performance.now() - t0 < 2000 ? requestAnimationFrame(f) : res(); };
        requestAnimationFrame(f);
      }),
      new Promise((res) => setTimeout(res, 3000)),
    ]);
    return { frames: n, intervalMs: n > 0 ? (performance.now() - t0) / n : 0 };
  })()`,
  });
  if (fpsRes.exceptionDetails || !fpsRes.result?.value) {
    console.log("smoke: INFO frame-interval probe unavailable (best effort, not a gate)");
  } else {
    const fps = fpsRes.result.value;
    console.log(`smoke: INFO frame interval ~${fps.intervalMs.toFixed(1)} ms (${fps.frames} rAF, headless software GL)`);
  }

  // --- screenshots (human-facing evidence only; asserts stay on state)
  for (const shot of SHOTS) {
    await cmd("Emulation.setDeviceMetricsOverride", {
      width: shot.width,
      height: shot.height,
      deviceScaleFactor: 1,
      mobile: shot.mobile,
    });
    await new Promise((r) => setTimeout(r, 500)); // let the renderer resize + draw
    const shot1 = await cmd("Page.captureScreenshot", { format: "png" });
    if (!shot1.data) fail(`Page.captureScreenshot returned no data at ${shot.width}x${shot.height}`);
    const bytes = Buffer.from(shot1.data, "base64");
    const path = join(ROOT, `out/smoke-${shot.width}x${shot.height}.png`);
    writeFileSync(path, bytes);
    if (bytes.length < 10000) fail(`screenshot ${path} is only ${bytes.length} bytes -- likely blank`);
    console.log(`smoke: screenshot ${path} (${bytes.length} bytes)`);
  }

  // --- v3 deliverable screenshots: the open world, the wide map, a close-up.
  const grab = async (name) => {
    await new Promise((r) => setTimeout(r, 500)); // let the renderer settle
    const shot = await cmd("Page.captureScreenshot", { format: "png" });
    if (!shot.data) fail(`Page.captureScreenshot returned no data for ${name}`);
    const bytes = Buffer.from(shot.data, "base64");
    const path = join(ROOT, `out/${name}.png`);
    writeFileSync(path, bytes);
    if (bytes.length < 10000) fail(`screenshot ${path} is only ${bytes.length} bytes -- likely blank`);
    console.log(`smoke: screenshot ${path} (${bytes.length} bytes)`);
  };
  await cmd("Emulation.setDeviceMetricsOverride", { width: 1280, height: 800, deviceScaleFactor: 1, mobile: false });
  // The probe framed a townsfolk (reset only clears the selection, not the
  // camera); restore the OrbitCamera defaults for v3-default. The restore
  // must stay: earlier intents moved the camera, so without it this shot
  // would be a close-up instead of the default framing.
  await evaluate(`window.game.dispatch({type:"orbit",yaw:-0.6,pitch:0.72})`);
  await evaluate(`window.game.dispatch({type:"zoom",distance:60})`);
  await evaluate(`window.game.focus(17, 8)`); // the village-centre default target
  await grab("v3-default"); // camera is at the default framing here (reset above)

  const wide = JSON.parse(await evaluate(`JSON.stringify(window.game.dispatch({type:"zoom",distance:120}))`));
  if (!wide.ok) fail(`dispatch(zoom 120) failed: ${wide.error}`);
  await grab("v3-wide");

  const tfClose = centreTf; // open plaza ground; the close camera must not clip a wall
  for (const intent of [{ type: "reset" }, { type: "orbit", yaw: 0.6, pitch: 0.35 }, { type: "zoom", distance: 4 }]) {
    const res = JSON.parse(await evaluate(`JSON.stringify(window.game.dispatch(${JSON.stringify(intent)}))`));
    if (!res.ok) fail(`dispatch(${JSON.stringify(intent)}) failed: ${res.error}`);
  }
  // The sim auto-ticks, so the townsfolk wanders off a focused cell; re-focus
  // its live cell until entityScreenPos puts it near frame centre.
  let framed = null;
  for (let i = 0; i < 10 && !framed; i++) {
    const live = JSON.parse(await evaluate("JSON.stringify(window.game.state())"))
      .townsfolk.find((t) => t.id === tfClose.id) ?? tfClose;
    await evaluate(`window.game.focus(${live.x}, ${live.y})`);
    await waitFrames(2);
    const pos = await evaluate(`window.game.entityScreenPos(${tfClose.id})`);
    if (pos && Math.abs(pos.x - 640) < 220 && Math.abs(pos.y - 400) < 220) framed = pos;
  }
  if (!framed) fail(`could not centre townsfolk ${tfClose.id} for v3-close within 10 focus attempts`);
  await grab("v3-close");

  // --- no-fetch: every request same-origin
  const offOrigin = requests
    .filter((u) => !u.startsWith("about:") && !u.startsWith("devtools:"))
    .map((u) => {
      try {
        return new URL(u);
      } catch {
        return null;
      }
    })
    .filter((u) => u && u.origin !== baseOrigin);
  if (offOrigin.length > 0) {
    fail(`runtime fetched cross-origin (acceptance 5): ${offOrigin.slice(0, 5).map((u) => u.href).join(", ")}`);
  }
  console.log(`smoke: network OK (${requests.length} requests, all same-origin)`);

  // Acceptance 5, offline half: with the NIC emulated offline the game must
  // keep playing -- zero runtime fetch dependency.
  await cmd("Network.emulateNetworkConditions", {
    offline: true,
    latency: 0,
    downloadThroughput: 0,
    uploadThroughput: 0,
  });
  const off = JSON.parse(await evaluate(`JSON.stringify(window.game.dispatch({type:"inspect",x:0,y:0}))`));
  if (!off.ok) fail("dispatch under offline emulation failed");
  const offSel = JSON.parse(await evaluate("JSON.stringify(window.game.state().selection)"));
  if (offSel?.text !== off.state.selection?.text) fail("state().selection differs under offline emulation");
  const during = requests
    .slice()
    .filter((u) => !u.startsWith("about:") && !u.startsWith("devtools:") && !u.startsWith(baseOrigin + "/"));
  if (during.length > 0 || blocked.length > 0) {
    fail(`runtime fetch dependency (acceptance 5): blocked=[${blocked.slice(0, 3).join(", ")}] offline=[${during.slice(0, 3).join(", ")}]`);
  }
  console.log("smoke: offline OK (non-local requests hard-blocked; game plays with the NIC offline)");

  await cmd("Target.closeTarget", { targetId });
  browser.close();
  server.kill();
  chromium.kill("SIGKILL");
  rmSync(profileDir, { recursive: true, force: true });
  console.log("smoke: PASS");
} catch (e) {
  browser?.close();
  server.kill();
  chromium?.kill("SIGKILL");
  if (profileDir) rmSync(profileDir, { recursive: true, force: true });
  fail(e.message);
}
