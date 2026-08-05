// Shadowbox — P0 scaffold. Proves the render path end-to-end inside mj: vendored three.js (ESM),
// a perspective camera that only DRIFTS, and a few placeholder planes at different depths so the
// parallax reads. The real editor (palette from mj libraries, drag/scale/depth, scenes) is P2+.
import * as THREE from "/vendor/three.module.js";

const revEl = document.getElementById("sb-rev");
if (revEl) revEl.textContent = THREE.REVISION;

const stage = document.getElementById("sb-stage");
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x07060a);
const box = new THREE.Group();
scene.add(box);

let HFOV = 62 * Math.PI / 180; // framed, shadow-box lens
const cam = new THREE.PerspectiveCamera(50, 1, 0.05, 200);

const rend = new THREE.WebGLRenderer({ antialias: true });
rend.setPixelRatio(Math.min(devicePixelRatio, 2));
stage.appendChild(rend.domElement);

// Placeholder layers: {z, w, h, color}. A far backdrop and two nearer "props".
function plane(z, w, h, color) {
  const m = new THREE.Mesh(
    new THREE.PlaneGeometry(w, h),
    new THREE.MeshBasicMaterial({ color })
  );
  m.position.z = z;
  box.add(m);
  return m;
}
plane(-15, 40, 24, 0x1b2a3a); // FAR backdrop
plane(-8, 6, 8, 0x8a5a2a);    // MID
plane(-8, 6, 8, 0x8a5a2a).position.x = 4;
plane(-3.5, 2.5, 6, 0x6a8a4a); // NEAR
box.children[box.children.length - 1].position.x = -5;

function resize() {
  const w = stage.clientWidth, h = stage.clientHeight;
  cam.aspect = w / h;
  cam.fov = 2 * Math.atan(Math.tan(HFOV / 2) / cam.aspect) * 180 / Math.PI;
  cam.updateProjectionMatrix();
  rend.setSize(w, h);
}
addEventListener("resize", resize);

// Drift: the camera eases toward a small target set by the mouse; the layers parallax against it.
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
