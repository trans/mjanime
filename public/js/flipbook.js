// Flipbook: browse the frames, mark the unusable ones, line some up and play them.
// What's decided is posted to /flipbook/state and kept in the Outtake's flipbook.json.
(() => {
  const $ = id => document.getElementById(id);
  // v is the frame's file time, so a frame that's been redrawn isn't shown from the browser's cache
  const img = (n, size) => `/flipbook/img/${n}/${size}?v=${(byN[n] || {}).v || 0}`;
  let frames = [], byN = {}, unusable = new Set(), notes = {}, sequences = {};
  let sel = null, seq = [], cur = -1, timer = null, vecs = {};

  async function load() {
    const r = await (await fetch("/flipbook/frames.json")).json();
    frames = r.frames;
    byN = Object.fromEntries(frames.map(f => [f.n, f]));
    unusable = new Set(r.unusable || []);
    notes = r.notes || {};
    sequences = r.sequences || {};
    fillLoad();
    render();
  }

  function save(what) {
    const body = { unusable: [...unusable].sort(), notes, sequences };
    fetch("/flipbook/state", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) })
      .then(() => { $("saved").textContent = `saved ${what}`; setTimeout(() => $("saved").textContent = "", 1500); });
  }

  function visible() {
    const words = $("filter").value.toLowerCase().split(/\s+/).filter(Boolean);
    return frames.filter(f => words.every(w => f.path.toLowerCase().includes(w)) &&
                              !($("hideBad").checked && unusable.has(f.path)));
  }

  function card(f, small) {
    const c = document.createElement("div");
    c.className = "card" + (unusable.has(f.path) ? " bad" : "") + (sel === f.n ? " sel" : "");
    c.title = `#${f.n} ${f.path}` + (notes[f.path] ? `\n${notes[f.path]}` : "");
    const i = new Image();
    i.src = img(f.n, "thumb");
    i.onload = () => vector(f.n, i);
    c.append(i);
    const num = document.createElement("span");
    num.className = "num"; num.textContent = f.n;
    c.append(num);
    c.onclick = () => select(f.n);
    c.ondblclick = () => add(f.n);
    return c;
  }

  function render() {
    const lib = $("lib");
    lib.innerHTML = "";
    const vis = visible();
    $("count").textContent = `${vis.length} of ${frames.length} frames`;
    let group = null, grid = null;
    for (const f of vis) {
      if (f.group !== group) {
        group = f.group;
        const h = document.createElement("h4"); h.textContent = group; lib.append(h);
        grid = document.createElement("div"); grid.className = "grid"; lib.append(grid);
      }
      grid.append(card(f));
    }
  }

  // a small picture of each thumbnail, to find the frames that look most alike
  function vector(n, i) {
    if (vecs[n]) return;
    const c = document.createElement("canvas");
    c.width = 20; c.height = 30;
    const g = c.getContext("2d");
    g.drawImage(i, 0, 0, 20, 30);
    vecs[n] = g.getImageData(0, 0, 20, 30).data;
    if (n === sel) near();
  }

  function distance(a, b) {
    let d = 0;
    for (let k = 0; k < a.length; k += 4) {
      const wa = a[k + 3] / 255, wb = b[k + 3] / 255;
      d += Math.abs(a[k] * wa - b[k] * wb) + Math.abs(a[k + 1] * wa - b[k + 1] * wb) +
           Math.abs(a[k + 2] * wa - b[k + 2] * wb) + Math.abs(a[k + 3] - b[k + 3]);
    }
    return d;
  }

  function near() {
    const box = $("near");
    box.innerHTML = "";
    const v = vecs[sel];
    if (!v) return;
    const rows = visible().filter(f => f.n !== sel && vecs[f.n] && !unusable.has(f.path))
      .map(f => [distance(v, vecs[f.n]), f]).sort((a, b) => a[0] - b[0]).slice(0, 12);
    for (const [, f] of rows) box.append(card(f, true));
  }

  function select(n) {
    sel = n;
    const f = byN[n];
    $("stage").src = img(n, "view");
    $("onion").removeAttribute("src");
    $("info").textContent = `#${n}  ${f.path}` + (unusable.has(f.path) ? "  (unusable)" : "");
    $("note").value = notes[f.path] || "";
    $("badBtn").textContent = unusable.has(f.path) ? "mark usable (X)" : "mark unusable (X)";
    document.querySelectorAll(".card").forEach(c => c.classList.toggle("sel", c.querySelector(".num")?.textContent == n));
    near();
  }

  function toggleBad() {
    if (sel == null) return;
    const p = byN[sel].path;
    unusable.has(p) ? unusable.delete(p) : unusable.add(p);
    save("marks");
    render(); select(sel);
  }

  // -- the sequence --
  function add(n) { seq.push({ n, hold: null }); drawSeq(); }

  function drawSeq() {
    const box = $("seq");
    box.innerHTML = "";
    seq.forEach((it, i) => {
      const d = document.createElement("div");
      d.className = "item" + (i === cur ? " cur" : "");
      d.draggable = true;
      const im = new Image(); im.src = img(it.n, "thumb"); d.append(im);
      const lab = document.createElement("div"); lab.textContent = `#${it.n}`; d.append(lab);
      const h = document.createElement("input");
      h.type = "number"; h.placeholder = $("hold").value; h.value = it.hold ?? ""; h.title = "hold, ms (blank: the default)";
      h.onchange = () => { it.hold = h.value ? parseInt(h.value) : null; };
      d.append(h);
      const x = document.createElement("button"); x.textContent = "✕"; x.title = "remove";
      x.onclick = e => { e.stopPropagation(); seq.splice(i, 1); drawSeq(); };
      d.append(x);
      d.onclick = () => { stop(); show(i); };
      d.ondragstart = e => { e.dataTransfer.setData("text/plain", i); d.classList.add("drag"); };
      d.ondragend = () => d.classList.remove("drag");
      d.ondragover = e => e.preventDefault();
      d.ondrop = e => {
        e.preventDefault();
        const from = parseInt(e.dataTransfer.getData("text/plain"));
        const [moved] = seq.splice(from, 1);
        seq.splice(i, 0, moved);
        drawSeq();
      };
      box.append(d);
    });
  }

  function show(i) {
    cur = i;
    const it = seq[i];
    $("stage").src = img(it.n, "view");
    const prev = seq[i - 1];
    if (prev && $("onionOn").checked && !timer) $("onion").src = img(prev.n, "view");
    else $("onion").removeAttribute("src");
    $("info").textContent = `step ${i + 1} of ${seq.length}: #${it.n}  ${byN[it.n]?.path || ""}`;
    document.querySelectorAll("#seq .item").forEach((d, k) => d.classList.toggle("cur", k === i));
  }

  function play() {
    if (!seq.length) return;
    stop();
    // preload so a step never waits on the network
    seq.forEach(it => { new Image().src = img(it.n, "view"); });
    let i = cur >= 0 && cur < seq.length - 1 ? cur : -1;
    const step = () => {
      i += 1;
      if (i >= seq.length) {
        if (!$("loop").checked) { stop(); return; }
        i = 0;
      }
      show(i);
      timer = setTimeout(step, seq[i].hold || parseInt($("hold").value) || 400);
    };
    timer = 1; // marks playing for show(), so the onion stays off
    step();
  }

  function stop() { if (timer && timer !== 1) clearTimeout(timer); timer = null; }

  // -- saved sequences --
  function fillLoad() {
    const s = $("load");
    s.innerHTML = '<option value="">load a sequence…</option>';
    for (const name of Object.keys(sequences).sort()) {
      const o = document.createElement("option"); o.value = name; o.textContent = `${name} (${sequences[name].length})`; s.append(o);
    }
  }

  $("save").onclick = () => {
    const name = $("seqName").value.trim();
    if (!name || !seq.length) return;
    sequences[name] = seq.map(it => ({ n: it.n, path: byN[it.n].path, hold: it.hold || parseInt($("hold").value) }));
    fillLoad(); save(`"${name}"`);
  };
  $("load").onchange = () => {
    const name = $("load").value;
    if (!name) return;
    stop();
    seq = sequences[name].map(it => ({ n: frames.find(f => f.path === it.path)?.n ?? it.n, hold: it.hold }));
    $("seqName").value = name; cur = -1; drawSeq();
  };
  $("del").onclick = () => {
    const name = $("seqName").value.trim();
    if (!sequences[name]) return;
    delete sequences[name]; fillLoad(); save(`(deleted "${name}")`);
  };
  $("clear").onclick = () => { stop(); seq = []; cur = -1; drawSeq(); };
  $("play").onclick = play;
  $("stop").onclick = stop;
  $("badBtn").onclick = toggleBad;
  $("addBtn").onclick = () => sel != null && add(sel);
  $("note").onchange = () => {
    if (sel == null) return;
    const p = byN[sel].path, v = $("note").value.trim();
    if (v) notes[p] = v; else delete notes[p];
    save("note");
  };
  $("filter").oninput = render;
  $("hideBad").onchange = render;
  document.addEventListener("keydown", e => {
    if (e.target.tagName === "INPUT" || e.target.tagName === "SELECT") return;
    if (e.key === "x" || e.key === "X") toggleBad();
    else if (e.key === "a" || e.key === "A") { if (sel != null) add(sel); }
    else if (e.key === " ") { e.preventDefault(); timer ? stop() : play(); }
    else if (e.key === "ArrowRight" && seq.length) { stop(); show(Math.min(cur + 1, seq.length - 1)); }
    else if (e.key === "ArrowLeft" && seq.length) { stop(); show(Math.max(cur - 1, 0)); }
  });
  load();
})();
