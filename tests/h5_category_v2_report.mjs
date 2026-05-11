import fs from "node:fs";
import path from "node:path";

const REQUIRED_MAP_CATEGORIES = {
  main_city: 6,
  life_skill: 8,
  random_exploration: 8,
  social_function: 6,
  seasonal: 4,
};
const EXPECTED_AVATAR_VARIANTS = [
  "male_melee_v0",
  "male_ranged_v0",
  "male_magic_v0",
  "female_melee_v0",
  "female_ranged_v0",
  "female_magic_v0",
];
const EXPECTED_WALK_FACINGS = ["down", "right", "up", "left"];
const EXPECTED_DEVICES = ["desktop", "mobile-landscape"];

const artifactRoot = path.resolve(process.argv[2] || process.env.PSW_H5_CATEGORY_V2_ARTIFACT_DIR || "");
if (!artifactRoot) {
  throw new Error("Missing category v2 artifact root");
}

const inputs = {
  maps: path.join(artifactRoot, "h5-map-patrol", "map-patrol-summary.json"),
  npcAmbience: path.join(artifactRoot, "h5-npc-ambience-patrol", "npc-ambience-patrol-summary.json"),
  avatarVariants: path.join(artifactRoot, "h5-avatar-variant-patrol", "avatar-variant-patrol-summary.json"),
  avatarActions: path.join(artifactRoot, "h5-avatar-action-patrol", "avatar-action-patrol-summary.json"),
};

const data = Object.fromEntries(Object.entries(inputs).map(([key, file]) => [key, readJson(file)]));
const gates = [
  mapGate(data.maps),
  npcAmbienceGate(data.npcAmbience),
  avatarVariantGate(data.avatarVariants),
  avatarActionGate(data.avatarActions),
];
const failures = gates.flatMap((gate) => gate.failures.map((failure) => `${gate.title}: ${failure}`));

const summaryPath = path.join(artifactRoot, "category-v2-summary.json");
const htmlPath = path.join(artifactRoot, "category-v2-report.html");
fs.writeFileSync(summaryPath, JSON.stringify({
  ok: failures.length === 0,
  artifact_root: artifactRoot,
  inputs,
  gates,
}, null, 2));
fs.writeFileSync(htmlPath, renderHtml(gates));

if (failures.length > 0) {
  for (const failure of failures) {
    console.error(failure);
  }
  console.error(`category v2 report: ${htmlPath}`);
  process.exit(1);
}

console.log(`category v2 report: ${htmlPath}`);

function readJson(file) {
  if (!fs.existsSync(file)) {
    throw new Error(`Missing summary file: ${file}`);
  }
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function mapGate(summary) {
  const failures = [];
  const categories = summary.categories || countBy(summary.maps || [], "category");
  const reviewNotes = (summary.maps || []).filter((map) => map.note);

  if (summary.partial) {
    failures.push("map patrol ran in partial mode");
  }
  if (Number(summary.checked_maps || 0) !== 32) {
    failures.push(`expected 32 maps, got ${summary.checked_maps || 0}`);
  }
  if (Number(summary.screenshots || 0) !== 64) {
    failures.push(`expected 64 map screenshots, got ${summary.screenshots || 0}`);
  }
  for (const [category, expected] of Object.entries(REQUIRED_MAP_CATEGORIES)) {
    if (Number(categories[category] || 0) !== expected) {
      failures.push(`expected ${expected} ${category} maps, got ${categories[category] || 0}`);
    }
  }
  if (reviewNotes.length > 0) {
    failures.push(`${reviewNotes.length} map review notes remain`);
  }

  return {
    id: "maps",
    title: "Maps",
    ok: failures.length === 0,
    failures,
    metrics: {
      checked_maps: summary.checked_maps || 0,
      screenshots: summary.screenshots || 0,
      categories,
      review_notes: reviewNotes.map((map) => ({ id: map.id, note: map.note })),
    },
    report: "h5-map-patrol/map-patrol-report.html",
  };
}

function npcAmbienceGate(summary) {
  const rows = summary.rows || [];
  const npcIds = new Set(rows.map((row) => row.npc).filter(Boolean));
  const maps = new Set(rows.map((row) => row.map).filter(Boolean));
  const failures = [];

  if (Number(summary.checked || 0) < 8) {
    failures.push(`expected at least 8 NPC ambience screenshots, got ${summary.checked || 0}`);
  }
  if (npcIds.size < 4) {
    failures.push(`expected at least 4 distinct NPC ambience targets, got ${npcIds.size}`);
  }
  if (maps.size < 4) {
    failures.push(`expected ambience coverage across at least 4 maps, got ${maps.size}`);
  }

  return {
    id: "npc_ambience",
    title: "NPC Ambience",
    ok: failures.length === 0,
    failures,
    metrics: {
      checked: summary.checked || 0,
      npcs: [...npcIds].sort(),
      maps: [...maps].sort(),
    },
    report: "h5-npc-ambience-patrol/npc-ambience-patrol-report.html",
  };
}

function avatarVariantGate(summary) {
  const rows = summary.rows || [];
  const counts = countBy(rows, "variant");
  const failures = [];

  if (Number(summary.checked || 0) < 12) {
    failures.push(`expected at least 12 avatar variant screenshots, got ${summary.checked || 0}`);
  }
  for (const variant of EXPECTED_AVATAR_VARIANTS) {
    if (Number(counts[variant] || 0) < 2) {
      failures.push(`expected desktop and mobile coverage for ${variant}, got ${counts[variant] || 0}`);
    }
  }

  return {
    id: "avatar_variants",
    title: "Avatar Variants",
    ok: failures.length === 0,
    failures,
    metrics: {
      checked: summary.checked || 0,
      variants: counts,
    },
    report: "h5-avatar-variant-patrol/avatar-variant-patrol-report.html",
  };
}

function avatarActionGate(summary) {
  const rows = summary.rows || [];
  const failures = [];
  const rowNames = new Set(rows.map((row) => row.name));
  const walkRows = rows.filter((row) => row.action === "walk");
  const localEmotes = rows.filter((row) => row.action === "emote");
  const remoteRows = rows.filter((row) => row.remote);

  if (Number(summary.checked || 0) < 12) {
    failures.push(`expected at least 12 avatar action screenshots, got ${summary.checked || 0}`);
  }
  for (const device of EXPECTED_DEVICES) {
    for (const facing of EXPECTED_WALK_FACINGS) {
      const expectedName = `h5-${device}-avatar-action-walk-${facing}`;
      if (!rowNames.has(expectedName)) {
        failures.push(`missing ${expectedName}`);
      }
    }
    if (!rowNames.has(`h5-${device}-avatar-action-emote`)) {
      failures.push(`missing h5-${device}-avatar-action-emote`);
    }
    if (!rowNames.has(`h5-${device}-avatar-action-remote-sync`)) {
      failures.push(`missing h5-${device}-avatar-action-remote-sync`);
    }
  }

  const movedDirections = new Set(walkRows.map((row) => row.facing));
  for (const facing of EXPECTED_WALK_FACINGS) {
    if (!movedDirections.has(facing)) {
      failures.push(`walk direction ${facing} did not appear in summary`);
    }
  }
  if (localEmotes.length < 2) {
    failures.push(`expected desktop and mobile local emote screenshots, got ${localEmotes.length}`);
  }
  if (remoteRows.length < 2) {
    failures.push(`expected desktop and mobile remote sync screenshots, got ${remoteRows.length}`);
  }

  return {
    id: "avatar_actions",
    title: "Avatar Actions",
    ok: failures.length === 0,
    failures,
    metrics: {
      checked: summary.checked || 0,
      walk_rows: walkRows.length,
      local_emote_rows: localEmotes.length,
      remote_rows: remoteRows.length,
    },
    report: "h5-avatar-action-patrol/avatar-action-patrol-report.html",
  };
}

function countBy(rows, key) {
  return rows.reduce((counts, row) => {
    const value = row[key] || "unknown";
    counts[value] = (counts[value] || 0) + 1;
    return counts;
  }, {});
}

function renderHtml(gates) {
  const ok = gates.every((gate) => gate.ok);
  const cards = gates.map((gate) => {
    const failures = gate.failures.length > 0
      ? `<ul>${gate.failures.map((failure) => `<li>${escapeHtml(failure)}</li>`).join("")}</ul>`
      : "<p class=\"pass\">Gate passed.</p>";
    return `<article class="${gate.ok ? "ok" : "fail"}">
      <header>
        <h2>${escapeHtml(gate.title)}</h2>
        <strong>${gate.ok ? "OK" : "Review"}</strong>
      </header>
      ${failures}
      <pre>${escapeHtml(JSON.stringify(gate.metrics, null, 2))}</pre>
      <a href="${escapeAttr(gate.report)}">Open detail report</a>
    </article>`;
  }).join("\n");

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Category v2 Gate</title>
  <style>
    body { margin: 0; background: #10151d; color: #efe6d2; font: 14px/1.45 system-ui, sans-serif; }
    main { max-width: 1180px; margin: 0 auto; padding: 22px; }
    h1 { margin: 0; font-size: 25px; }
    .summary { margin: 4px 0 18px; color: #c8b995; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 14px; }
    article { border: 1px solid #3a3327; border-radius: 8px; padding: 12px; background: #1a2029; }
    article.fail { border-color: #c98b42; }
    header { display: flex; justify-content: space-between; gap: 12px; align-items: baseline; margin-bottom: 8px; }
    h2 { margin: 0; font-size: 17px; }
    strong { color: #90df96; }
    .fail strong { color: #ffca73; }
    ul { margin: 0 0 10px 18px; color: #ffca73; padding: 0; }
    p { margin: 0 0 10px; }
    .pass { color: #90df96; }
    pre { overflow: auto; background: #10151d; border-radius: 6px; padding: 9px; color: #91a9c1; font-size: 12px; }
    a { color: #8ecbff; }
  </style>
</head>
<body>
  <main>
    <h1>Category v2 Gate</h1>
    <p class="summary">${ok ? "All category v2 gates passed." : "One or more category v2 gates need review."}</p>
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
