// Diorama player — a saved scene rendered chrome-less. Ported from siliconcircus index.html (the
// drift/parallax loop) but scene-driven: it reads the scene name from the URL, fetches the scene JSON
// from mj, places each layer at its stored world position, and lets the camera DRIFT inside the box
// (or WALK through it, clamped to the scene's camera box). This is the "play" third of
// generate → compose → play, and the format other programs can copy.
import * as THREE from "/vendor/three.module.js";

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const stage = document.getElementById("stage");
const sceneName = decodeURIComponent((location.pathname.split("/").filter(Boolean).pop()) || "");

const scene = new THREE.Scene(); scene.background = new THREE.Color(0x07060a);
const box = new THREE.Group(); scene.add(box);
let HFOV = 62 * Math.PI / 180;
const cam = new THREE.PerspectiveCamera(50, innerWidth / innerHeight, 0.05, 6000);
cam.rotation.order = "YXZ";
const rend = new THREE.WebGLRenderer({ antialias: true });
rend.setPixelRatio(Math.min(devicePixelRatio, 2));
stage.appendChild(rend.domElement);

const loader = new THREE.TextureLoader();
// Anisotropy is not optional for a floor: a ground plane is viewed at grazing incidence, where
// plain mipmapping collapses the texture into a smooth smear a few metres out.
const MAXANISO = rend.capabilities.getMaxAnisotropy();
const art = src => {
  const t = loader.load(src);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = MAXANISO;
  return t;
};

const SHADOW_TEX = (() => {
  const c = document.createElement("canvas"); c.width = c.height = 128; const g = c.getContext("2d");
  const rg = g.createRadialGradient(64, 64, 2, 64, 64, 62);
  rg.addColorStop(0, "rgba(0,0,0,0.68)"); rg.addColorStop(0.55, "rgba(0,0,0,0.26)"); rg.addColorStop(1, "rgba(0,0,0,0)");
  g.fillStyle = rg; g.fillRect(0, 0, 128, 128);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
})();

// scene model, filled from the fetched JSON
let S = { floorY: -1.6, lens: 62, cam: { x: 1.2, y: 0.35, z: 1.5, yaw: 22, pitch: 10 }, meta: {}, layers: [] };
let DX = 0.5, DY = 0.22;          // drift amplitude, derived from the camera box
let sway = true;                  // gentle ambient motion unless the scene disables it

// A layer is normally sized by `scale` (the image height in world units) with the width following
// from the image aspect. A tiled floor can't work that way -- its world size and its texture aspect
// are unrelated -- so `size: [w, d]` overrides both, and `repeat: [u, v]` tiles the texture across
// it. Near ground needs ~200 px/m of detail; one stretched image can never supply that, a repeated
// one can.
function planeSize(L) {
  if (L.size) return [L.size[0], L.size[1]];
  const h = L.scale;
  return [h * L.w / L.h, h];
}
function tileTexture(t, L) {
  if (!L.repeat) return t;
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(L.repeat[0], L.repeat[1]);
  return t;
}

// An imposter carries a set of bearings rather than one image; decode them all up front so a
// swap is a map assignment, not a network round-trip at the moment the viewer is looking away.
function layerTexture(L) {
  if (L.plane === "imposter") {
    L._tex = L.srcs.map(s => art(s));
    L._shown = 0;
    return L._tex[0];
  }
  return tileTexture(art(L.src), L);
}

// A wrap-around sky wants to be a DOME, not a ring of cards. Chord segments stop abutting the
// moment the camera leaves the centre, and no card is tall enough once you can pitch up 70 deg.
// One inside-out sphere solves both, and three.js has the flip-flop tiling built in:
// MirroredRepeatWrapping alternates the image, so every repeat joins its neighbour edge-to-edge.
function buildSky(L) {
  const t = art(L.src);
  t.wrapS = THREE.MirroredRepeatWrapping;
  t.wrapT = THREE.ClampToEdgeWrapping;
  // Wrapping N times covers 360/N degrees of azimuth with the image's WIDTH, but v still spans a
  // full 180 degrees of latitude -- leave repeat.y at 1 and the sky stretches vertically by
  // 2N*h/w (3.6x at N=4, which turns a treeline into a mountain range). Derive it so a degree of
  // sky is the same size across as it is up, and clamp above and below the band.
  const rx = L.repeat ? L.repeat[0] : 4;
  const ry = rx * L.w / (2 * L.h);
  t.repeat.set(rx, ry);
  // land the plate's painted horizon on the equator (texture v runs bottom-up)
  t.offset.set(0, (1 - (L.horizon ?? 0.5)) - 0.5 * ry);
  const m = new THREE.Mesh(
    new THREE.SphereGeometry(L.radius || 400, 48, 24),
    new THREE.MeshBasicMaterial({ map: t, side: THREE.BackSide, fog: false, depthWrite: false }));
  m.position.set(L.x, L.y, L.z);
  m.renderOrder = L.order ?? -10;
  return m;
}

function build() {
  for (const L of S.layers) {
    if (L.plane === "sky") { L.m = buildSky(L); box.add(L.m); continue; }
    const m = new THREE.Mesh(new THREE.PlaneGeometry(1, 1),
      new THREE.MeshBasicMaterial({ map: layerTexture(L), transparent: true, alphaTest: 0.04, depthWrite: false, side: THREE.DoubleSide, fog: !L.meta?.nofog }));
    const [w, h] = planeSize(L);
    m.scale.set(L.flipX ? -w : w, h, 1); m.position.set(L.x, L.y, L.z);
    m.rotation.order = "YXZ";                 // Y applied OUTSIDE X: spin the flattened plane
    if (L.plane === "floor") m.rotation.x = -Math.PI / 2;   // lay it flat: +Y -> -Z, so scale.y is DEPTH
    if (L.rotY) m.rotation.y = L.rotY * Math.PI / 180;
    m.renderOrder = L.order || 0;
    L.m = m; box.add(m);
    if (L.occluder) OCCLUDERS.push({ mesh: m, alpha: alphaSampler(m.material.map) });

    if (L.shadow) {
      const sh = new THREE.Mesh(new THREE.PlaneGeometry(1, 1),
        new THREE.MeshBasicMaterial({ map: SHADOW_TEX, transparent: true, depthWrite: false, opacity: 0.85 }));
      sh.scale.set(w * 1.45, h * 0.15, 1); sh.position.set(L.x, L.y - h / 2 + h * 0.015, L.z - 0.02);
      L.sh = sh; box.add(sh);
    }
  }
}
// Billboarding — a layer may TURN to face the camera, clamped to ±`billboard` degrees. The cards are
// flat, so a subject that reads wrong in profile (a crow, a gargoyle, a roughly symmetric shrub) can
// keep looking at the viewer through the drift. 0 / absent = a fixed pane, the original behaviour.
// The ground shadow never turns — it stays a flat smudge under the card.

// ── Imposter: one object, eight painted bearings ────────────────────────────────────────────────
// A flat card cannot be walked around -- turn 90 degrees and it is a line. An imposter carries a
// SET of images, one per 45 degrees around the subject, and shows whichever matches where the
// viewer is standing. The seam is the problem: swapping while the thing is in plain sight is a
// visible pop. So the swap is DEFERRED until the subject is hidden -- occluded by scenery, or off
// the edge of the screen -- and the viewer only ever discovers the new angle after the trees clear.
const OCCLUDERS = [];             // meshes flagged `occluder: true`, with an alpha sampler each

// Sample a texture's alpha cheaply: a tree card's quad is mostly empty, so a raycast hitting the
// quad proves nothing. What matters is whether the hit UV lands on an opaque texel.
function alphaSampler(tex, size = 128) {
  const c = document.createElement("canvas"); c.width = c.height = size;
  const g = c.getContext("2d", { willReadFrequently: true });
  let data = null;
  const load = () => {
    const img = tex.image;
    if (!img || !img.width) return;
    g.clearRect(0, 0, size, size);
    g.drawImage(img, 0, 0, size, size);
    try { data = g.getImageData(0, 0, size, size).data; } catch (e) { data = null; }
  };
  if (tex.image && tex.image.width) load(); else tex.addEventListener?.("update", load);
  setTimeout(load, 400); setTimeout(load, 2000);          // textures stream in
  return (u, v) => {
    if (!data) return 1;                                   // not decoded yet: assume solid
    const x = Math.min(size - 1, Math.max(0, Math.floor(u * size)));
    const y = Math.min(size - 1, Math.max(0, Math.floor((1 - v) * size)));
    return data[(y * size + x) * 4 + 3] / 255;
  };
}

const IMP_RAY = new THREE.Raycaster();
const IMP_V = new THREE.Vector3();

function bearingIndex(L, camera) {
  const n = L.srcs.length;
  const a = Math.atan2(camera.position.x - L.x, camera.position.z - L.z);   // 0 = straight in front
  return ((Math.round(a / (2 * Math.PI / n)) % n) + n) % n;
}

// Sampled across the subject's silhouette, not at its centre. One trunk in front of the middle of
// a wide house still leaves both flanks in view, and swapping then is exactly the pop this is meant
// to avoid -- so EVERY sample must be covered before the swap is allowed.
const IMP_SAMPLES = [[0, 0], [-0.45, 0], [0.45, 0], [0, 0.35], [-0.3, 0.3], [0.3, 0.3]];
const IMP_RIGHT = new THREE.Vector3(), IMP_UP = new THREE.Vector3(0, 1, 0), IMP_P = new THREE.Vector3();

function covered(p, camera) {
  const ndc = IMP_P.copy(p).project(camera);
  if (ndc.z > 1 || Math.abs(ndc.x) > 1.05 || Math.abs(ndc.y) > 1.05) return true;   // off-screen
  if (!OCCLUDERS.length) return false;
  const dir = p.clone().sub(camera.position);
  const dist = dir.length();
  IMP_RAY.set(camera.position, dir.normalize());
  IMP_RAY.far = dist;
  for (const hit of IMP_RAY.intersectObjects(OCCLUDERS.map(o => o.mesh), false)) {
    if (hit.distance >= dist) break;
    const s = OCCLUDERS.find(o => o.mesh === hit.object);
    // 0.15, not 0.5: foliage is full of small gaps, and a haze of pine needles genuinely does
    // hide what is behind it even though few individual texels are fully opaque. Demanding a
    // solid texel per ray made occlusion stochastic -- clumps registered or not by luck of
    // alignment. This is still far stricter than testing the card's bounding quad.
    if (hit.uv && s && s.alpha(hit.uv.x, hit.uv.y) > 0.15) return true;
  }
  return false;
}

function hidden(L, camera) {
  const h = L.scale, w = h * L.w / L.h;
  // the card faces the viewer, so its horizontal axis is the camera's right vector
  IMP_RIGHT.set(camera.position.z - L.z, 0, -(camera.position.x - L.x)).normalize();
  for (const [u, v] of IMP_SAMPLES) {
    IMP_V.set(L.x + IMP_RIGHT.x * u * w, L.y + v * h, L.z + IMP_RIGHT.z * u * w);
    if (!covered(IMP_V, camera)) return false;
  }
  return true;
}

function stepImposters(camera) {
  box.updateMatrixWorld(true);        // occluders were just re-aimed by faceCamera()
  // Debug: drop the camera anywhere on the map, aim it at the imposter, and report what the
  // occlusion test makes of that spot. Sweeping this round the circuit measures coverage far more
  // cheaply, and far more precisely, than reading screenshots.
  if (S.meta?.imposterLog && !window.__impCam) window.__impCam = (x, z) => {
    const L = S.layers.find(l => l.plane === "imposter");
    camera.position.set(x, 0, z);
    camera.lookAt(L.x, L.y, L.z);
    camera.updateMatrixWorld(true);
    faceCamera();                       // re-aim billboarded occluders for this viewpoint
    box.updateMatrixWorld(true);
    const n = IMP_P.set(L.x, L.y, L.z).project(camera);
    const h = L.scale, w = h * L.w / L.h;
    IMP_RIGHT.set(camera.position.z - L.z, 0, -(camera.position.x - L.x)).normalize();
    const per = IMP_SAMPLES.map(([u, v]) => {
      IMP_V.set(L.x + IMP_RIGHT.x * u * w, L.y + v * h, L.z + IMP_RIGHT.z * u * w);
      return covered(IMP_V, camera) ? "#" : ".";
    }).join("");
    return { hidden: hidden(L, camera), want: bearingIndex(L, camera), shown: L._shown, samples: per,
             onScreen: n.z <= 1 && Math.abs(n.x) <= 1.05 && Math.abs(n.y) <= 1.05 };
  };
  if (S.meta?.imposterLog && !window.__imp) window.__imp = () => ({
    cam: [+camera.position.x.toFixed(2), +camera.position.z.toFixed(2)],
    layers: S.layers.filter(l => l.plane === "imposter").map(l => ({
      shown: l._shown, want: bearingIndex(l, camera), hidden: hidden(l, camera),
      onScreen: (() => { const n = IMP_P.set(l.x, l.y, l.z).project(camera);
                         return n.z <= 1 && Math.abs(n.x) <= 1.05 && Math.abs(n.y) <= 1.05; })(),
      occ: OCCLUDERS.length })),
  });
  for (const L of S.layers) {
    if (L.plane !== "imposter" || !L.m) continue;
    const want = bearingIndex(L, camera);
    if (want === L._shown) continue;
    const free = S.meta?.imposterAlways;                   // debug: swap on sight, to prove wiring
    const hid = free || hidden(L, camera);
    if (!hid) continue;                                    // in view: hold the old angle
    if (S.meta?.imposterLog)
      console.log(`[imposter] ${L.meta?.imposter} ${L._shown} -> ${want} (${free ? "forced" : "hidden"})`);
    L._shown = want;
    L.m.material.map = L._tex[want];
    L.m.material.needsUpdate = true;
  }
}

function faceCamera() {
  for (const L of S.layers) {
    if (!L.m) continue;
    if (L.plane === "floor" || L.plane === "sky") continue;
    if (L.plane === "imposter") {                        // an imposter is a billboard by definition
      L.m.rotation.y = Math.atan2(cam.position.x - L.m.position.x, cam.position.z - L.m.position.z);
      continue;
    }                   // a floor never turns
    const lim = (L.billboard || 0) * Math.PI / 180;
    if (lim <= 0) { L.m.rotation.y = 0; continue; }
    const want = Math.atan2(cam.position.x - L.m.position.x, cam.position.z - L.m.position.z);
    L.m.rotation.y = clamp(want, -lim, lim);
  }
}

// Depth haze. Aerial perspective is what makes a stack of equally-crisp cards read as distance, so
// a scene may carry meta.fog = {color, density} and the far layers fade into the backdrop's own
// horizon colour. The backdrop plate itself opts out with meta.nofog, or it would fog to a flat wash.
function applyFog(f) {
  if (!f) { scene.fog = null; return; }
  const c = new THREE.Color(f.color ?? 0x2d3750);
  scene.fog = new THREE.FogExp2(c, f.density ?? 0.012);
  // Fog colour belongs at the HORIZON; the page behind everything is mostly ZENITH. A sky
  // enclosure can never be tall enough for every pitch, so match what shows above it.
  scene.background = new THREE.Color(f.background ?? f.color ?? 0x2d3750);
}

function refit() {
  cam.aspect = innerWidth / innerHeight;
  cam.fov = 2 * Math.atan(Math.tan(HFOV / 2) / cam.aspect) * 180 / Math.PI;
  cam.updateProjectionMatrix(); rend.setSize(innerWidth, innerHeight);
}
addEventListener("resize", refit);

// ── drift · walk-through ────────────────────────────────────────────────────────────────────────
let tx = 0, ty = 0, cx = 0, cy = 0;
let playing = false, YAW = 0, PITCH = 0;
const keys = new Set();
const kk = k => keys.has(k) ? 1 : 0;

addEventListener("mousemove", e => {
  if (playing) {
    if (document.pointerLockElement !== rend.domElement) return;
    // Yaw is UNLIMITED in walk mode -- turn as far as you like, either way, forever. No 3D
    // walkthrough caps how far you can spin, and `cam.yaw` was only ever meant to bound the
    // look-around from a fixed viewpoint. A scene has to ask for a limit now (cam.yawLimit).
    YAW -= e.movementX * 0.0022;
    if (S.cam.yawLimit > 0) {
      const ly = S.cam.yawLimit * Math.PI / 180;
      YAW = clamp(YAW, -ly, ly);
    }
    // Pitch still clamps, or you tumble over the top.
    const lp = Math.min(S.cam.pitch ?? 85, 85) * Math.PI / 180;
    PITCH = clamp(PITCH - e.movementY * 0.0022, -lp, lp);
  } else {
    tx = (e.clientX / innerWidth - 0.5) * 2;
    ty = -(e.clientY / innerHeight - 0.5) * 2;
  }
});
function setPlay(p) {
  playing = p;
  if (p) { YAW = 0; PITCH = 0; rend.domElement.requestPointerLock?.(); }
  else { document.exitPointerLock?.(); cam.rotation.set(0, 0, 0); }
}
rend.domElement.addEventListener("click", () => { if (playing) rend.domElement.requestPointerLock?.(); });
addEventListener("keydown", e => {
  const k = e.key.toLowerCase();
  if (k === "p") { setPlay(!playing); e.preventDefault(); return; }
  if (k === "escape" && playing) { setPlay(false); e.preventDefault(); return; }
  if (playing) { keys.add(k); e.preventDefault(); }
});
addEventListener("keyup", e => keys.delete(e.key.toLowerCase()));

// Keeping the walker ON the path is not a nicety -- it is what makes occlusion tractable. Free
// roaming means the subject can be viewed from any distance and any angle, so no amount of scenery
// reliably hides it. Pinned to a corridor of known radius, a tree of known size covers a known
// angle, and the imposter's swap can be relied on.
function confine(x, z) {
  const r = S.cam?.ring;
  if (!r) return [x, z];
  const dx = x - r.x, dz = z - r.z;
  const d = Math.hypot(dx, dz) || 1e-6;
  const lo = r.r - r.w / 2, hi = r.r + r.w / 2;
  const k = d < lo ? lo / d : d > hi ? hi / d : 1;
  return k === 1 ? [x, z] : [r.x + dx * k, r.z + dz * k];
}

const WALK = 2.4, RISE = 1.2;
let last = performance.now();
function step(now) {
  requestAnimationFrame(step);
  const dt = Math.min(0.05, (now - last) / 1000); last = now; const t = now / 1000;
  if (playing) {
    const f = (kk("w") + kk("arrowup")) - (kk("s") + kk("arrowdown"));
    const s = (kk("d") + kk("arrowright")) - (kk("a") + kk("arrowleft"));
    const u = kk("r") - kk("f");
    const sp = kk("shift") ? 0.35 : 1;
    const sn = Math.sin(YAW), cs = Math.cos(YAW);
    let x = cam.position.x + (-f * sn + s * cs) * WALK * sp * dt;
    let z = cam.position.z + (-f * cs - s * sn) * WALK * sp * dt;
    const y = cam.position.y + u * RISE * sp * dt;
    [x, z] = confine(x, z);
    cam.position.set(clamp(x, -S.cam.x, S.cam.x), clamp(y, -S.cam.y, S.cam.y), clamp(z, -S.cam.z, S.cam.z));
    cam.rotation.set(PITCH, YAW, sway ? Math.sin(t * 0.37) * 0.005 : 0);
  } else {
    cx += (clamp(tx, -1, 1) * DX - cx) * Math.min(1, dt * 3.2);
    cy += (clamp(ty, -1, 1) * DY - cy) * Math.min(1, dt * 3.2);
    const swayX = sway ? Math.sin(t * 0.55) * 0.06 + Math.sin(t * 0.23) * 0.035 : 0;
    const swayY = sway ? Math.sin(t * 0.41 + 1.3) * 0.03 : 0;
    cam.position.set(cx + swayX, cy + swayY, 0);
    cam.rotation.z = sway ? Math.sin(t * 0.37) * 0.005 : 0;
    cam.lookAt(0, 0, -15);
  }
  faceCamera();
  stepImposters(cam);
  rend.render(scene, cam);
}

// ── load the scene, then run ──────────────────────────────────────────────────────────────────────
function fail(msg) { const m = document.getElementById("msg"); m.textContent = msg; m.style.display = "grid"; }
fetch("/diorama/scenes/" + encodeURIComponent(sceneName))
  .then(r => r.ok ? r.json() : Promise.reject(r.status))
  .then(j => {
    S = Object.assign(S, j);
    S.cam = Object.assign({ x: 1.2, y: 0.35, z: 1.5, yaw: 22, pitch: 10 }, j.cam || {});
    S.layers = j.layers || [];
    HFOV = (S.lens || 62) * Math.PI / 180;
    DX = clamp(S.cam.x, 0.1, 1.2); DY = clamp(S.cam.y, 0.05, 0.6);
    sway = S.meta?.ambientSway !== false;                 // on unless the scene opts out
    applyFog(S.meta?.fog);
    document.title = "Diorama — " + (S.name || sceneName);
    build(); refit(); requestAnimationFrame(step);
  })
  .catch(() => fail(sceneName ? `scene “${sceneName}” not found` : "no scene specified"));
