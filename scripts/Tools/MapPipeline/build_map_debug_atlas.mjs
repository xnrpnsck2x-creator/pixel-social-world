#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const DEFAULT_OUT = path.join(ROOT, ".tools", "map-debug-atlas-v1");
const outDir = path.resolve(process.argv[2] || process.env.PSW_MAP_DEBUG_ATLAS_DIR || DEFAULT_OUT);

const catalog = loadJson(path.join(ROOT, "configs", "map_catalog.json"));
const pointConfig = loadJson(path.join(ROOT, "configs", "map_points.json"));
const pointMaps = pointConfig.maps || {};
const records = (catalog.maps || []).filter(isPatrolMap);
const rows = records.map((record) => mapRow(record));
const failures = rows.flatMap((row) => row.failures);

if (failures.length > 0) {
  for (const failure of failures) {
    console.error(failure);
  }
  process.exit(1);
}

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, "summary.json"), JSON.stringify(summary(rows), null, 2));
fs.writeFileSync(path.join(outDir, "index.html"), renderHtml(rows));
console.log(`map debug atlas: ${path.join(outDir, "index.html")}`);

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function isPatrolMap(record) {
  return Boolean(record?.id && record?.asset_path && record?.metadata_path);
}

function mapRow(record) {
  const points = pointMaps[record.id] || {};
  const canvas = points.canvas_size || [];
  const assetPath = resourceToPath(record.asset_path);
  const failures = [];
  const warnings = [];
  if (!fs.existsSync(assetPath)) {
    failures.push(`${record.id}: missing map asset ${record.asset_path}`);
  }
  if (canvas.length !== 2 || Number(canvas[0]) <= 0 || Number(canvas[1]) <= 0) {
    failures.push(`${record.id}: missing valid canvas_size`);
  }
  if ((points.walkable_rects || []).length === 0) {
    warnings.push("no walkable rects");
  }
  if ((points.blocked_rects || []).length === 0) {
    warnings.push("no blocked rects");
  }
  return {
    id: record.id,
    title: localizedName(record, record.id),
    category: record.category || "uncategorized",
    assetPath,
    assetRelative: slash(path.relative(outDir, assetPath)),
    width: Number(canvas[0] || 1),
    height: Number(canvas[1] || 1),
    points,
    density: densityFor(points),
    failures,
    warnings,
  };
}

function resourceToPath(resourcePath) {
  const normalized = String(resourcePath || "").replace(/^res:\/\//, "");
  return path.join(ROOT, normalized);
}

function localizedName(record, fallback) {
  return record?.name?.en || record?.name?.zh || record?.name?.ja || fallback;
}

function densityFor(points = {}) {
  return {
    spawn: count(points.spawn_points),
    npc: count(points.npc_points),
    life: count(points.life_skill_nodes),
    portal: count(points.portals),
    interaction: count(points.interaction_points),
    walkable: count(points.walkable_rects),
    blocked: count(points.blocked_rects),
  };
}

function count(value) {
  return Array.isArray(value) ? value.length : 0;
}

function summary(rows) {
  return {
    maps: rows.length,
    failures: 0,
    warnings: rows.reduce((total, row) => total + row.warnings.length, 0),
    totals: rows.reduce((totals, row) => {
      for (const [key, value] of Object.entries(row.density)) {
        totals[key] = (totals[key] || 0) + value;
      }
      return totals;
    }, {}),
    map_rows: rows.map((row) => ({
      id: row.id,
      category: row.category,
      density: row.density,
      warnings: row.warnings,
    })),
  };
}

function renderHtml(rows) {
  const cards = rows
    .sort((a, b) => a.category.localeCompare(b.category) || a.id.localeCompare(b.id))
    .map(renderCard)
    .join("\n");
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Map Debug Atlas</title>
  <style>
    body { margin: 0; background: #10141b; color: #eee7d4; font: 13px/1.4 system-ui, sans-serif; }
    main { max-width: 1480px; margin: 0 auto; padding: 20px; }
    h1 { margin: 0 0 6px; font-size: 24px; }
    .summary { margin: 0 0 18px; color: #bfb49b; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(410px, 1fr)); gap: 14px; }
    .card { border: 1px solid #3b3328; background: #181d24; border-radius: 8px; padding: 10px; }
    .card.warn { border-color: #b98536; }
    header { display: flex; justify-content: space-between; gap: 10px; margin-bottom: 8px; }
    h2 { margin: 0; font-size: 16px; }
    p { margin: 0; }
    header p, .counts, figcaption { color: #a79e86; font-size: 12px; }
    .stage { position: relative; display: block; background: #05070a; border: 1px solid #2d3440; border-radius: 5px; overflow: hidden; }
    img { display: block; width: 100%; height: auto; }
    svg { position: absolute; inset: 0; width: 100%; height: 100%; pointer-events: none; }
    .walkable { fill: rgba(109, 229, 128, .08); stroke: rgba(127, 229, 139, .70); stroke-width: 4; }
    .blocked { fill: rgba(255, 100, 80, .14); stroke: rgba(255, 141, 107, .90); stroke-width: 4; }
    .spawn { fill: #fff; stroke: #10141b; stroke-width: 5; }
    .npc { fill: #ffcc4d; stroke: #10141b; stroke-width: 5; }
    .npc-facing { stroke: #ffcc4d; stroke-width: 8; stroke-linecap: round; filter: drop-shadow(0 0 2px #10141b); }
    .life { fill: #7cff9c; stroke: #10141b; stroke-width: 5; }
    .portal { fill: #c58cff; stroke: #10141b; stroke-width: 5; }
    .interaction { fill: #6dd5ff; stroke: #10141b; stroke-width: 5; }
    .label { fill: #fff7d4; paint-order: stroke; stroke: #10141b; stroke-width: 7; font-size: 34px; font-weight: 700; }
    .legend { display: flex; flex-wrap: wrap; gap: 8px; margin: 7px 0 0; color: #928873; font-size: 11px; }
    .legend span::before { content: ""; display: inline-block; width: 8px; height: 8px; margin-right: 4px; vertical-align: -1px; background: currentColor; }
    .legend .npc { color: #ffcc4d; }
    .legend .life { color: #7cff9c; }
    .legend .portal { color: #c58cff; }
    .legend .interaction { color: #6dd5ff; }
    .legend .blocked { color: #ff8d6b; }
    .legend .walkable { color: #7fe58b; }
    .warn-note { margin-top: 6px; color: #ffcd6b; }
  </style>
</head>
<body>
  <main>
    <h1>Map Debug Atlas</h1>
    <p class="summary">${rows.length} generated maps with full-canvas collision and interaction overlays. Use this to check route shape, NPC grounding, blocked art, and hotspot placement before H5/device runs.</p>
    <section class="grid">${cards}</section>
  </main>
</body>
</html>
`;
}

function renderCard(row) {
  const warning = row.warnings.length > 0 ? `<p class="warn-note">${escapeHtml(row.warnings.join("; "))}</p>` : "";
  return `<article class="card ${row.warnings.length > 0 ? "warn" : ""}">
    <header>
      <div>
        <h2>${escapeHtml(row.title)}</h2>
        <p>${escapeHtml(row.category)} / ${escapeHtml(row.id)}</p>
      </div>
      <p class="counts">NPC ${row.density.npc} · Life ${row.density.life} · Hotspot ${row.density.interaction}</p>
    </header>
    <figure>
      <a class="stage" href="${escapeAttr(row.assetRelative)}">
        <img src="${escapeAttr(row.assetRelative)}" alt="${escapeAttr(row.id)}">
        <svg viewBox="0 0 ${row.width} ${row.height}" role="img" aria-label="${escapeAttr(row.id)} debug overlay">
          ${renderRects(row.points.walkable_rects, "walkable")}
          ${renderRects(row.points.blocked_rects, "blocked")}
          ${renderPoints(row.points.spawn_points, "spawn", "S")}
          ${renderNpcPoints(row.points.npc_points)}
          ${renderPoints(row.points.life_skill_nodes, "life", "L")}
          ${renderPoints(row.points.portals, "portal", "P")}
          ${renderPoints(row.points.interaction_points, "interaction", "I")}
        </svg>
      </a>
      <figcaption>${row.width}x${row.height} · walkable ${row.density.walkable} · blocked ${row.density.blocked}</figcaption>
    </figure>
    ${renderLegend()}
    ${warning}
  </article>`;
}

function renderRects(rects = [], className) {
  return rects.map((rect) => {
    return `<rect class="${className}" x="${num(rect.x)}" y="${num(rect.y)}" width="${num(rect.width)}" height="${num(rect.height)}"><title>${escapeHtml(rect.id || className)}</title></rect>`;
  }).join("");
}

function renderPoints(points = [], className, label) {
  return points.map((point) => {
    const x = num(point.x);
    const y = num(point.y);
    return `<g><circle class="${className}" cx="${x}" cy="${y}" r="18"><title>${escapeHtml(point.id || className)}</title></circle><text class="label" x="${x}" y="${Number(y) - 26}" text-anchor="middle">${label}</text></g>`;
  }).join("");
}

function renderNpcPoints(points = []) {
  return points.map((point) => {
    const x = Number(num(point.x));
    const y = Number(num(point.y));
    const vector = facingVector(point.facing || "down");
    const endX = (x + vector.x * 42).toFixed(1);
    const endY = (y + vector.y * 42).toFixed(1);
    return `<g><line class="npc-facing" x1="${x}" y1="${y}" x2="${endX}" y2="${endY}"></line><circle class="npc" cx="${x}" cy="${y}" r="18"><title>${escapeHtml(point.id || "npc")} / ${escapeHtml(point.facing || "down")}</title></circle><text class="label" x="${x}" y="${(y - 26).toFixed(1)}" text-anchor="middle">N</text></g>`;
  }).join("");
}

function facingVector(facing) {
  switch (facing) {
    case "left":
      return { x: -1, y: 0 };
    case "right":
      return { x: 1, y: 0 };
    case "up":
      return { x: 0, y: -1 };
    default:
      return { x: 0, y: 1 };
  }
}

function renderLegend() {
  return `<p class="legend"><span class="npc">NPC</span><span class="life">Life</span><span class="portal">Portal</span><span class="interaction">Interaction</span><span class="blocked">Blocked</span><span class="walkable">Walkable</span></p>`;
}

function num(value) {
  return Number(value || 0).toFixed(1);
}

function slash(value) {
  return value.split(path.sep).join("/");
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  }[char]));
}

function escapeAttr(value) {
  return escapeHtml(value);
}
