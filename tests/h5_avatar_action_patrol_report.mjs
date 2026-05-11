import fs from "node:fs";
import path from "node:path";

const matrixPath = path.resolve(process.argv[2] || process.env.PSW_H5_SEMANTIC_MATRIX || "");
if (!matrixPath || !fs.existsSync(matrixPath)) {
  throw new Error(`Missing H5 matrix: ${matrixPath || "(unset)"}`);
}

const artifactDir = path.dirname(matrixPath);
const rows = JSON.parse(fs.readFileSync(matrixPath, "utf8"))
  .filter((row) => row.group === "avatar_actions" || row.name.includes("-avatar-action-"));
const failures = [];

for (const row of rows) {
  if (row.remoteAvatar) {
    verifyRemoteRow(row);
  } else {
    verifyLocalRow(row);
  }
  if (row.messages?.length > 0) {
    failures.push(`${row.name}: console messages ${row.messages.join("; ")}`);
  }
}
if (rows.length === 0) {
  failures.push("No avatar action patrol screenshots found");
}
if (failures.length > 0) {
  for (const failure of failures) {
    console.error(failure);
  }
  process.exit(1);
}

const summaryPath = path.join(artifactDir, "avatar-action-patrol-summary.json");
const htmlPath = path.join(artifactDir, "avatar-action-patrol-report.html");
fs.writeFileSync(summaryPath, JSON.stringify({
  checked: rows.length,
  rows: rows.map(summaryRow),
}, null, 2));
fs.writeFileSync(htmlPath, renderHtml(rows));
console.log(`avatar action patrol report: ${htmlPath}`);

function verifyLocalRow(row) {
  const state = row.debugState?.avatarVariant || {};
  if (!state.ok) {
    failures.push(`${row.name}: local avatar debug did not complete`);
    return;
  }
  if (state.variant !== row.characterVariant) {
    failures.push(`${row.name}: expected variant ${row.characterVariant}, got ${state.variant || "(none)"}`);
  }
  if (state.action !== row.avatarAction) {
    failures.push(`${row.name}: expected action ${row.avatarAction}, got ${state.action || "(none)"}`);
  }
  if (state.facing !== row.avatarFacing) {
    failures.push(`${row.name}: expected facing ${row.avatarFacing}, got ${state.facing || "(none)"}`);
  }
  const expectedPrefix = row.avatarAction === "emote" ? "idle" : row.avatarAction;
  if (!String(state.animation || "").startsWith(`${expectedPrefix}_`)) {
    failures.push(`${row.name}: animation did not use ${expectedPrefix}: ${state.animation || "(none)"}`);
  }
  if (row.avatarAction === "walk") {
    verifyWalk(row, state);
  }
  if (row.avatarAction === "emote") {
    if (!state.emote_visible) {
      failures.push(`${row.name}: local overhead emote was not visible`);
    }
    if (!String(state.emote_texture || "").includes("overhead_emotes")) {
      failures.push(`${row.name}: local overhead emote did not use the generated emote sheet`);
    }
  }
  if (state.facing === "right" && state.flip_h !== true) {
    failures.push(`${row.name}: right-facing side frame was not mirrored`);
  }
  if (state.facing === "left" && state.flip_h !== false) {
    failures.push(`${row.name}: left-facing side frame was mirrored backwards`);
  }
}

function verifyWalk(row, state) {
  const delta = state.movement_delta || {};
  const dx = Number(delta.x || 0);
  const dy = Number(delta.y || 0);
  if (Number(state.moved_pixels || 0) < 10) {
    failures.push(`${row.name}: walk did not move enough pixels (${state.moved_pixels || 0})`);
  }
  if (row.avatarFacing === "right" && dx <= 8) {
    failures.push(`${row.name}: right walk did not move right (dx=${dx.toFixed(1)})`);
  }
  if (row.avatarFacing === "left" && dx >= -8) {
    failures.push(`${row.name}: left walk did not move left (dx=${dx.toFixed(1)})`);
  }
  if (row.avatarFacing === "down" && dy <= 8) {
    failures.push(`${row.name}: down walk did not move down (dy=${dy.toFixed(1)})`);
  }
  if (row.avatarFacing === "up" && dy >= -8) {
    failures.push(`${row.name}: up walk did not move up (dy=${dy.toFixed(1)})`);
  }
}

function verifyRemoteRow(row) {
  const state = row.debugState?.remoteAvatars || {};
  if (!state.ok) {
    failures.push(`${row.name}: remote avatar debug did not complete`);
    return;
  }
  if (Number(state.count || 0) < 2) {
    failures.push(`${row.name}: expected 2 remote avatars, got ${state.count || 0}`);
  }
  if (Number(state.emote_visible_count || 0) < 2) {
    failures.push(`${row.name}: remote overhead emotes were not visible`);
  }
  if (Number(state.names_visible_count || 0) !== 0) {
    failures.push(`${row.name}: remote names should stay hidden until clicked`);
  }
  const variants = new Set((state.entries || []).map((entry) => entry.variant));
  for (const expected of ["female_magic_v0", "male_ranged_v0"]) {
    if (!variants.has(expected)) {
      failures.push(`${row.name}: missing remote variant ${expected}`);
    }
  }
  for (const entry of state.entries || []) {
    if (!String(entry.texture || "").includes("player_")) {
      failures.push(`${row.name}: remote ${entry.variant || "(unknown)"} did not load a player action sheet`);
    }
    if (!entry.emote_visible || !String(entry.emote_texture || "").includes("overhead_emotes")) {
      failures.push(`${row.name}: remote ${entry.variant || "(unknown)"} emote is not backed by the generated emote sheet`);
    }
  }
}

function summaryRow(row) {
  if (row.remoteAvatar) {
    return {
      name: row.name,
      remote: row.debugState.remoteAvatars,
      screenshot: row.screenshot,
    };
  }
  return {
    name: row.name,
    variant: row.characterVariant,
    action: row.avatarAction,
    facing: row.avatarFacing,
    debug: row.debugState.avatarVariant,
    screenshot: row.screenshot,
  };
}

function renderHtml(rows) {
  const cards = rows.map((row) => {
    const rel = path.relative(artifactDir, row.screenshot).split(path.sep).join("/");
    const state = row.remoteAvatar ? row.debugState.remoteAvatars : row.debugState.avatarVariant;
    const subtitle = row.remoteAvatar
      ? `remote sync / ${state.count} players / emotes ${state.emote_visible_count}`
      : `${state.variant} / ${state.action} / ${state.facing} / ${state.animation}`;
    return `<article>
      <header>
        <h2>${escapeHtml(row.name)}</h2>
        <p>${escapeHtml(subtitle)}</p>
      </header>
      <a href="${escapeAttr(rel)}"><img src="${escapeAttr(rel)}" alt="${escapeAttr(row.name)}"></a>
      <pre>${escapeHtml(JSON.stringify(state, null, 2))}</pre>
    </article>`;
  }).join("\n");
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Avatar Action Patrol</title>
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
    pre { white-space: pre-wrap; overflow-wrap: anywhere; font-size: 12px; color: #8fa6bd; }
  </style>
</head>
<body>
  <main>
    <h1>Avatar Action Patrol</h1>
    <p class="summary">${rows.length} screenshots covering four-direction walking, overhead emotes, and remote avatar sync.</p>
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
