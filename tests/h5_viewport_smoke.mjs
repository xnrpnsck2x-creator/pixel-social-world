import fs from "node:fs";
import path from "node:path";
import { caseUrl, importPlaywright, runCaseSteps, sampleCanvasPixels } from "./h5_smoke_helpers.mjs";

const DEFAULT_PLAYWRIGHT_MODULE = "../.tools/browser-smoke/node_modules/playwright/index.mjs";
const APP_URL = process.env.PSW_H5_URL || "http://127.0.0.1:18888/index.html";
const ARTIFACT_DIR = path.resolve(process.env.PSW_H5_ARTIFACT_DIR || ".tools/artifacts");

function generatedMapCases() {
  const catalogPath = path.resolve("configs/map_catalog.json");
  if (!fs.existsSync(catalogPath)) {
    return [];
  }
  const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
  const generatedMaps = catalog.maps.filter((map) => map.asset_path && map.metadata_path);
  return generatedMaps.flatMap((map) => [generatedMapCase(map), generatedMobileMapCase(map)]);
}

function generatedMapCase(map) {
  return {
    name: `h5-desktop-map-${slugifyMapId(map.id)}`,
    group: "maps",
    viewport: { width: 1280, height: 720 },
    map: map.id,
    exposureProbe: true,
    loginClick: { x: 640, y: 421 },
  };
}

function generatedMobileMapCase(map) {
  return {
    name: `h5-mobile-landscape-map-${slugifyMapId(map.id)}`,
    group: "maps",
    viewport: { width: 844, height: 390 },
    map: map.id,
    exposureProbe: true,
    clearHoverBeforeScreenshot: true,
    loginClick: { x: 422, y: 238 },
  };
}

function slugifyMapId(mapId) {
  return String(mapId).replace(/_/g, "-");
}

function avatarVariantPatrolCases() {
  const configPath = path.resolve("configs/player_animations.json");
  if (!fs.existsSync(configPath)) {
    return [];
  }
  const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  return config.character_variants.flatMap((variant) => [
    avatarVariantPatrolCase(variant, "desktop", { width: 1280, height: 720 }, { x: 640, y: 421 }),
    avatarVariantPatrolCase(variant, "mobile-landscape", { width: 844, height: 390 }, { x: 422, y: 238 }),
  ]);
}

function avatarVariantPatrolCase(variant, device, viewport, loginClick) {
  return {
    name: `h5-${device}-avatar-variant-${String(variant.id).replace(/_/g, "-")}`,
    group: "avatar_variants",
    viewport,
    characterVariant: variant.id,
    avatarAction: "attack",
    avatarFacing: "right",
    exposureProbe: true,
    clearHoverBeforeScreenshot: device.includes("mobile"),
    loginClick,
  };
}

function avatarActionPatrolCases() {
  const walkDirections = ["down", "right", "up", "left"];
  const devices = [
    { id: "desktop", viewport: { width: 1280, height: 720 }, loginClick: { x: 640, y: 421 } },
    { id: "mobile-landscape", viewport: { width: 844, height: 390 }, loginClick: { x: 422, y: 238 } },
  ];
  const walkCases = devices.flatMap((device) => walkDirections.map((direction) => ({
    name: `h5-${device.id}-avatar-action-walk-${direction}`,
    group: "avatar_actions",
    viewport: device.viewport,
    characterVariant: "male_melee_v0",
    avatarAction: "walk",
    avatarFacing: direction,
    exposureProbe: true,
    clearHoverBeforeScreenshot: device.id.includes("mobile"),
    loginClick: device.loginClick,
  })));
  const emoteCases = devices.map((device) => ({
    name: `h5-${device.id}-avatar-action-emote`,
    group: "avatar_actions",
    viewport: device.viewport,
    characterVariant: "female_magic_v0",
    avatarAction: "emote",
    avatarFacing: "up",
    avatarEmote: "emote.laugh",
    exposureProbe: true,
    clearHoverBeforeScreenshot: device.id.includes("mobile"),
    loginClick: device.loginClick,
  }));
  const remoteCases = devices.map((device) => ({
    name: `h5-${device.id}-avatar-action-remote-sync`,
    group: "avatar_actions",
    viewport: device.viewport,
    remoteAvatar: "sample",
    exposureProbe: true,
    clearHoverBeforeScreenshot: device.id.includes("mobile"),
    loginClick: device.loginClick,
  }));
  return [...walkCases, ...emoteCases, ...remoteCases];
}

const NPC_AMBIENCE_PATROL_TARGETS = [
  { map: "city_port_market_v1", npc: "merchant", label: "port-market" },
  { map: "city_academy_plaza_v1", npc: "academy_registrar", label: "academy" },
  { map: "social_trade_market_v1", npc: "trade_broker", label: "trade-market" },
  { map: "life_fishing_riverbend_v1", npc: "fisher", label: "fishing-riverbend" },
];

function npcAmbiencePatrolCases() {
  return NPC_AMBIENCE_PATROL_TARGETS.flatMap((target) => [
    npcAmbiencePatrolCase(target, "desktop", { width: 1280, height: 720 }, { x: 640, y: 421 }),
    npcAmbiencePatrolCase(target, "mobile-landscape", { width: 844, height: 390 }, { x: 422, y: 238 }),
  ]);
}

function npcAmbiencePatrolCase(target, device, viewport, loginClick) {
  return {
    name: `h5-${device}-npc-ambience-${target.label}`,
    group: "npc_ambience",
    viewport,
    map: target.map,
    ambienceNpc: target.npc,
    exposureProbe: true,
    clearHoverBeforeScreenshot: device.includes("mobile"),
    loginClick,
  };
}

const CASES = [
  {
    name: "h5-desktop-login-character-preview",
    viewport: { width: 1280, height: 720 },
  },
  {
    name: "h5-desktop-world-base",
    viewport: { width: 1280, height: 720 },
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-desktop-npc-dialog",
    viewport: { width: 1280, height: 720 },
    npc: "event_guide",
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-desktop-first-session-reward",
    viewport: { width: 1280, height: 720 },
    firstSession: "complete",
    firstSessionRewardCoins: 30,
    loginClick: { x: 640, y: 421 },
  },
  ...generatedMapCases(),
  ...npcAmbiencePatrolCases(),
  ...avatarVariantPatrolCases(),
  ...avatarActionPatrolCases(),
  {
    name: "h5-desktop-inventory-panel",
    viewport: { width: 1280, height: 720 },
    loginClick: { x: 640, y: 421 },
    inventoryClick: { x: 1120, y: 668 },
  },
  {
    name: "h5-desktop-inventory-activity-rewards",
    viewport: { width: 1280, height: 720 },
    panel: "inventory",
    activityRewards: "sample",
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-desktop-map-panel",
    viewport: { width: 1280, height: 720 },
    panel: "map",
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-desktop-map-atlas",
    viewport: { width: 1280, height: 720 },
    panel: "map_atlas",
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-desktop-map-atlas-wilds-filter",
    viewport: { width: 1280, height: 720 },
    panel: "map_atlas",
    loginClick: { x: 640, y: 421 },
    mapAtlasWildClick: { x: 624, y: 292 },
  },
  {
    name: "h5-desktop-map-activity-progress",
    viewport: { width: 1280, height: 720 },
    panel: "map",
    activityRewards: "sample",
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-desktop-shop-panel",
    viewport: { width: 1280, height: 720 },
    panel: "shop",
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-desktop-trade-facility-panel",
    viewport: { width: 1280, height: 720 },
    map: "social_trade_market_v1",
    facility: "trade",
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-mobile-landscape-trade-facility-panel",
    viewport: { width: 844, height: 390 },
    map: "social_trade_market_v1",
    facility: "trade",
    loginClick: { x: 422, y: 238 },
  },
  {
    name: "h5-mobile-landscape-trade-price-keyboard-guard",
    viewport: { width: 844, height: 390 },
    map: "social_trade_market_v1",
    facility: "trade",
    tradeSeed: "activity_drop",
    loginClick: { x: 422, y: 238 },
    tradePriceInputClick: { x: 711, y: 181 },
    tradePriceText: "88",
    expectedFocusedInput: "trade_price",
  },
  {
    name: "h5-mobile-landscape-guild-facility-panel",
    viewport: { width: 844, height: 390 },
    map: "social_guild_garden_v1",
    facility: "guild",
    loginClick: { x: 422, y: 238 },
  },
  {
    name: "h5-desktop-mail-panel",
    viewport: { width: 1280, height: 720 },
    panel: "mail",
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-desktop-messages-panel",
    viewport: { width: 1280, height: 720 },
    panel: "messages",
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-desktop-private-messages-panel",
    viewport: { width: 1280, height: 720 },
    panel: "messages_private",
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-mobile-landscape-messages-panel",
    viewport: { width: 844, height: 390 },
    panel: "messages",
    loginClick: { x: 422, y: 238 },
    expectedOverlay: "mail",
  },
  {
    name: "h5-mobile-landscape-private-messages-panel",
    viewport: { width: 844, height: 390 },
    panel: "messages_private",
    loginClick: { x: 422, y: 238 },
    expectedOverlay: "private",
  },
  {
    name: "h5-mobile-landscape-private-keyboard-guard",
    viewport: { width: 844, height: 390 },
    panel: "messages_private",
    loginClick: { x: 422, y: 238 },
    privateInputClick: { x: 704, y: 309 },
    expectedFocusedInput: "private",
  },
  {
    name: "h5-desktop-notice-panel",
    viewport: { width: 1280, height: 720 },
    panel: "notice",
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-desktop-creator-panel",
    viewport: { width: 1280, height: 720 },
    panel: "creator",
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-mobile-landscape-creator-panel",
    viewport: { width: 844, height: 390 },
    panel: "creator",
    loginClick: { x: 422, y: 238 },
    expectedOverlay: "creator",
  },
  {
    name: "h5-desktop-room-panel",
    viewport: { width: 1280, height: 720 },
    loginClick: { x: 640, y: 421 },
    roomClick: { x: 1202, y: 668 },
  },
  {
    name: "h5-desktop-profile-card",
    viewport: { width: 1280, height: 720 },
    panel: "profile",
    characterVariant: "female_ranged_v0",
    loginClick: { x: 640, y: 421 },
    expectedOverlay: "profile",
  },
  {
    name: "h5-desktop-profile-report",
    viewport: { width: 1280, height: 720 },
    panel: "profile",
    characterVariant: "female_ranged_v0",
    loginClick: { x: 640, y: 421 },
    profileReportClick: { x: 1138, y: 302 },
    expectedOverlay: "profile",
  },
  {
    name: "h5-desktop-room-invite-chip",
    viewport: { width: 1280, height: 720 },
    panel: "room_invite",
    loginClick: { x: 640, y: 421 },
  },
  {
    name: "h5-desktop-room-emote",
    viewport: { width: 1280, height: 720 },
    loginClick: { x: 640, y: 421 },
    roomClick: { x: 1202, y: 668 },
    roomEmoteClick: { x: 1004, y: 210 },
  },
  {
    name: "h5-mobile-landscape-world-base",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 238 },
  },
  {
    name: "h5-mobile-landscape-hotspot-feedback",
    viewport: { width: 844, height: 390 },
    hotspot: "shop",
    loginClick: { x: 422, y: 238 },
  },
  {
    name: "h5-mobile-landscape-tap-move-feedback",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 238 },
    tapMoveClick: { x: 500, y: 275 },
    tapMoveWaitMs: 100,
  },
  {
    name: "h5-mobile-landscape-npc-dialog",
    viewport: { width: 844, height: 390 },
    npc: "event_guide",
    loginClick: { x: 422, y: 238 },
  },
  {
    name: "h5-mobile-landscape-login-character-preview",
    viewport: { width: 844, height: 390 },
  },
  {
    name: "h5-mobile-landscape-chat-keyboard-guard",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 238 },
    chatInputClick: { x: 300, y: 362 },
    expectedFocusedInput: "chat",
  },
  {
    name: "h5-mobile-landscape-map-button-panel",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 238 },
    mapClick: { x: 406, y: 36 },
    expectedOverlay: "map",
  },
  {
    name: "h5-mobile-landscape-mail-button-panel",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 238 },
    socialClick: { x: 784, y: 36 },
    expectedOverlay: "mail",
  },
  {
    name: "h5-mobile-landscape-emote-palette",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 238 },
    emoteClick: { x: 594, y: 363 },
    expectedOverlay: "emote",
  },
  {
    name: "h5-mobile-landscape-name-reveal",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 238 },
    avatarClick: { x: 422, y: 210 },
  },
  {
    name: "h5-mobile-landscape-attack-role-emote",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 238 },
    keyPress: "z",
    keyWaitMs: 180,
  },
  {
    name: "h5-mobile-landscape-inventory-panel",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 238 },
    inventoryClick: { x: 736, y: 363 },
    expectedOverlay: "inventory",
  },
  {
    name: "h5-mobile-landscape-inventory-activity-rewards",
    viewport: { width: 844, height: 390 },
    panel: "inventory",
    activityRewards: "sample",
    loginClick: { x: 422, y: 238 },
    expectedOverlay: "inventory",
  },
  {
    name: "h5-mobile-landscape-map-panel",
    viewport: { width: 844, height: 390 },
    panel: "map",
    loginClick: { x: 422, y: 238 },
    expectedOverlay: "map",
  },
  {
    name: "h5-mobile-landscape-map-atlas",
    viewport: { width: 844, height: 390 },
    panel: "map_atlas",
    loginClick: { x: 422, y: 238 },
    expectedOverlay: "map_atlas",
  },
  {
    name: "h5-mobile-landscape-map-atlas-wilds-filter",
    viewport: { width: 844, height: 390 },
    panel: "map_atlas",
    loginClick: { x: 422, y: 238 },
    mapAtlasWildClick: { x: 338, y: 159 },
    expectedOverlay: "map_atlas",
  },
  {
    name: "h5-mobile-landscape-room-panel",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 238 },
    roomClick: { x: 786, y: 363 },
    expectedOverlay: "room",
  },
  {
    name: "h5-mobile-landscape-room-keyboard-guard",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 238 },
    roomClick: { x: 786, y: 363 },
    roomInputClick: { x: 628, y: 171 },
    expectedOverlay: "room",
    expectedFocusedInput: "room",
  },
  {
    name: "h5-mobile-landscape-profile-card",
    viewport: { width: 844, height: 390 },
    panel: "profile",
    characterVariant: "female_ranged_v0",
    loginClick: { x: 422, y: 238 },
    expectedOverlay: "profile",
  },
  {
    name: "h5-mobile-landscape-profile-report",
    viewport: { width: 844, height: 390 },
    panel: "profile",
    characterVariant: "female_ranged_v0",
    loginClick: { x: 422, y: 238 },
    profileReportClick: { x: 785, y: 153 },
    expectedOverlay: "profile",
  },
  {
    name: "h5-liveops-960x540",
    viewport: { width: 960, height: 540 },
    route: "liveops_console",
  },
  {
    name: "h5-liveops-960x540-audit-scrolled",
    viewport: { width: 960, height: 540 },
    route: "liveops_console",
    wheelY: 900,
  },
  {
    name: "h5-liveops-375x240",
    viewport: { width: 375, height: 240 },
    route: "liveops_console",
  },
  {
    name: "h5-liveops-375x240-audit-scrolled",
    viewport: { width: 375, height: 240 },
    route: "liveops_console",
    liveopsTabClick: { x: 94, y: 68 },
    wheelY: 900,
  },
  {
    name: "h5-liveops-375x240-ops-tab",
    viewport: { width: 375, height: 240 },
    route: "liveops_console",
    liveopsTabClick: { x: 282, y: 68 },
  },
  {
    name: "h5-mobile-portrait-guard",
    viewport: { width: 390, height: 844 },
  },
  {
    name: "h5-desktop-housing-selected",
    viewport: { width: 1280, height: 720 },
    route: "home_edit",
    catalogClick: { x: 560, y: 650 },
    placeClick: { x: 520, y: 350 },
    selectPlacedClick: { x: 545, y: 374 },
  },
  {
    name: "h5-desktop-housing",
    viewport: { width: 1280, height: 720 },
    route: "home_edit",
    catalogClick: { x: 560, y: 650 },
    placeClick: { x: 520, y: 350 },
    selectPlacedClick: { x: 545, y: 374 },
    moveClick: { x: 620, y: 374 },
  },
  {
    name: "h5-mobile-landscape-housing-selected",
    viewport: { width: 844, height: 390 },
    route: "home_edit",
    catalogClick: { x: 300, y: 374 },
    placeClick: { x: 260, y: 190 },
    selectPlacedClick: { x: 276, y: 210 },
  },
  {
    name: "h5-mobile-landscape-housing",
    viewport: { width: 844, height: 390 },
    route: "home_edit",
    catalogClick: { x: 300, y: 374 },
    placeClick: { x: 260, y: 190 },
    selectPlacedClick: { x: 276, y: 210 },
    moveClick: { x: 305, y: 210 },
  },
  {
    name: "h5-desktop-minigame-host",
    viewport: { width: 1280, height: 720 },
    launchMinigame: "fishing",
    loginClick: { x: 640, y: 421 },
    castClick: { x: 360, y: 312 },
    expectSandboxTopBar: true,
  },
  {
    name: "h5-mobile-landscape-minigame-host",
    viewport: { width: 844, height: 390 },
    launchMinigame: "fishing",
    loginClick: { x: 422, y: 238 },
    castClick: { x: 232, y: 168 },
    expectSandboxTopBar: true,
  },
  ...(process.env.PSW_H5_INCLUDE_BACKEND_OPS === "1" ? [{
    name: "h5-liveops-960x540-backend-ops",
    viewport: { width: 960, height: 540 },
    route: "liveops_console",
    backgroundWorldClient: {
      viewport: { width: 960, height: 540 },
      loginClick: { x: 480, y: 313 },
    },
    adminToken: process.env.PSW_H5_ADMIN_TOKEN || "local-admin-token",
    adminTokenClick: { x: 420, y: 80 },
    adminRefreshClick: { x: 925, y: 80 },
    adminWaitMs: 8000,
    wheelY: 1400,
    scrollDrag: { from: { x: 956, y: 96 }, to: { x: 956, y: 500 } },
  }] : []),
];

const ignoredConsolePatterns = [
  /GL Driver Message.*ReadPixels/,
  /WebGL: CONTEXT_LOST_WEBGL/,
  /Virtual keyboard not supported by this display server/,
  /virtual_keyboard_get_height \(servers\/display\/display_server\.cpp:1121\)/,
];

function exposureProbePoints(viewport) {
  const sampleRows = [viewport.height - 150, viewport.height - 125]
    .map((y) => Math.max(1, Math.min(viewport.height - 1, Math.round(y))));
  const xRatios = [0.12, 0.28, 0.44, 0.6, 0.76, 0.92];
  const bottomProbe = sampleRows.flatMap((y, rowIndex) => xRatios.map((ratio, sampleIndex) => ({
    x: Math.round(viewport.width * ratio),
    y,
    label: `bottom-exposure-${rowIndex}-${sampleIndex}`,
  })));
  return [...bottomProbe, ...edgeExposureProbePoints(viewport)];
}

function edgeExposureProbePoints(viewport) {
  const yRatios = [0.34, 0.46, 0.58, 0.7];
  const columns = [
    { side: "left", ratios: [0.03, 0.06] },
    { side: "right", ratios: [0.94, 0.97] },
  ];
  return columns.flatMap(({ side, ratios }) => ratios.flatMap((xRatio, columnIndex) => yRatios.map((yRatio, rowIndex) => ({
    x: Math.round(viewport.width * xRatio),
    y: Math.round(viewport.height * yRatio),
    label: `edge-exposure-${side}-${columnIndex}-${rowIndex}`,
  }))));
}

function findExposureIssue(samples) {
  const rows = new Map();
  for (const sample of samples.filter((entry) => entry.label?.startsWith("bottom-exposure-"))) {
    const rowIndex = sample.label.split("-")[2];
    if (!rows.has(rowIndex)) {
      rows.set(rowIndex, []);
    }
    rows.get(rowIndex).push(sample);
  }
  for (const [rowIndex, rowSamples] of rows) {
    const issue = flatExposureIssue(rowSamples);
    if (issue) {
      return `bottom exposure probe row ${rowIndex}: ${issue}`;
    }
  }
  const columns = new Map();
  for (const sample of samples.filter((entry) => entry.label?.startsWith("edge-exposure-"))) {
    const [, , side, columnIndex] = sample.label.split("-");
    const key = `${side}-${columnIndex}`;
    if (!columns.has(key)) {
      columns.set(key, []);
    }
    columns.get(key).push(sample);
  }
  for (const [columnKey, columnSamples] of columns) {
    const issue = flatExposureIssue(columnSamples);
    if (issue) {
      return `side exposure probe column ${columnKey}: ${issue}`;
    }
  }
  return "";
}

function flatExposureIssue(samples) {
  const usable = samples.filter((sample) => !sample.error && sample.a >= 200);
  if (usable.length < 4) {
    return "";
  }
  const channelRanges = ["r", "g", "b"].map(
    (key) => Math.max(...usable.map((sample) => sample[key])) - Math.min(...usable.map((sample) => sample[key])),
  );
  const average = averageRgb(usable);
  const flatBand = channelRanges.reduce((sum, value) => sum + value, 0) < 42;
  const fallbackGreen = average.r >= 25 && average.r <= 55
    && average.g >= 70 && average.g <= 105
    && average.b >= 50 && average.b <= 85;
  const darkVoid = average.r < 28 && average.g < 32 && average.b < 38;
  if (flatBand && fallbackGreen) {
    return `flat green ground band ${formatRgb(average)}`;
  }
  if (flatBand && darkVoid) {
    return `flat dark void band ${formatRgb(average)}`;
  }
  return "";
}

function averageRgb(samples) {
  const total = samples.reduce((accumulator, sample) => ({
    r: accumulator.r + sample.r,
    g: accumulator.g + sample.g,
    b: accumulator.b + sample.b,
  }), { r: 0, g: 0, b: 0 });
  return {
    r: total.r / samples.length,
    g: total.g / samples.length,
    b: total.b / samples.length,
  };
}

function formatRgb(color) {
  return `rgb(${Math.round(color.r)}, ${Math.round(color.g)}, ${Math.round(color.b)})`;
}

const selectedCase = process.env.PSW_H5_CASE || "";
const selectedGroup = process.env.PSW_H5_GROUP || "";
const selectedNames = selectedCase.split(",").map((name) => name.trim()).filter(Boolean);
const activeCases = selectedNames.length > 0
  ? CASES.filter((testCase) => selectedNames.includes(testCase.name))
  : selectedGroup
    ? CASES.filter((testCase) => testCase.group === selectedGroup)
    : CASES;

if (selectedNames.length > 0 && activeCases.length !== selectedNames.length) {
  const foundNames = new Set(activeCases.map((testCase) => testCase.name));
  const missingNames = selectedNames.filter((name) => !foundNames.has(name));
  throw new Error(`No H5 smoke case named ${missingNames.join(", ")}`);
}
if (selectedGroup && activeCases.length === 0) {
  throw new Error(`No H5 smoke group named ${selectedGroup}`);
}

const playwright = await importPlaywright(process.env.PLAYWRIGHT_MODULE || DEFAULT_PLAYWRIGHT_MODULE, import.meta.url);
const browser = await playwright.chromium.launch({ headless: true });
const results = [];
const failures = [];

for (const testCase of activeCases) {
  process.stderr.write(`h5 case start: ${testCase.name}\n`);
  let backgroundContext = null;
  if (testCase.backgroundWorldClient) {
    backgroundContext = await browser.newContext({
      viewport: testCase.backgroundWorldClient.viewport,
      deviceScaleFactor: 1,
      isMobile: false,
    });
    const backgroundPage = await backgroundContext.newPage();
    await backgroundPage.goto(caseUrl(APP_URL, testCase.backgroundWorldClient), { waitUntil: "domcontentloaded" });
    await runCaseSteps(backgroundPage, testCase.backgroundWorldClient);
  }
  const context = await browser.newContext({
    viewport: testCase.viewport,
    deviceScaleFactor: 1,
    isMobile: testCase.name.includes("mobile"),
    hasTouch: testCase.name.includes("mobile"),
  });
  const page = await context.newPage();
  page.setDefaultTimeout(20000);
  page.setDefaultNavigationTimeout(30000);
  const messages = [];

  page.on("console", (message) => {
    if (message.type() !== "error" && message.type() !== "warning") {
      return;
    }
    const text = `${message.type()}: ${message.text()}`;
    if (!ignoredConsolePatterns.some((pattern) => pattern.test(text))) {
      messages.push(text);
    }
  });
  page.on("pageerror", (error) => messages.push(`pageerror: ${error.message}`));

  await page.goto(caseUrl(APP_URL, testCase), { waitUntil: "domcontentloaded" });
  await runCaseSteps(page, testCase);
  if (testCase.clearHoverBeforeScreenshot) {
    await page.mouse.move(2, 2);
    await page.waitForTimeout(250);
  }

  const canvasInfo = await page.evaluate(() => {
    const canvas = document.querySelector("canvas");
    if (!canvas) {
      return null;
    }
    return {
      width: canvas.width,
      height: canvas.height,
      cssWidth: canvas.clientWidth,
      cssHeight: canvas.clientHeight,
    };
  });
  const debugState = await page.evaluate(() => ({
    route: globalThis.__psw_debug_route || "",
    map: globalThis.__psw_debug_map || "",
    mapView: globalThis.__psw_debug_map_view || null,
    npcAmbience: globalThis.__psw_debug_npc_ambience || null,
    avatarVariant: globalThis.__psw_debug_avatar_variant || null,
    remoteAvatars: globalThis.__psw_debug_remote_avatars || null,
    facility: globalThis.__psw_debug_facility || "",
    npc: globalThis.__psw_debug_npc || "",
    hotspot: globalThis.__psw_debug_hotspot || "",
    hotspotRect: globalThis.__psw_debug_hotspot_rect || null,
    firstSessionRect: globalThis.__psw_debug_first_session_rect || null,
    firstSession: globalThis.__psw_debug_first_session || "",
    coinBalance: globalThis.__psw_debug_coin_balance ?? null,
    overlay: globalThis.__psw_debug_overlay || "",
    focusedInput: globalThis.__psw_debug_focused_input || "",
  }));
  const samplePoints = [
    ...(testCase.expectSandboxTopBar ? [{ x: 20, y: 20, label: "sandbox-top-bar" }] : []),
    ...(testCase.exposureProbe ? exposureProbePoints(testCase.viewport) : []),
  ];
  const canvasSamples = samplePoints.length > 0 ? await sampleCanvasPixels(page, samplePoints) : [];
  const screenshot = path.join(ARTIFACT_DIR, `${testCase.name}.png`);
  await page.screenshot({ path: screenshot, fullPage: true, timeout: 30000 });
  results.push({
    name: testCase.name,
    group: testCase.group || "",
    viewport: testCase.viewport,
    route: testCase.route || "",
    panel: testCase.panel || "",
    map: testCase.map || "",
    ambienceNpc: testCase.ambienceNpc || "",
    characterVariant: testCase.characterVariant || "",
    avatarAction: testCase.avatarAction || "",
    avatarFacing: testCase.avatarFacing || "",
    avatarEmote: testCase.avatarEmote || "",
    remoteAvatar: testCase.remoteAvatar || "",
    facility: testCase.facility || "",
    canvasInfo,
    debugState,
    messages,
    canvasSamples,
    screenshot,
  });
  if (!canvasInfo) {
    failures.push(`${testCase.name}: canvas not found`);
  }
  if (testCase.expectSandboxTopBar) {
    const sample = canvasSamples.find((entry) => entry.label === "sandbox-top-bar");
    if (!sample || sample.error) {
      failures.push(`${testCase.name}: sandbox top bar sample failed: ${sample?.error || "missing"}`);
    } else if (sample.r > 70 || sample.g > 80 || sample.b > 90 || sample.a < 200) {
      failures.push(
        `${testCase.name}: expected dark sandbox top bar, got rgba(${sample.r}, ${sample.g}, ${sample.b}, ${sample.a})`,
      );
    }
  }
  if (testCase.exposureProbe) {
    const exposureIssue = findExposureIssue(canvasSamples);
    if (exposureIssue) {
      failures.push(`${testCase.name}: ${exposureIssue}`);
    }
  }
  for (const message of messages) {
    failures.push(`${testCase.name}: ${message}`);
  }
  await context.close();
  if (backgroundContext) {
    await backgroundContext.close();
  }
  process.stderr.write(`h5 case done: ${testCase.name}\n`);
}

await browser.close();
console.log(JSON.stringify(results, null, 2));
if (failures.length > 0) {
  for (const failure of failures) {
    console.error(failure);
  }
  process.exit(1);
}
