import fs from "node:fs";
import path from "node:path";

const matrixPath = path.resolve(process.argv[2] || process.env.PSW_H5_SEMANTIC_MATRIX || "");
if (!matrixPath || !fs.existsSync(matrixPath)) {
  throw new Error(`Missing H5 matrix: ${matrixPath || "(unset)"}`);
}

const artifactDir = path.dirname(matrixPath);
const rows = JSON.parse(fs.readFileSync(matrixPath, "utf8"))
  .filter((row) => row.group === "npc_ambience" || row.name.includes("-npc-ambience-"));
const failures = [];

for (const row of rows) {
  const state = row.debugState?.npcAmbience || {};
  if (!state.ok) {
    failures.push(`${row.name}: ambience debug did not complete`);
    continue;
  }
  if (state.npc !== row.ambienceNpc) {
    failures.push(`${row.name}: expected NPC ${row.ambienceNpc}, got ${state.npc || "(none)"}`);
  }
  if (!state.pose) {
    failures.push(`${row.name}: missing ambience pose`);
  }
  if (!String(state.texture || "").includes(String(state.pose || ""))) {
    failures.push(`${row.name}: texture does not match pose ${state.pose}: ${state.texture || "(none)"}`);
  }
  if (row.debugState?.map !== row.map) {
    failures.push(`${row.name}: expected map ${row.map}, got ${row.debugState?.map || "(none)"}`);
  }
  if (row.messages?.length > 0) {
    failures.push(`${row.name}: console messages ${row.messages.join("; ")}`);
  }
}
if (rows.length === 0) {
  failures.push("No npc ambience patrol screenshots found");
}
if (failures.length > 0) {
  for (const failure of failures) {
    console.error(failure);
  }
  process.exit(1);
}

const summaryPath = path.join(artifactDir, "npc-ambience-patrol-summary.json");
const htmlPath = path.join(artifactDir, "npc-ambience-patrol-report.html");
fs.writeFileSync(summaryPath, JSON.stringify({
  checked: rows.length,
  rows: rows.map((row) => ({
    name: row.name,
    map: row.map,
    npc: row.ambienceNpc,
    pose: row.debugState.npcAmbience.pose,
    texture: row.debugState.npcAmbience.texture,
    screenshot: row.screenshot,
  })),
}, null, 2));
fs.writeFileSync(htmlPath, renderHtml(rows));
console.log(`npc ambience patrol report: ${htmlPath}`);

function renderHtml(rows) {
  const cards = rows.map((row) => {
    const state = row.debugState.npcAmbience;
    const rel = path.relative(artifactDir, row.screenshot).split(path.sep).join("/");
    return `<article>
      <header>
        <h2>${escapeHtml(row.name)}</h2>
        <p>${escapeHtml(row.map)} / ${escapeHtml(row.ambienceNpc)} / ${escapeHtml(state.pose)}</p>
      </header>
      <a href="${escapeAttr(rel)}"><img src="${escapeAttr(rel)}" alt="${escapeAttr(row.name)}"></a>
      <p class="texture">${escapeHtml(state.texture)}</p>
    </article>`;
  }).join("\n");
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>NPC Ambience Patrol</title>
  <style>
    body { margin: 0; background: #11161d; color: #efe6d2; font: 14px/1.4 system-ui, sans-serif; }
    main { max-width: 1420px; margin: 0 auto; padding: 20px; }
    h1 { margin: 0 0 6px; font-size: 24px; }
    .summary { margin: 0 0 18px; color: #c8b995; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 14px; }
    article { border: 1px solid #3d3326; border-radius: 8px; padding: 10px; background: #1a2028; }
    header { display: flex; flex-direction: column; gap: 2px; margin-bottom: 8px; }
    h2 { margin: 0; font-size: 16px; }
    p { margin: 0; color: #b9ad93; }
    img { display: block; width: 100%; border: 1px solid #2e3845; border-radius: 5px; background: #070a0d; }
    .texture { margin-top: 6px; font-size: 12px; color: #8fa6bd; overflow-wrap: anywhere; }
  </style>
</head>
<body>
  <main>
    <h1>NPC Ambience Patrol</h1>
    <p class="summary">${rows.length} screenshots across desktop and mobile landscape. Each shot forces a configured NPC point action pose for visual review.</p>
    <section class="grid">${cards}</section>
  </main>
</body>
</html>`;
}

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function escapeAttr(value) {
  return escapeHtml(value).replace(/"/g, "&quot;");
}
