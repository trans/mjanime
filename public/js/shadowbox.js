// Shadowbox editor — ported from siliconcircus sbedit.html, wired to mj.
// Scenes are stacks of images at real depths. A layer carries POSITION (x,y,z) and SCALE in world
// units. There is no "backdrop" type — a room is just a big image far away. Two alignment ideas do
// the heavy lifting: HORIZON (every image's baked eye-level sits at world y=0) and SCALE (an image
// reproduces its shot FOV when it subtends the same angle, so scale IS the FOV knob). FLOOR seats
// grounded props. Adaptations from the original: assets come from mj's /shadowbox/assets.json, three
// is vendored at /vendor, the app fits under mj's nav, and scenes carry open `meta` fields (scene +
// per-layer) so the JSON format is portable for other programs.
import * as THREE from "/vendor/three.module.js";

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const $ = id => document.getElementById(id);
const stage = $("stage"), app = $("sbapp");

// Fit the editor under mj's nav (it's position:fixed; top defaults to 56px in CSS).
const navH = document.querySelector("nav")?.offsetHeight || 56;
app.style.top = navH + "px";
document.body.style.overflow = "hidden";

const scene = new THREE.Scene(); scene.background = new THREE.Color(0x07060a);
const box = new THREE.Group(); scene.add(box);
let HFOV = 62 * Math.PI / 180;
const cam = new THREE.PerspectiveCamera(50, 1, 0.05, 400);
cam.rotation.order = "YXZ";
const rend = new THREE.WebGLRenderer({ antialias: true });
rend.setPixelRatio(Math.min(devicePixelRatio, 2));
stage.appendChild(rend.domElement);

const loader = new THREE.TextureLoader();
const art = src => { const t = loader.load(src); t.colorSpace = THREE.SRGBColorSpace; return t; };

// The scene model — this object IS the exported file. layer: {src,w,h, x,y,z, scale, horizon, shadow, meta}
const S = {
  name: "untitled", meta: {}, floorY: -1.6, lens: 62,
  cam: { x: 1.2, y: 0.35, z: 1.5, yaw: 22, pitch: 10 },
  layers: []
};

const SHADOW_TEX = (() => {
  const c = document.createElement("canvas"); c.width = c.height = 128; const g = c.getContext("2d");
  const rg = g.createRadialGradient(64, 64, 2, 64, 64, 62);
  rg.addColorStop(0, "rgba(0,0,0,0.68)"); rg.addColorStop(0.55, "rgba(0,0,0,0.26)"); rg.addColorStop(1, "rgba(0,0,0,0)");
  g.fillStyle = rg; g.fillRect(0, 0, 128, 128);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
})();

let sel = -1;
const sels = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.PlaneGeometry(1, 1)),
  new THREE.LineBasicMaterial({ color: 0xf0b64a })); sels.visible = false; scene.add(sels);
const floorGrid = new THREE.GridHelper(80, 40, 0x4a6a8a, 0x243444); floorGrid.visible = false; scene.add(floorGrid);
const horizLine = (() => {
  const g = new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(-120, 0, -90), new THREE.Vector3(120, 0, -90)]);
  const l = new THREE.Line(g, new THREE.LineBasicMaterial({ color: 0x6ad0ff })); l.visible = false; scene.add(l); return l;
})();
const camBox = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(1, 1, 1)),
  new THREE.LineBasicMaterial({ color: 0x62d68a })); camBox.visible = false; scene.add(camBox);

function viewAt(dist) { const h = 2 * dist * Math.tan(cam.fov * Math.PI / 360); return { w: h * cam.aspect, h }; }

function rebuild() {
  while (box.children.length) { const o = box.children[0]; box.remove(o); o.geometry?.dispose?.(); o.material?.dispose?.(); }
  for (const L of S.layers) { L.m = null; L.sh = null; }
  for (const L of S.layers) {
    L.m = new THREE.Mesh(new THREE.PlaneGeometry(1, 1),
      new THREE.MeshBasicMaterial({ map: art(L.src), transparent: true, alphaTest: 0.04, depthWrite: false }));
    box.add(L.m);
    if (L.shadow) {
      L.sh = new THREE.Mesh(new THREE.PlaneGeometry(1, 1),
        new THREE.MeshBasicMaterial({ map: SHADOW_TEX, transparent: true, depthWrite: false, opacity: 0.85 }));
      box.add(L.sh);
    }
  }
  layout(); listLayers();
}
function layout() {
  for (const L of S.layers) {
    if (!L.m) continue;
    const h = L.scale, w = h * L.w / L.h;
    L.m.scale.set(w, h, 1); L.m.position.set(L.x, L.y, L.z);
    if (L.sh) { L.sh.scale.set(w * 1.45, h * 0.15, 1); L.sh.position.set(L.x, L.y - h / 2 + h * 0.015, L.z - 0.02); }
  }
  floorGrid.position.set(0, S.floorY, -14);
  camBox.scale.set(Math.max(0.02, S.cam.x * 2), Math.max(0.02, S.cam.y * 2), Math.max(0.02, S.cam.z * 2));
  if (sel >= 0 && S.layers[sel]?.m) { const m = S.layers[sel].m; sels.visible = !playing; sels.scale.copy(m.scale); sels.position.copy(m.position); }
  else sels.visible = false;
}
function resize() {
  const w = stage.clientWidth, h = stage.clientHeight;
  cam.aspect = w / h; cam.fov = 2 * Math.atan(Math.tan(HFOV / 2) / cam.aspect) * 180 / Math.PI;
  cam.updateProjectionMatrix(); rend.setSize(w, h); layout();
}
addEventListener("resize", resize);

// palette — from mj's asset manifest
let MANIFEST = [], filter = "all";
fetch("/shadowbox/assets.json").then(r => r.json()).then(m => {
  MANIFEST = m; drawPalette();
  const bg = m.find(a => !a.cut); if (bg) addLayer(bg.src);   // seed with the first backdrop (de-piraten: no hardcoded room)
});
function drawPalette() {
  const q = $("search").value.toLowerCase();
  const list = MANIFEST.filter(a =>
    (filter === "all" || (filter === "prop" && a.cut) || (filter === "full" && !a.cut)) && a.src.toLowerCase().includes(q));
  $("palette").innerHTML = list.map(a =>
    `<div class="th ${a.cut ? "" : "full"}" data-src="${a.src}" title="${(a.name || a.src)}">
       <img src="${a.src}" loading="lazy"></div>`).join("");
  $("palette").querySelectorAll(".th").forEach(el => el.onclick = () => addLayer(el.dataset.src));
}
$("search").oninput = drawPalette;
for (const [id, f] of [["tAll", "all"], ["tProp", "prop"], ["tFull", "full"]])
  $(id).onclick = () => { filter = f; for (const t of ["tAll", "tProp", "tFull"]) $(t).classList.toggle("on", t === id); drawPalette(); };

function addLayer(src) {
  const a = MANIFEST.find(x => x.src === src); if (!a) return;
  const z = a.cut ? -6 : -16;
  const scale = a.cut ? 1.6 : viewAt(-z).h * 1.25;
  const L = { src, w: a.w, h: a.h, x: 0, y: (a.cut ? S.floorY + scale / 2 : 0), z, scale, horizon: 0.5, shadow: !!a.cut, meta: {} };
  S.layers.push(L); S.layers.sort((p, q) => p.z - q.z);
  sel = S.layers.indexOf(L); rebuild(); showSel();
}

// selection + properties
function listLayers() {
  const rows = S.layers.map((L, i) => ({ L, i })).sort((a, b) => b.L.z - a.L.z);
  $("layers").innerHTML = rows.map(({ L, i }) =>
    `<li class="${i === sel ? 'sel' : ''}" data-i="${i}">
       <img src="${L.src}"><span class="nm">${L.src.split("/").pop().replace(/\.(webp|png|jpg)$/, "")}</span>
       <span class="zz">z${L.z.toFixed(1)}</span><span class="x" data-del="${i}" title="delete">✕</span></li>`).join("")
    || `<li class="dim" style="cursor:default">— empty —</li>`;
  $("layers").querySelectorAll("li[data-i]").forEach(el => {
    el.onclick = ev => { if (ev.target.dataset.del !== undefined) return; sel = +el.dataset.i; listLayers(); showSel(); layout(); };
  });
  $("layers").querySelectorAll("[data-del]").forEach(el =>
    el.onclick = ev => { ev.stopPropagation(); S.layers.splice(+el.dataset.del, 1); sel = -1; rebuild(); showSel(); });
}
function showSel() {
  const L = S.layers[sel];
  if (!L) { $("sel").innerHTML = '<span class="dim">nothing selected</span>'; layout(); return; }
  $("sel").innerHTML = `
    <div class="row"><label>x</label><input type="range" id="px" min="-30" max="30" step="0.05" value="${L.x}"><span class="val">${L.x.toFixed(2)}</span></div>
    <div class="row"><label>y</label><input type="range" id="py" min="-20" max="20" step="0.05" value="${L.y}"><span class="val">${L.y.toFixed(2)}</span></div>
    <div class="row"><label>z</label><input type="range" id="pz" min="-60" max="-1" step="0.1" value="${L.z}"><span class="val">${L.z.toFixed(2)}</span></div>
    <div class="row"><label>scale</label><input type="range" id="ps" min="0.05" max="80" step="0.05" value="${L.scale}"><span class="val">${L.scale.toFixed(2)}</span></div>
    <div class="row"><label>horizon</label><input type="range" id="ph" min="0" max="1" step="0.005" value="${L.horizon}"><span class="val">${L.horizon.toFixed(3)}</span></div>
    <div class="row"><label>shadow</label><input type="checkbox" id="psh" ${L.shadow ? "checked" : ""}></div>
    <div class="two"><button id="palign" title="set y so this image's horizon sits on the line of sight">Align horizon</button>
                     <button id="pfloor" title="set y so this sits on the floor line">Drop to floor</button></div>
    <div class="two"><button id="pdel">Delete</button></div>`;
  const bind = (id, f) => { const el = $(id); if (el) el.oninput = () => { f(parseFloat(el.value)); el.nextElementSibling.textContent = parseFloat(el.value).toFixed(id === "ph" ? 3 : 2); layout(); listLayers(); }; };
  bind("px", v => L.x = v); bind("py", v => L.y = v); bind("pz", v => L.z = v); bind("ps", v => L.scale = v); bind("ph", v => L.horizon = v);
  $("psh").onchange = e => { L.shadow = e.target.checked; rebuild(); showSel(); };
  $("palign").onclick = () => { L.y = L.scale * (L.horizon - 0.5); showSel(); };
  $("pfloor").onclick = () => { L.y = S.floorY + L.scale / 2; showSel(); };
  $("pdel").onclick = () => { S.layers.splice(sel, 1); sel = -1; rebuild(); showSel(); };
  layout();
}

// direct manipulation (edit mode)
const ray = new THREE.Raycaster(), ndc = new THREE.Vector2();
let drag = null;
function pick(e) {
  const r = rend.domElement.getBoundingClientRect();
  ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
  ray.setFromCamera(ndc, cam);
  const hits = ray.intersectObjects(S.layers.filter(L => L.m).map(L => L.m), false);
  if (!hits.length) return -1;
  const idx = hits.map(h => S.layers.findIndex(L => L.m === h.object)).filter(i => i >= 0);
  return idx.length ? idx[(idx.indexOf(sel) + 1) % idx.length] : -1;
}
rend.domElement.addEventListener("pointerdown", e => {
  if (playing) { rend.domElement.requestPointerLock?.(); return; }
  const i = pick(e); sel = i; listLayers(); showSel();
  if (i >= 0) drag = { i, px: e.clientX, py: e.clientY };
  rend.domElement.setPointerCapture(e.pointerId);
});
rend.domElement.addEventListener("pointermove", e => {
  if (!drag || playing) return;
  const L = S.layers[drag.i], r = rend.domElement.getBoundingClientRect(), v = viewAt(-L.z);
  L.x += ((e.clientX - drag.px) / r.width) * v.w;
  L.y -= ((e.clientY - drag.py) / r.height) * v.h;
  drag.px = e.clientX; drag.py = e.clientY;
  layout(); listLayers();
});
addEventListener("pointerup", () => { if (drag) { drag = null; showSel(); } });
rend.domElement.addEventListener("wheel", e => {
  if (playing || sel < 0) return; e.preventDefault();
  const L = S.layers[sel], d = Math.sign(e.deltaY);
  if (e.shiftKey) { L.z = clamp(L.z + d * 0.5, -60, -1); S.layers.sort((p, q) => p.z - q.z); sel = S.layers.indexOf(L); }
  else L.scale = clamp(L.scale * (1 - d * 0.06), 0.05, 80);
  layout(); listLayers(); showSel();
}, { passive: false });

// scene + camera-box sliders
const slider = (id, get, set, fmt) => {
  const el = $(id), out = $(id + "V");
  el.value = get(); out.textContent = fmt(get());
  el.oninput = () => { set(parseFloat(el.value)); out.textContent = fmt(parseFloat(el.value)); layout(); };
};
slider("floor", () => S.floorY, v => S.floorY = v, v => v.toFixed(2));
slider("lens", () => S.lens, v => { S.lens = v; HFOV = v * Math.PI / 180; resize(); }, v => v.toFixed(0) + "°");
slider("cx", () => S.cam.x, v => S.cam.x = v, v => v.toFixed(2));
slider("cy", () => S.cam.y, v => S.cam.y = v, v => v.toFixed(2));
slider("cz", () => S.cam.z, v => S.cam.z = v, v => v.toFixed(2));
slider("cyaw", () => S.cam.yaw, v => S.cam.yaw = v, v => v.toFixed(0) + "°");
slider("cpit", () => S.cam.pitch, v => S.cam.pitch = v, v => v.toFixed(0) + "°");
const toggle = (id, obj) => $(id).onclick = () => { obj.visible = !obj.visible; $(id).classList.toggle("on", obj.visible); };
toggle("grid", floorGrid); toggle("horiz", horizLine); toggle("cbox", camBox);

// the walk-through
let playing = false, YAW = 0, PITCH = 0;
const keys = new Set();
function setPlay(p) {
  playing = p; app.classList.toggle("playing", p); $("preview").classList.toggle("on", p);
  floorGrid.visible = p ? false : floorGrid.visible; camBox.visible = p ? false : camBox.visible;
  if (p) { YAW = 0; PITCH = 0; cam.position.set(0, 0, 0); }
  else { document.exitPointerLock?.(); cam.position.set(0, 0, 0); cam.rotation.set(0, 0, 0); }
  setTimeout(resize, 200); layout();
}
$("preview").onclick = () => setPlay(!playing);
addEventListener("mousemove", e => {
  if (!playing || document.pointerLockElement !== rend.domElement) return;
  YAW = clamp(YAW - e.movementX * 0.0022, -S.cam.yaw * Math.PI / 180, S.cam.yaw * Math.PI / 180);
  PITCH = clamp(PITCH - e.movementY * 0.0022, -S.cam.pitch * Math.PI / 180, S.cam.pitch * Math.PI / 180);
});
addEventListener("keydown", e => {
  if (e.target.tagName === "INPUT" && (e.target.type === "text" || e.target.type === "file")) return;
  const k = e.key.toLowerCase();
  if (k === "p") { setPlay(!playing); e.preventDefault(); return; }
  if (k === "escape" && playing) { setPlay(false); e.preventDefault(); return; }
  if (!playing && (k === "delete" || k === "backspace") && sel >= 0) { S.layers.splice(sel, 1); sel = -1; rebuild(); showSel(); e.preventDefault(); return; }
  if (playing) { keys.add(k); e.preventDefault(); }
});
addEventListener("keyup", e => keys.delete(e.key.toLowerCase()));
const kk = k => keys.has(k) ? 1 : 0;

// serialize / apply — shared by the scene library (save/open) and the file export/import
function serializeScene() {
  return {
    name: S.name, meta: S.meta, floorY: S.floorY, lens: S.lens, cam: S.cam,
    layers: S.layers.map(L => ({
      src: L.src, w: L.w, h: L.h, x: +L.x.toFixed(3), y: +L.y.toFixed(3), z: +L.z.toFixed(3),
      scale: +L.scale.toFixed(3), horizon: +(L.horizon ?? 0.5).toFixed(3), shadow: !!L.shadow, meta: L.meta || {}
    }))
  };
}
function applyScene(j) {
  S.name = j.name || "untitled"; S.meta = j.meta || {}; S.floorY = j.floorY ?? -1.6; S.lens = j.lens || 62;
  S.cam = Object.assign({ x: 1.2, y: 0.35, z: 1.5, yaw: 22, pitch: 10 }, j.cam || {});
  S.layers = (j.layers || []).map(L => ({ x: 0, y: 0, z: -6, scale: 1.6, horizon: 0.5, shadow: false, meta: {}, ...L }));
  $("name").value = S.name; HFOV = S.lens * Math.PI / 180;
  const map = { floor: S.floorY, lens: S.lens, cx: S.cam.x, cy: S.cam.y, cz: S.cam.z, cyaw: S.cam.yaw, cpit: S.cam.pitch };
  for (const id in map) { $(id).value = map[id]; $(id + "V").textContent = (id === "lens" || id === "cyaw" || id === "cpit") ? Math.round(map[id]) + "°" : (+map[id]).toFixed(2); }
  sel = -1; resize(); rebuild(); showSel();
}
const status = (msg, cls) => { const s = $("status"); s.textContent = msg; s.className = "stat" + (cls ? " " + cls : ""); if (msg) setTimeout(() => { if (s.textContent === msg) { s.textContent = ""; s.className = "stat"; } }, 2600); };

$("name").oninput = e => S.name = e.target.value;

// scene library — save / open / delete by name
function refreshScenes(selected) {
  fetch("/shadowbox/scenes").then(r => r.json()).then(list => {
    const cur = selected ?? "";
    $("scenes").innerHTML = `<option value="">Open…</option>` +
      list.map(s => `<option value="${s.name}" ${s.name === cur ? "selected" : ""}>${s.name} · ${s.layers}L</option>`).join("");
  }).catch(() => {});
}
$("dosave").onclick = () => {
  const name = (S.name || "untitled").trim();
  fetch("/shadowbox/scenes/" + encodeURIComponent(name), {
    method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify(serializeScene())
  }).then(async r => {
    const j = await r.json().catch(() => ({}));
    if (r.ok) { S.name = j.saved || name; $("name").value = S.name; status("saved “" + S.name + "”", "ok"); refreshScenes(S.name); }
    else status(j.error || "save failed", "err");
  }).catch(() => status("save failed", "err"));
};
$("scenes").onchange = e => {
  const name = e.target.value; if (!name) return;
  fetch("/shadowbox/scenes/" + encodeURIComponent(name)).then(r => r.json()).then(j => {
    applyScene(j); status("opened “" + name + "”", "ok");
  }).catch(() => status("open failed", "err"));
};
$("dodelete").onclick = () => {
  const name = (S.name || "").trim(); if (!name) return;
  if (!confirm(`Delete scene “${name}” from the library?`)) return;
  fetch("/shadowbox/scenes/" + encodeURIComponent(name), { method: "DELETE" }).then(r => {
    if (r.ok) { status("deleted “" + name + "”", "ok"); refreshScenes(); } else status("not in library", "err");
  }).catch(() => status("delete failed", "err"));
};
refreshScenes();

// file export / import — portability, independent of the library
$("exportfile").onclick = () => {
  const blob = new Blob([JSON.stringify(serializeScene(), null, 2)], { type: "application/json" });
  const a = document.createElement("a"); a.href = URL.createObjectURL(blob); a.download = (S.name || "scene") + ".json"; a.click();
};
$("loadfile").onclick = () => $("file").click();
$("file").onchange = e => {
  const f = e.target.files[0]; if (!f) return;
  f.text().then(t => { applyScene(JSON.parse(t)); status("imported file", "ok"); }).catch(() => status("bad file", "err"));
};

const WALK = 2.4, RISE = 1.2;
let last = performance.now();
function tick(now) {
  requestAnimationFrame(tick);
  const dt = Math.min(0.05, (now - last) / 1000); last = now; const t = now / 1000;
  if (playing) {
    const f = (kk("w") + kk("arrowup")) - (kk("s") + kk("arrowdown"));
    const s = (kk("d") + kk("arrowright")) - (kk("a") + kk("arrowleft"));
    const u = kk("r") - kk("f");
    const sp = kk("shift") ? 0.35 : 1;
    const sn = Math.sin(YAW), cs = Math.cos(YAW);
    let x = cam.position.x + (-f * sn + s * cs) * WALK * sp * dt;
    let z = cam.position.z + (-f * cs - s * sn) * WALK * sp * dt;
    let y = cam.position.y + u * RISE * sp * dt;
    cam.position.set(clamp(x, -S.cam.x, S.cam.x), clamp(y, -S.cam.y, S.cam.y), clamp(z, -S.cam.z, S.cam.z));
    cam.rotation.set(PITCH, YAW, Math.sin(t * 0.37) * 0.005);
  }
  rend.render(scene, cam);
}
resize(); requestAnimationFrame(tick);
