// Shadowbox player — a saved scene rendered chrome-less. Ported from siliconcircus index.html (the
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
const cam = new THREE.PerspectiveCamera(50, innerWidth / innerHeight, 0.05, 400);
cam.rotation.order = "YXZ";
const rend = new THREE.WebGLRenderer({ antialias: true });
rend.setPixelRatio(Math.min(devicePixelRatio, 2));
stage.appendChild(rend.domElement);

const loader = new THREE.TextureLoader();
const art = src => { const t = loader.load(src); t.colorSpace = THREE.SRGBColorSpace; return t; };

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

function build() {
  for (const L of S.layers) {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(1, 1),
      new THREE.MeshBasicMaterial({ map: art(L.src), transparent: true, alphaTest: 0.04, depthWrite: false }));
    const h = L.scale, w = h * L.w / L.h;
    m.scale.set(w, h, 1); m.position.set(L.x, L.y, L.z);
    box.add(m);
    if (L.shadow) {
      const sh = new THREE.Mesh(new THREE.PlaneGeometry(1, 1),
        new THREE.MeshBasicMaterial({ map: SHADOW_TEX, transparent: true, depthWrite: false, opacity: 0.85 }));
      sh.scale.set(w * 1.45, h * 0.15, 1); sh.position.set(L.x, L.y - h / 2 + h * 0.015, L.z - 0.02);
      box.add(sh);
    }
  }
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
    YAW = clamp(YAW - e.movementX * 0.0022, -S.cam.yaw * Math.PI / 180, S.cam.yaw * Math.PI / 180);
    PITCH = clamp(PITCH - e.movementY * 0.0022, -S.cam.pitch * Math.PI / 180, S.cam.pitch * Math.PI / 180);
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
    const x = cam.position.x + (-f * sn + s * cs) * WALK * sp * dt;
    const z = cam.position.z + (-f * cs - s * sn) * WALK * sp * dt;
    const y = cam.position.y + u * RISE * sp * dt;
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
  rend.render(scene, cam);
}

// ── load the scene, then run ──────────────────────────────────────────────────────────────────────
function fail(msg) { const m = document.getElementById("msg"); m.textContent = msg; m.style.display = "grid"; }
fetch("/shadowbox/scenes/" + encodeURIComponent(sceneName))
  .then(r => r.ok ? r.json() : Promise.reject(r.status))
  .then(j => {
    S = Object.assign(S, j);
    S.cam = Object.assign({ x: 1.2, y: 0.35, z: 1.5, yaw: 22, pitch: 10 }, j.cam || {});
    S.layers = j.layers || [];
    HFOV = (S.lens || 62) * Math.PI / 180;
    DX = clamp(S.cam.x, 0.1, 1.2); DY = clamp(S.cam.y, 0.05, 0.6);
    sway = S.meta?.ambientSway !== false;                 // on unless the scene opts out
    document.title = "Shadowbox — " + (S.name || sceneName);
    build(); refit(); requestAnimationFrame(step);
  })
  .catch(() => fail(sceneName ? `scene “${sceneName}” not found` : "no scene specified"));
