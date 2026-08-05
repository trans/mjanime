// Shadowbox — P1 demo. The stage now pulls REAL assets from mj's libraries via /shadowbox/assets.json
// (props = cut-outs, backdrops = full frames) and renders them as depth-layered planes with camera
// drift. This proves the asset bridge end-to-end. The full editor (palette panel, drag/scale/depth,
// scene save/load) is P2+; here we just auto-place a backdrop and the first few props.
import * as THREE from "/vendor/three.module.js";

const revEl = document.getElementById("sb-rev");
if (revEl) revEl.textContent = THREE.REVISION;

const stage = document.getElementById("sb-stage");
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x07060a);
const box = new THREE.Group();
scene.add(box);

let HFOV = 62 * Math.PI / 180;
const cam = new THREE.PerspectiveCamera(50, 1, 0.05, 200);
const rend = new THREE.WebGLRenderer({ antialias: true });
rend.setPixelRatio(Math.min(devicePixelRatio, 2));
stage.appendChild(rend.domElement);

const loader = new THREE.TextureLoader();
const tex = src => { const t = loader.load(src); t.colorSpace = THREE.SRGBColorSpace; return t; };

function viewSizeAt(dist) { const h = 2 * dist * Math.tan(cam.fov * Math.PI / 360); return { w: h * cam.aspect, h }; }

// A layer sized by a fraction of the view at its depth (so aspect is honoured from the asset's w/h).
const LAYERS = [];
function addLayer(a, z, hFrac, hx, cut) {
  const m = new THREE.Mesh(
    new THREE.PlaneGeometry(1, 1),
    new THREE.MeshBasicMaterial({ map: tex(a.src), transparent: cut, alphaTest: cut ? 0.04 : 0, depthWrite: !cut })
  );
  m.position.z = z;
  box.add(m);
  LAYERS.push({ m, z, iw: a.w, ih: a.h, hFrac, hx, cut });
}
function relayout() {
  for (const L of LAYERS) {
    const v = viewSizeAt(-L.z);
    if (L.cut) {
      const h = v.h * L.hFrac, w = h * L.iw / L.ih;
      L.m.scale.set(w, h, 1); L.m.position.x = v.w * L.hx; L.m.position.y = -v.h * 0.12;
    } else {
      const cover = Math.max(v.w * 1.3 / L.iw, v.h * 1.3 / L.ih);
      L.m.scale.set(L.iw * cover, L.ih * cover, 1);
    }
  }
}

function resize() {
  const w = stage.clientWidth, h = stage.clientHeight;
  cam.aspect = w / h;
  cam.fov = 2 * Math.atan(Math.tan(HFOV / 2) / cam.aspect) * 180 / Math.PI;
  cam.updateProjectionMatrix();
  rend.setSize(w, h);
  relayout();
}
addEventListener("resize", resize);

// Build a demo scene from whatever the libraries currently hold.
fetch("/shadowbox/assets.json").then(r => r.json()).then(assets => {
  const backs = assets.filter(a => !a.cut);
  const props = assets.filter(a => a.cut);
  if (backs.length) addLayer(backs[0], -15, 0, 0, false);          // FAR: first backdrop
  const near = props.slice(0, 4);                                  // a few props across the mid/near band
  near.forEach((p, i) => addLayer(p, -8 + i * 1.3, 0.42, (i / Math.max(1, near.length - 1) - 0.5) * 0.7, true));
  resize();
  const cap = document.getElementById("sb-count");
  if (cap) cap.textContent = `${backs.length} backdrop(s) · ${props.length} prop(s)`;
}).catch(() => { resize(); });

// Drift.
const DX = 0.6, DY = 0.28;
let tx = 0, ty = 0, cx = 0, cy = 0;
stage.addEventListener("mousemove", e => {
  const r = stage.getBoundingClientRect();
  tx = ((e.clientX - r.left) / r.width - 0.5) * 2;
  ty = -((e.clientY - r.top) / r.height - 0.5) * 2;
});
stage.addEventListener("mouseleave", () => { tx = 0; ty = 0; });

let last = performance.now();
function step(now) {
  requestAnimationFrame(step);
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  cx += (clamp(tx, -1, 1) * DX - cx) * Math.min(1, dt * 3.2);
  cy += (clamp(ty, -1, 1) * DY - cy) * Math.min(1, dt * 3.2);
  cam.position.set(cx, cy, 0);
  cam.lookAt(0, 0, -15);
  rend.render(scene, cam);
}
resize();
requestAnimationFrame(step);
