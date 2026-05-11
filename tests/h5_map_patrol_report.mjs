import fs from "node:fs";
import path from "node:path";

const MIN_DENSITY_SCORE = 8;
const ALLOW_PARTIAL = process.env.PSW_H5_MAP_PATROL_ALLOW_PARTIAL === "1";
const matrixPath = path.resolve(process.argv[2] || process.env.PSW_H5_SEMANTIC_MATRIX || "");
if (!matrixPath || !fs.existsSync(matrixPath)) {
  throw new Error(`Missing H5 matrix: ${matrixPath || "(unset)"}`);
}

const artifactDir = path.dirname(matrixPath);
const rows = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
const maps = buildMapRows(rows);
const failures = [];

for (const map of maps) {
  if (!map.desktop) {
    failures.push(`${map.id}: missing desktop screenshot`);
  }
  if (!map.mobile) {
    failures.push(`${map.id}: missing mobile landscape screenshot`);
  }
  if (map.density.score < MIN_DENSITY_SCORE) {
    failures.push(`${map.id}: density score ${map.density.score} below ${MIN_DENSITY_SCORE}`);
  }
}
if (failures.length > 0) {
  for (const failure of failures) {
    console.error(failure);
  }
  process.exit(1);
}

const htmlPath = path.join(artifactDir, "map-patrol-report.html");
const summaryPath = path.join(artifactDir, "map-patrol-summary.json");
fs.writeFileSync(summaryPath, JSON.stringify({
  partial: ALLOW_PARTIAL,
  checked_maps: maps.length,
  screenshots: maps.length * 2,
  categories: categorySummary(maps),
  maps: maps.map((map) => ({
    id: map.id,
    category: map.category,
    density: map.density,
    desktop: metricsFor(map.desktop),
    mobile: metricsFor(map.mobile),
    note: reviewNote(map),
  })),
}, null, 2));
fs.writeFileSync(htmlPath, renderHtml(maps));
console.log(`map patrol report: ${htmlPath}`);

function buildMapRows(results) {
  const catalog = loadCatalog();
  const points = loadMapPoints();
  const grouped = new Map();
  if (!ALLOW_PARTIAL) {
    for (const record of catalog.values()) {
      if (!isPatrolMap(record)) {
        continue;
      }
      grouped.set(record.id, mapRowFor(record.id, catalog, points));
    }
  }
  for (const result of results) {
    if (!result.map || !result.name.includes("-map-")) {
      continue;
    }
    if (!grouped.has(result.map)) {
      grouped.set(result.map, mapRowFor(result.map, catalog, points));
    }
    const row = grouped.get(result.map);
    if (result.name.startsWith("h5-desktop-map-")) {
      row.desktop = result;
    } else if (result.name.startsWith("h5-mobile-landscape-map-")) {
      row.mobile = result;
    }
  }
  return [...grouped.values()].sort((a, b) => a.category.localeCompare(b.category) || a.id.localeCompare(b.id));
}

function mapRowFor(mapId, catalog, points) {
  const pointRecord = points.get(mapId) || {};
  return {
    id: mapId,
    category: catalog.get(mapId)?.category || "uncategorized",
    title: localizedName(catalog.get(mapId), mapId),
    points: pointRecord,
    density: densityFor(pointRecord),
    desktop: null,
    mobile: null,
  };
}

function isPatrolMap(record) {
  return Boolean(record?.id && record?.asset_path && record?.metadata_path);
}

function loadCatalog() {
  const catalogPath = path.resolve("configs/map_catalog.json");
  if (!fs.existsSync(catalogPath)) {
    return new Map();
  }
  const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
  return new Map((catalog.maps || []).map((record) => [record.id, record]));
}

function loadMapPoints() {
  const pointsPath = path.resolve("configs/map_points.json");
  if (!fs.existsSync(pointsPath)) {
    return new Map();
  }
  const data = JSON.parse(fs.readFileSync(pointsPath, "utf8"));
  return new Map(Object.entries(data.maps || {}));
}

function densityFor(record = {}) {
  const npcs = record.npc_points?.length || 0;
  const activities = record.life_skill_nodes?.length || 0;
  const interactions = record.interaction_points?.length || 0;
  const gatherings = record.gathering_zones?.length || 0;
  return {
    score: npcs * 2 + activities + interactions + gatherings,
    npcs,
    activities,
    interactions,
    gatherings,
  };
}

function localizedName(record, fallback) {
  if (!record?.name) {
    return fallback;
  }
  return record.name.en || record.name.zh || record.name.ja || fallback;
}

function metricsFor(result) {
  return {
    width: result?.viewport?.width || 0,
    height: result?.viewport?.height || 0,
    debug_map: result?.debugState?.map || "",
    annotated: Boolean(result?.debugState?.mapView),
    messages: result?.messages?.length || 0,
    screenshot: result?.screenshot || "",
  };
}

function reviewNote(map) {
  const notes = [];
  if (map.density.score < MIN_DENSITY_SCORE) {
    notes.push(`density ${map.density.score}/${MIN_DENSITY_SCORE}`);
  }
  for (const [label, result] of [["desktop", map.desktop], ["mobile", map.mobile]]) {
    if (!result) {
      continue;
    }
    if (result.debugState?.map !== map.id) {
      notes.push(`${label}: debug map mismatch`);
    }
    if (result.messages?.length > 0) {
      notes.push(`${label}: console messages`);
    }
  }
  return notes.join("; ");
}

function renderHtml(maps) {
  const categories = Object.entries(categorySummary(maps))
    .map(([category, count]) => `${category}: ${count}`)
    .join(" · ");
  const cards = maps.map((map) => {
    const note = reviewNote(map);
    return `
      <article class="card ${note ? "warn" : ""}">
        <header>
          <div>
            <h2>${escapeHtml(map.title)}</h2>
            <p>${escapeHtml(map.category)} / ${escapeHtml(map.id)}</p>
          </div>
          <strong>${note ? "Review" : "OK"} · Density ${map.density.score}</strong>
        </header>
        <p class="density">NPC ${map.density.npcs} · Activity ${map.density.activities} · Interaction ${map.density.interactions} · Gathering ${map.density.gatherings}</p>
        <div class="shots">
          ${renderShot("Desktop", map.desktop, map)}
          ${renderShot("Mobile", map.mobile, map)}
        </div>
        ${renderLegend()}
        ${note ? `<p class="note">${escapeHtml(note)}</p>` : ""}
      </article>`;
  }).join("\n");
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>H5 Map Patrol Report</title>
  <style>
    body { margin: 0; background: #10141b; color: #eee7d4; font: 14px/1.4 system-ui, sans-serif; }
    main { max-width: 1440px; margin: 0 auto; padding: 20px; }
    h1 { margin: 0 0 6px; font-size: 24px; }
    .summary { margin: 0 0 18px; color: #bfb49b; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(360px, 1fr)); gap: 14px; }
    .card { border: 1px solid #3b3328; background: #181d24; border-radius: 8px; padding: 10px; }
    .card.warn { border-color: #b98536; }
    header { display: flex; align-items: start; justify-content: space-between; gap: 10px; margin-bottom: 8px; }
    h2 { margin: 0; font-size: 16px; }
    p { margin: 0; }
    header p { color: #9f967f; font-size: 12px; }
    .density { margin: -3px 0 8px; color: #d9c792; font-size: 12px; }
    strong { color: #96df9c; }
    .warn strong { color: #ffcd6b; }
    .shots { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
    figure { margin: 0; }
    img { display: block; width: 100%; border-radius: 5px; border: 1px solid #2d3440; background: #05070a; }
    .shot-frame { position: relative; display: block; overflow: hidden; border-radius: 5px; }
    .shot-frame img { border-radius: 5px; }
    .overlay { position: absolute; inset: 0; pointer-events: none; }
    .rect { position: absolute; box-sizing: border-box; border: 1px solid; opacity: .5; }
    .rect.walkable { border-color: #7fe58b; background: rgba(83, 213, 103, .08); }
    .rect.blocked { border-color: #ff8d6b; background: rgba(255, 100, 80, .12); }
    .pin { position: absolute; transform: translate(-50%, -50%); width: 9px; height: 9px; border: 1px solid #10141b; box-shadow: 0 0 0 1px rgba(255,255,255,.5); }
    .pin.spawn { border-radius: 50%; background: #ffffff; }
    .pin.npc { border-radius: 50%; background: #ffcc4d; }
    .pin.interaction { background: #6dd5ff; transform: translate(-50%, -50%) rotate(45deg); }
    .pin.life { border-radius: 2px; background: #7cff9c; }
    .pin.portal { border-radius: 50%; background: #c58cff; }
    .legend { display: flex; flex-wrap: wrap; gap: 7px; margin: 5px 0 0; color: #928873; font-size: 11px; }
    .legend span::before { content: ""; display: inline-block; width: 7px; height: 7px; margin-right: 4px; vertical-align: -1px; background: currentColor; }
    .legend .npc { color: #ffcc4d; }
    .legend .interaction { color: #6dd5ff; }
    .legend .life { color: #7cff9c; }
    .legend .blocked { color: #ff8d6b; }
    .legend .walkable { color: #7fe58b; }
    figcaption { margin-top: 4px; color: #bfb49b; font-size: 12px; }
    .note { margin-top: 8px; color: #ffcd6b; }
  </style>
</head>
<body>
  <main>
    <h1>H5 Map Patrol Report</h1>
    <p class="summary">${maps.length} maps, ${maps.length * 2} screenshots. ${escapeHtml(categories)}. Check player/NPC grounding, route readability, HUD overlap, and whether any map feels too loose.</p>
    <section class="grid">${cards}</section>
  </main>
</body>
</html>
`;
}

function categorySummary(maps) {
  return maps.reduce((summary, map) => {
    summary[map.category] = (summary[map.category] || 0) + 1;
    return summary;
  }, {});
}

function renderShot(label, result, map) {
  if (!result) {
    return `<figure><div class="missing">Missing</div><figcaption>${label}</figcaption></figure>`;
  }
  const relative = path.relative(artifactDir, result.screenshot).split(path.sep).join("/");
  return `<figure>
    <a class="shot-frame" href="${escapeAttr(relative)}">
      <img src="${escapeAttr(relative)}" alt="${escapeAttr(result.name)}">
      ${renderOverlay(result, map.points)}
    </a>
    <figcaption>${label} ${result.viewport.width}x${result.viewport.height}</figcaption>
  </figure>`;
}

function renderLegend() {
  return `<p class="legend"><span class="npc">NPC</span><span class="interaction">Interaction</span><span class="life">Life</span><span class="blocked">Blocked</span><span class="walkable">Walkable</span></p>`;
}

function renderOverlay(result, points) {
  const view = result?.debugState?.mapView;
  if (!view || !points) {
    return "";
  }
  const rects = [
    ...rectsFor(points.walkable_rects, "walkable", view),
    ...rectsFor(points.blocked_rects, "blocked", view),
  ];
  const pins = [
    ...pinsFor(points.spawn_points, "spawn", view),
    ...pinsFor(points.npc_points, "npc", view),
    ...pinsFor(points.interaction_points, "interaction", view),
    ...pinsFor(points.life_skill_nodes, "life", view),
    ...pinsFor(points.portals, "portal", view),
  ];
  if (rects.length === 0 && pins.length === 0) {
    return "";
  }
  return `<span class="overlay" aria-hidden="true">${rects.join("")}${pins.join("")}</span>`;
}

function rectsFor(rects = [], className, view) {
  return rects.map((rect) => screenRectFor(rect, view))
    .filter((rect) => rect && isVisibleRect(rect))
    .map((rect) => `<span class="rect ${className}" style="${rectStyle(rect)}"></span>`);
}

function pinsFor(points = [], className, view) {
  return points.map((point) => screenPointFor(point, view))
    .filter((point) => point && isVisiblePoint(point))
    .map((point) => `<span class="pin ${className}" title="${escapeAttr(point.id)}" style="${pointStyle(point)}"></span>`);
}

function screenRectFor(rect, view) {
  const topLeft = screenPointFor(rect, view);
  const bottomRight = screenPointFor({
    x: Number(rect.x) + Number(rect.width),
    y: Number(rect.y) + Number(rect.height),
  }, view);
  if (!topLeft || !bottomRight) {
    return null;
  }
  return {
    x: topLeft.x,
    y: topLeft.y,
    width: bottomRight.x - topLeft.x,
    height: bottomRight.y - topLeft.y,
    viewportWidth: topLeft.viewportWidth,
    viewportHeight: topLeft.viewportHeight,
  };
}

function screenPointFor(point, view) {
  const canvasWidth = Number(view.canvas_width || 0);
  const canvasHeight = Number(view.canvas_height || 0);
  const viewportWidth = Number(view.viewport_width || 0);
  const viewportHeight = Number(view.viewport_height || 0);
  const zoomX = Number(view.zoom_x || 1);
  const zoomY = Number(view.zoom_y || 1);
  if (canvasWidth <= 0 || canvasHeight <= 0 || viewportWidth <= 0 || viewportHeight <= 0) {
    return null;
  }
  const worldX = Number(point.x) - canvasWidth * 0.5;
  const worldY = Number(point.y) - canvasHeight * 0.5;
  return {
    id: String(point.id || ""),
    x: (worldX - Number(view.center_x || 0)) * zoomX + viewportWidth * 0.5,
    y: (worldY - Number(view.center_y || 0)) * zoomY + viewportHeight * 0.5,
    viewportWidth,
    viewportHeight,
  };
}

function isVisiblePoint(point) {
  return point.x >= -12 && point.y >= -12 && point.x <= point.viewportWidth + 12 && point.y <= point.viewportHeight + 12;
}

function isVisibleRect(rect) {
  return rect.x + rect.width >= 0 && rect.y + rect.height >= 0 && rect.x <= rect.viewportWidth && rect.y <= rect.viewportHeight;
}

function pointStyle(point) {
  return `left:${percent(point.x, point.viewportWidth)}%;top:${percent(point.y, point.viewportHeight)}%;`;
}

function rectStyle(rect) {
  return [
    `left:${percent(rect.x, rect.viewportWidth)}%`,
    `top:${percent(rect.y, rect.viewportHeight)}%`,
    `width:${percent(rect.width, rect.viewportWidth)}%`,
    `height:${percent(rect.height, rect.viewportHeight)}%`,
  ].join(";");
}

function percent(value, total) {
  return total > 0 ? (Number(value) / total * 100).toFixed(3) : "0";
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
