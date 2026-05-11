import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";

const MATRIX_LOG = path.resolve(
  process.env.PSW_H5_SEMANTIC_MATRIX || process.argv[2] || ".tools/artifacts/h5-matrix.json",
);

const DEFAULT_CASES = [
  "h5-desktop-world-base",
  "h5-mobile-landscape-world-base",
  "h5-mobile-landscape-name-reveal",
  "h5-mobile-landscape-hotspot-feedback",
  "h5-desktop-map-panel",
  "h5-mobile-landscape-map-panel",
  "h5-mobile-landscape-map-atlas",
  "h5-mobile-landscape-map-atlas-wilds-filter",
  "h5-desktop-trade-facility-panel",
  "h5-mobile-landscape-trade-price-keyboard-guard",
  "h5-mobile-landscape-guild-facility-panel",
  "h5-desktop-mail-panel",
  "h5-desktop-messages-panel",
  "h5-mobile-landscape-chat-keyboard-guard",
  "h5-mobile-landscape-messages-panel",
  "h5-mobile-landscape-private-messages-panel",
  "h5-mobile-landscape-private-keyboard-guard",
  "h5-mobile-landscape-inventory-panel",
  "h5-mobile-landscape-inventory-activity-rewards",
  "h5-mobile-landscape-creator-panel",
  "h5-desktop-profile-card",
  "h5-mobile-landscape-profile-card",
  "h5-mobile-landscape-profile-report",
  "h5-desktop-housing-selected",
  "h5-mobile-landscape-housing-selected",
  "h5-mobile-landscape-housing",
  "h5-desktop-minigame-host",
  "h5-mobile-landscape-minigame-host",
  "h5-liveops-375x240-ops-tab",
  "h5-mobile-portrait-guard",
];

const EXPECTATIONS = {
  "h5-desktop-login-character-preview": {
    regions: [
      region("login panel", 0.34, 0.26, 0.24, 0.46, 10, 18),
      region("character preview", 0.65, 0.26, 0.15, 0.46, 20, 18),
    ],
  },
  "h5-mobile-landscape-login-character-preview": {
    regions: [
      region("mobile login panel", 0.28, 0.10, 0.42, 0.80, 10, 18),
      region("mobile character preview", 0.72, 0.12, 0.20, 0.76, 14, 15),
    ],
  },
  "h5-desktop-world-base": {
    regions: [
      region("world playfield", 0.18, 0.12, 0.64, 0.58, 45, 30),
      region("bottom HUD", 0.08, 0.82, 0.84, 0.15, 20, 18),
    ],
  },
  "h5-mobile-landscape-world-base": {
    regions: [
      region("mobile playfield", 0.16, 0.10, 0.68, 0.62, 35, 25),
      region("mobile HUD", 0.05, 0.78, 0.90, 0.18, 16, 14),
    ],
  },
  "h5-mobile-landscape-name-reveal": {
    regions: [
      region("avatar focus", 0.36, 0.30, 0.28, 0.32, 20, 18),
    ],
  },
  "h5-desktop-trade-facility-panel": {
    debug: { map: "social_trade_market_v1", facility: "trade" },
    regions: [
      region("trade board", 0.50, 0.08, 0.46, 0.78, 35, 28),
    ],
  },
  "h5-desktop-map-panel": {
    regions: [
      region("map directory", 0.42, 0.10, 0.52, 0.76, 28, 22),
    ],
  },
  "h5-mobile-landscape-map-panel": {
    debug: { overlay: "map" },
    regions: [
      region("mobile map directory", 0.42, 0.06, 0.54, 0.74, 24, 20),
    ],
  },
  "h5-mobile-landscape-map-atlas": {
    debug: { overlay: "map_atlas" },
    regions: [
      region("mobile map atlas", 0.05, 0.06, 0.90, 0.74, 28, 22),
    ],
  },
  "h5-mobile-landscape-map-atlas-wilds-filter": {
    debug: { overlay: "map_atlas" },
    regions: [
      region("mobile map atlas", 0.05, 0.06, 0.90, 0.74, 28, 22),
    ],
  },
  "h5-mobile-landscape-trade-price-keyboard-guard": {
    debug: { map: "social_trade_market_v1", facility: "trade", focusedInput: "trade_price" },
    regions: [
      region("mobile trade board", 0.46, 0.06, 0.50, 0.72, 28, 22),
      region("keyboard-safe lower band", 0.10, 0.74, 0.80, 0.22, 15, 12),
    ],
  },
  "h5-mobile-landscape-guild-facility-panel": {
    debug: { map: "social_guild_garden_v1", facility: "guild" },
    regions: [
      region("mobile guild board", 0.44, 0.06, 0.52, 0.72, 25, 20),
    ],
  },
  "h5-desktop-mail-panel": {
    regions: [
      region("mail panel", 0.42, 0.10, 0.52, 0.76, 28, 22),
    ],
  },
  "h5-desktop-messages-panel": {
    regions: [
      region("messages panel", 0.42, 0.10, 0.52, 0.76, 30, 24),
    ],
  },
  "h5-mobile-landscape-messages-panel": {
    debug: { overlay: "mail" },
    regions: [
      region("mobile messages panel", 0.42, 0.06, 0.54, 0.74, 24, 20),
    ],
  },
  "h5-mobile-landscape-chat-keyboard-guard": {
    debug: { focusedInput: "chat" },
    regions: [
      region("mobile public chat input", 0.12, 0.74, 0.76, 0.20, 16, 12),
    ],
  },
  "h5-mobile-landscape-map-button-panel": {
    debug: { overlay: "map" },
    regions: [
      region("mobile map panel from HUD", 0.42, 0.06, 0.54, 0.74, 24, 20),
    ],
  },
  "h5-mobile-landscape-mail-button-panel": {
    debug: { overlay: "mail" },
    regions: [
      region("mobile mail panel from HUD", 0.42, 0.06, 0.54, 0.74, 24, 20),
    ],
  },
  "h5-mobile-landscape-emote-palette": {
    debug: { overlay: "emote" },
    regions: [
      region("mobile emote palette from HUD", 0.02, 0.02, 0.42, 0.62, 20, 16),
    ],
  },
  "h5-mobile-landscape-private-keyboard-guard": {
    debug: { focusedInput: "private" },
    regions: [
      region("private messages panel", 0.42, 0.06, 0.54, 0.74, 25, 20),
      region("private input band", 0.18, 0.72, 0.72, 0.22, 15, 12),
    ],
  },
  "h5-mobile-landscape-private-messages-panel": {
    debug: { overlay: "private" },
    regions: [
      region("mobile private messages panel", 0.42, 0.06, 0.54, 0.74, 25, 20),
    ],
  },
  "h5-mobile-landscape-room-keyboard-guard": {
    debug: { overlay: "room", focusedInput: "room" },
    regions: [
      region("room panel input band", 0.50, 0.34, 0.38, 0.20, 18, 14),
      region("keyboard-safe room lower band", 0.10, 0.74, 0.80, 0.22, 15, 12),
    ],
  },
  "h5-mobile-landscape-inventory-panel": {
    debug: { overlay: "inventory" },
    regions: [
      region("mobile inventory panel", 0.42, 0.06, 0.54, 0.74, 24, 20),
    ],
  },
  "h5-mobile-landscape-inventory-activity-rewards": {
    debug: { overlay: "inventory" },
    regions: [
      region("mobile inventory rewards panel", 0.42, 0.06, 0.54, 0.74, 24, 20),
    ],
  },
  "h5-mobile-landscape-creator-panel": {
    debug: { overlay: "creator" },
    regions: [
      region("mobile creator panel", 0.42, 0.06, 0.54, 0.74, 24, 20),
    ],
  },
  "h5-mobile-landscape-room-panel": {
    debug: { overlay: "room" },
    regions: [
      region("mobile room panel", 0.42, 0.06, 0.54, 0.74, 24, 20),
    ],
  },
  "h5-desktop-profile-card": {
    debug: { overlay: "profile" },
    regions: [
      region("profile card", 0.42, 0.10, 0.52, 0.76, 28, 22),
    ],
  },
  "h5-mobile-landscape-profile-card": {
    debug: { overlay: "profile" },
    regions: [
      region("mobile profile card", 0.72, 0.10, 0.26, 0.72, 20, 16),
    ],
  },
  "h5-mobile-landscape-profile-report": {
    debug: { overlay: "profile" },
    regions: [
      region("mobile profile report state", 0.72, 0.10, 0.26, 0.72, 20, 16),
    ],
  },
  "h5-desktop-housing-selected": {
    debug: { route: "home_edit" },
    regions: [
      region("housing room", 0.22, 0.12, 0.56, 0.58, 35, 26),
      region("housing catalog", 0.20, 0.80, 0.60, 0.15, 20, 15),
    ],
  },
  "h5-mobile-landscape-housing-selected": {
    debug: { route: "home_edit" },
    regions: [
      region("mobile housing room", 0.20, 0.10, 0.60, 0.56, 28, 22),
      region("mobile housing catalog", 0.10, 0.78, 0.80, 0.18, 16, 12),
    ],
  },
  "h5-mobile-landscape-housing": {
    debug: { route: "home_edit" },
    regions: [
      region("mobile housing room after move", 0.20, 0.10, 0.60, 0.56, 28, 22),
      region("mobile housing catalog after move", 0.10, 0.78, 0.80, 0.18, 16, 12),
    ],
  },
  "h5-desktop-minigame-host": {
    samples: [{ label: "sandbox-top-bar", maxRgb: 90 }],
    regions: [
      region("minigame sandbox", 0.12, 0.12, 0.76, 0.72, 30, 24),
    ],
  },
  "h5-mobile-landscape-minigame-host": {
    samples: [{ label: "sandbox-top-bar", maxRgb: 90 }],
    regions: [
      region("mobile minigame sandbox", 0.08, 0.10, 0.84, 0.72, 24, 20),
    ],
  },
  "h5-liveops-375x240-ops-tab": {
    debug: { route: "liveops_console" },
    regions: [
      region("small liveops console", 0.04, 0.05, 0.92, 0.88, 25, 20),
    ],
  },
  "h5-mobile-portrait-guard": {
    allowFlatFull: true,
    regions: [
      region("portrait guard", 0.20, 0.42, 0.60, 0.18, 3, 70),
    ],
  },
};

const matrix = JSON.parse(fs.readFileSync(MATRIX_LOG, "utf8"));
const selectedCases = semanticCaseNames(matrix);
const byName = new Map(matrix.map((entry) => [entry.name, entry]));
const failures = [];
const semanticRows = [];

for (const name of selectedCases) {
  const row = byName.get(name);
  if (!row) {
    failures.push(`${name}: missing from H5 matrix log`);
    continue;
  }
  const screenshotPath = path.resolve(row.screenshot || "");
  if (!fs.existsSync(screenshotPath)) {
    failures.push(`${name}: screenshot not found at ${screenshotPath}`);
    continue;
  }
  const image = readPng(screenshotPath);
  const expectation = EXPECTATIONS[name] || fallbackExpectation(name);
  const full = imageStats(image, normalizedRegion(0, 0, 1, 1));
  const caseFailures = verifyCase(row, image, expectation, full);
  semanticRows.push({
    name,
    screenshot: screenshotPath,
    width: image.width,
    height: image.height,
    uniqueColors: full.uniqueColors,
    luminanceRange: Math.round(full.luminanceRange),
  });
  failures.push(...caseFailures.map((failure) => `${name}: ${failure}`));
}

console.log(JSON.stringify({
  matrix: MATRIX_LOG,
  cases: semanticRows,
  checked: semanticRows.length,
}, null, 2));

if (failures.length > 0) {
  for (const failure of failures) {
    console.error(failure);
  }
  process.exit(1);
}

function verifyCase(row, image, expectation, full) {
  const caseFailures = [];
  if (!row.canvasInfo) {
    caseFailures.push("canvasInfo missing");
  }
  if (row.viewport && image.width < row.viewport.width) {
    caseFailures.push(`screenshot width ${image.width} is smaller than viewport ${row.viewport.width}`);
  }
  if (row.viewport && image.height < row.viewport.height) {
    caseFailures.push(`screenshot height ${image.height} is invalid for viewport ${row.viewport.height}`);
  }
  if ((row.messages || []).length > 0) {
    caseFailures.push(`console warnings/errors present: ${(row.messages || []).join(" | ")}`);
  }
  if (!expectation.allowFlatFull && full.uniqueColors < 35) {
    caseFailures.push(`screenshot looks too flat: ${full.uniqueColors} sampled colors`);
  }
  if (full.opaqueRatio < 0.98) {
    caseFailures.push(`screenshot has unexpected transparency: ${full.opaqueRatio.toFixed(3)} opaque`);
  }
  if (expectation.debug) {
    for (const [key, expected] of Object.entries(expectation.debug)) {
      const actual = row.debugState?.[key] || row[key] || "";
      if (actual !== expected) {
        caseFailures.push(`debug ${key} expected ${expected}, got ${actual || "<empty>"}`);
      }
    }
  }
  for (const sampleExpectation of expectation.samples || []) {
    const sample = (row.canvasSamples || []).find((entry) => entry.label === sampleExpectation.label);
    if (!sample || sample.error) {
      caseFailures.push(`semantic sample ${sampleExpectation.label} missing: ${sample?.error || "not captured"}`);
      continue;
    }
    const maxChannel = Math.max(sample.r, sample.g, sample.b);
    if (maxChannel > sampleExpectation.maxRgb || sample.a < 200) {
      caseFailures.push(
        `semantic sample ${sampleExpectation.label} expected dark UI, got rgba(${sample.r}, ${sample.g}, ${sample.b}, ${sample.a})`,
      );
    }
  }
  for (const expectedRegion of expectation.regions || []) {
    const stats = imageStats(image, expectedRegion);
    if (stats.uniqueColors < expectedRegion.minUniqueColors) {
      caseFailures.push(
        `${expectedRegion.label} too flat: ${stats.uniqueColors} sampled colors < ${expectedRegion.minUniqueColors}`,
      );
    }
    if (stats.luminanceRange < expectedRegion.minLuminanceRange) {
      caseFailures.push(
        `${expectedRegion.label} lacks contrast: ${Math.round(stats.luminanceRange)} < ${expectedRegion.minLuminanceRange}`,
      );
    }
    if (stats.opaqueRatio < 0.98) {
      caseFailures.push(`${expectedRegion.label} has transparent samples: ${stats.opaqueRatio.toFixed(3)} opaque`);
    }
  }
  caseFailures.push(...verifyHudLayout(row, image));
  return caseFailures;
}

function verifyHudLayout(row, image) {
  const failures = [];
  const viewport = row.viewport || row.canvasInfo || { width: image.width, height: image.height };
  const firstSessionRect = row.debugState?.firstSessionRect || null;
  const hotspotRect = row.debugState?.hotspotRect || null;
  const isWorldBase = row.name === "h5-desktop-world-base" || row.name === "h5-mobile-landscape-world-base";
  const isHotspot = row.name === "h5-mobile-landscape-hotspot-feedback";
  const isMobileLandscape = row.name.startsWith("h5-mobile-landscape-");

  if ((isWorldBase || isHotspot) && validRect(firstSessionRect) && isMobileLandscape) {
    if (firstSessionRect.height > 44) {
      failures.push(`first-session chip too tall for mobile: ${formatRect(firstSessionRect)}`);
    }
    if (firstSessionRect.width > 240) {
      failures.push(`first-session chip too wide for mobile: ${formatRect(firstSessionRect)}`);
    }
    if (rectBottom(firstSessionRect) > viewport.height * 0.34) {
      failures.push(`first-session chip reaches too far into the playfield: ${formatRect(firstSessionRect)}`);
    }
  }

  if (validRect(hotspotRect)) {
    if (validRect(firstSessionRect) && intersects(expandRect(hotspotRect, 4), firstSessionRect)) {
      failures.push(`hotspot prompt overlaps first-session chip: ${formatRect(hotspotRect)} vs ${formatRect(firstSessionRect)}`);
    }
    if (hotspotRect.y < viewport.height * 0.20) {
      failures.push(`hotspot prompt is too close to the top HUD: ${formatRect(hotspotRect)}`);
    }
    if (rectBottom(hotspotRect) > viewport.height * 0.78) {
      failures.push(`hotspot prompt overlaps the bottom HUD band: ${formatRect(hotspotRect)}`);
    }
  }

  return failures;
}

function fallbackExpectation(name) {
  return {
    regions: [
      region(`${name} content`, 0.08, 0.08, 0.84, 0.78, 25, 18),
    ],
  };
}

function semanticCaseNames(rows) {
  const explicit = process.env.PSW_H5_SEMANTIC_CASES || "";
  if (explicit.trim()) {
    return explicit.split(",").map((name) => name.trim()).filter(Boolean);
  }
  const group = process.env.PSW_H5_SEMANTIC_GROUP || "";
  if (group === "maps") {
    const names = rows
      .filter((row) => row.map && (
        row.name.startsWith("h5-desktop-map-")
        || row.name.startsWith("h5-mobile-landscape-map-")
      ))
      .map((row) => row.name);
    if (names.length === 0) {
      throw new Error("PSW_H5_SEMANTIC_GROUP=maps found no generated map screenshot rows");
    }
    return names;
  }
  if (group === "npc_ambience") {
    const names = rows
      .filter((row) => row.group === "npc_ambience" || row.ambienceNpc || row.name.includes("-npc-ambience-"))
      .map((row) => row.name);
    if (names.length === 0) {
      throw new Error("PSW_H5_SEMANTIC_GROUP=npc_ambience found no NPC ambience screenshot rows");
    }
    return names;
  }
  if (group === "avatar_variants") {
    const names = rows
      .filter((row) => row.group === "avatar_variants" || row.characterVariant || row.name.includes("-avatar-variant-"))
      .map((row) => row.name);
    if (names.length === 0) {
      throw new Error("PSW_H5_SEMANTIC_GROUP=avatar_variants found no avatar variant screenshot rows");
    }
    return names;
  }
  if (group === "avatar_actions") {
    const names = rows
      .filter((row) => row.group === "avatar_actions" || row.name.includes("-avatar-action-"))
      .map((row) => row.name);
    if (names.length === 0) {
      throw new Error("PSW_H5_SEMANTIC_GROUP=avatar_actions found no avatar action screenshot rows");
    }
    return names;
  }
  return DEFAULT_CASES;
}

function region(label, x, y, width, height, minUniqueColors, minLuminanceRange) {
  return {
    label,
    ...normalizedRegion(x, y, width, height),
    minUniqueColors,
    minLuminanceRange,
  };
}

function normalizedRegion(x, y, width, height) {
  return { x, y, width, height };
}

function validRect(rect) {
  return rect
    && Number.isFinite(rect.x)
    && Number.isFinite(rect.y)
    && Number.isFinite(rect.width)
    && Number.isFinite(rect.height)
    && rect.width > 0
    && rect.height > 0;
}

function rectRight(rect) {
  return rect.x + rect.width;
}

function rectBottom(rect) {
  return rect.y + rect.height;
}

function expandRect(rect, amount) {
  return {
    x: rect.x - amount,
    y: rect.y - amount,
    width: rect.width + amount * 2,
    height: rect.height + amount * 2,
  };
}

function intersects(a, b) {
  return a.x < rectRight(b)
    && rectRight(a) > b.x
    && a.y < rectBottom(b)
    && rectBottom(a) > b.y;
}

function formatRect(rect) {
  return `x=${Math.round(rect.x)}, y=${Math.round(rect.y)}, w=${Math.round(rect.width)}, h=${Math.round(rect.height)}`;
}

function imageStats(image, area) {
  const x0 = Math.max(0, Math.floor(image.width * area.x));
  const y0 = Math.max(0, Math.floor(image.height * area.y));
  const x1 = Math.min(image.width, Math.ceil(image.width * (area.x + area.width)));
  const y1 = Math.min(image.height, Math.ceil(image.height * (area.y + area.height)));
  const stepX = Math.max(1, Math.floor((x1 - x0) / 36));
  const stepY = Math.max(1, Math.floor((y1 - y0) / 24));
  const colors = new Set();
  let luminanceMin = Infinity;
  let luminanceMax = -Infinity;
  let samples = 0;
  let opaque = 0;
  for (let y = y0; y < y1; y += stepY) {
    for (let x = x0; x < x1; x += stepX) {
      const offset = (y * image.width + x) * 4;
      const r = image.pixels[offset];
      const g = image.pixels[offset + 1];
      const b = image.pixels[offset + 2];
      const a = image.pixels[offset + 3];
      const luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      luminanceMin = Math.min(luminanceMin, luminance);
      luminanceMax = Math.max(luminanceMax, luminance);
      colors.add(`${r >> 4},${g >> 4},${b >> 4},${a > 127 ? 1 : 0}`);
      samples += 1;
      if (a >= 240) {
        opaque += 1;
      }
    }
  }
  return {
    uniqueColors: colors.size,
    luminanceRange: luminanceMax - luminanceMin,
    opaqueRatio: samples === 0 ? 0 : opaque / samples,
  };
}

function readPng(filePath) {
  const buffer = fs.readFileSync(filePath);
  const signature = "89504e470d0a1a0a";
  if (buffer.subarray(0, 8).toString("hex") !== signature) {
    throw new Error(`${filePath} is not a PNG file`);
  }
  let offset = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  let interlace = 0;
  const idat = [];
  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.subarray(offset + 4, offset + 8).toString("ascii");
    const data = buffer.subarray(offset + 8, offset + 8 + length);
    offset += length + 12;
    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
      interlace = data[12];
    } else if (type === "IDAT") {
      idat.push(data);
    } else if (type === "IEND") {
      break;
    }
  }
  if (bitDepth !== 8 || interlace !== 0 || ![2, 6].includes(colorType)) {
    throw new Error(`${filePath} uses unsupported PNG format bitDepth=${bitDepth} colorType=${colorType} interlace=${interlace}`);
  }
  const channels = colorType === 6 ? 4 : 3;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const pixels = unfilterPng(raw, width, height, channels, colorType);
  return { width, height, pixels };
}

function unfilterPng(raw, width, height, channels, colorType) {
  const stride = width * channels;
  const rgba = Buffer.alloc(width * height * 4);
  const previous = Buffer.alloc(stride);
  let rawOffset = 0;
  for (let y = 0; y < height; y += 1) {
    const filter = raw[rawOffset];
    rawOffset += 1;
    const row = Buffer.alloc(stride);
    for (let i = 0; i < stride; i += 1) {
      const left = i >= channels ? row[i - channels] : 0;
      const up = previous[i] || 0;
      const upLeft = i >= channels ? previous[i - channels] || 0 : 0;
      row[i] = (raw[rawOffset + i] + predictor(filter, left, up, upLeft)) & 0xff;
    }
    rawOffset += stride;
    for (let x = 0; x < width; x += 1) {
      const source = x * channels;
      const target = (y * width + x) * 4;
      rgba[target] = row[source];
      rgba[target + 1] = row[source + 1];
      rgba[target + 2] = row[source + 2];
      rgba[target + 3] = colorType === 6 ? row[source + 3] : 255;
    }
    previous.set(row);
  }
  return rgba;
}

function predictor(filter, left, up, upLeft) {
  switch (filter) {
    case 0:
      return 0;
    case 1:
      return left;
    case 2:
      return up;
    case 3:
      return Math.floor((left + up) / 2);
    case 4:
      return paeth(left, up, upLeft);
    default:
      throw new Error(`unsupported PNG row filter ${filter}`);
  }
}

function paeth(left, up, upLeft) {
  const p = left + up - upLeft;
  const pa = Math.abs(p - left);
  const pb = Math.abs(p - up);
  const pc = Math.abs(p - upLeft);
  if (pa <= pb && pa <= pc) {
    return left;
  }
  return pb <= pc ? up : upLeft;
}
