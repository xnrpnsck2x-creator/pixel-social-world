import fs from "node:fs";
import path from "node:path";

const matrixPath = path.resolve(process.argv[2] || process.env.PSW_H5_SEMANTIC_MATRIX || "");
if (!matrixPath || !fs.existsSync(matrixPath)) {
  throw new Error(`Missing H5 matrix: ${matrixPath || "(unset)"}`);
}

const artifactDir = path.dirname(matrixPath);
const rows = JSON.parse(fs.readFileSync(matrixPath, "utf8"))
  .filter((row) => row.group === "avatar_variants" || row.name.includes("-avatar-variant-"));
const failures = [];

for (const row of rows) {
  const state = row.debugState?.avatarVariant || {};
  if (!state.ok) {
    failures.push(`${row.name}: avatar variant debug did not complete`);
    continue;
  }
  if (state.variant !== row.characterVariant) {
    failures.push(`${row.name}: expected variant ${row.characterVariant}, got ${state.variant || "(none)"}`);
  }
  if (state.action !== row.avatarAction) {
    failures.push(`${row.name}: expected action ${row.avatarAction}, got ${state.action || "(none)"}`);
  }
  if (!String(state.animation || "").startsWith(`${row.avatarAction}_`)) {
    failures.push(`${row.name}: animation did not use ${row.avatarAction}: ${state.animation || "(none)"}`);
  }
  const expectedSheet = `player_${String(state.avatar || "").replace("_v1", "")}_actions_v1`;
  if (!String(state.texture || "").includes(expectedSheet)) {
    failures.push(`${row.name}: texture does not match ${expectedSheet}: ${state.texture || "(none)"}`);
  }
  if (row.avatarAction === "attack" && !state.attack_feedback) {
    failures.push(`${row.name}: attack feedback trace was not spawned`);
  }
  if (state.facing === "right" && state.flip_h !== true) {
    failures.push(`${row.name}: right-facing side frame was not mirrored`);
  }
  if (row.messages?.length > 0) {
    failures.push(`${row.name}: console messages ${row.messages.join("; ")}`);
  }
}
if (rows.length === 0) {
  failures.push("No avatar variant patrol screenshots found");
}
if (failures.length > 0) {
  for (const failure of failures) {
    console.error(failure);
  }
  process.exit(1);
}

const summaryPath = path.join(artifactDir, "avatar-variant-patrol-summary.json");
const htmlPath = path.join(artifactDir, "avatar-variant-patrol-report.html");
fs.writeFileSync(summaryPath, JSON.stringify({
  checked: rows.length,
  rows: rows.map((row) => ({
    name: row.name,
    variant: row.characterVariant,
    avatar: row.debugState.avatarVariant.avatar,
    action: row.debugState.avatarVariant.action,
    animation: row.debugState.avatarVariant.animation,
    texture: row.debugState.avatarVariant.texture,
    screenshot: row.screenshot,
  })),
}, null, 2));
fs.writeFileSync(htmlPath, renderHtml(rows));
console.log(`avatar variant patrol report: ${htmlPath}`);

function renderHtml(rows) {
  const cards = rows.map((row) => {
    const state = row.debugState.avatarVariant;
    const rel = path.relative(artifactDir, row.screenshot).split(path.sep).join("/");
    return `<article>
      <header>
        <h2>${escapeHtml(row.name)}</h2>
        <p>${escapeHtml(state.gender)} / ${escapeHtml(state.class)} / ${escapeHtml(state.action)} / ${escapeHtml(state.animation)}</p>
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
  <title>Avatar Variant Patrol</title>
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
    <h1>Avatar Variant Patrol</h1>
    <p class="summary">${rows.length} screenshots across desktop and mobile landscape. Each shot forces one formal gender/class avatar variant in the live city scene.</p>
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
