import path from "node:path";
import { caseUrl, importPlaywright, runCaseSteps, sampleCanvasPixels } from "./h5_smoke_helpers.mjs";

const DEFAULT_PLAYWRIGHT_MODULE = "../.tools/browser-smoke/node_modules/playwright/index.mjs";
const APP_URL = process.env.PSW_H5_URL || "http://127.0.0.1:18888/index.html";
const ARTIFACT_DIR = path.resolve(process.env.PSW_H5_ARTIFACT_DIR || ".tools/artifacts");
const CASES = [
  {
    name: "h5-desktop-world-base",
    viewport: { width: 1280, height: 720 },
    loginClick: { x: 640, y: 384 },
  },
  {
    name: "h5-desktop-inventory-panel",
    viewport: { width: 1280, height: 720 },
    loginClick: { x: 640, y: 384 },
    inventoryClick: { x: 1120, y: 668 },
  },
  {
    name: "h5-desktop-shop-panel",
    viewport: { width: 1280, height: 720 },
    panel: "shop",
    loginClick: { x: 640, y: 384 },
  },
  {
    name: "h5-desktop-mail-panel",
    viewport: { width: 1280, height: 720 },
    panel: "mail",
    loginClick: { x: 640, y: 384 },
  },
  {
    name: "h5-desktop-messages-panel",
    viewport: { width: 1280, height: 720 },
    panel: "messages",
    loginClick: { x: 640, y: 384 },
  },
  {
    name: "h5-desktop-private-messages-panel",
    viewport: { width: 1280, height: 720 },
    panel: "messages_private",
    loginClick: { x: 640, y: 384 },
  },
  {
    name: "h5-mobile-landscape-messages-panel",
    viewport: { width: 844, height: 390 },
    panel: "messages",
    loginClick: { x: 422, y: 209 },
  },
  {
    name: "h5-mobile-landscape-private-messages-panel",
    viewport: { width: 844, height: 390 },
    panel: "messages_private",
    loginClick: { x: 422, y: 209 },
  },
  {
    name: "h5-mobile-landscape-private-keyboard-guard",
    viewport: { width: 844, height: 390 },
    panel: "messages_private",
    loginClick: { x: 422, y: 209 },
    privateInputClick: { x: 690, y: 285 },
  },
  {
    name: "h5-desktop-notice-panel",
    viewport: { width: 1280, height: 720 },
    panel: "notice",
    loginClick: { x: 640, y: 384 },
  },
  {
    name: "h5-desktop-creator-panel",
    viewport: { width: 1280, height: 720 },
    panel: "creator",
    loginClick: { x: 640, y: 384 },
  },
  {
    name: "h5-desktop-room-panel",
    viewport: { width: 1280, height: 720 },
    loginClick: { x: 640, y: 384 },
    roomClick: { x: 1202, y: 668 },
  },
  {
    name: "h5-desktop-profile-card",
    viewport: { width: 1280, height: 720 },
    panel: "profile",
    loginClick: { x: 640, y: 384 },
  },
  {
    name: "h5-desktop-profile-report",
    viewport: { width: 1280, height: 720 },
    panel: "profile",
    loginClick: { x: 640, y: 384 },
    profileReportClick: { x: 1138, y: 302 },
  },
  {
    name: "h5-desktop-room-invite-chip",
    viewport: { width: 1280, height: 720 },
    panel: "room_invite",
    loginClick: { x: 640, y: 384 },
  },
  {
    name: "h5-desktop-room-emote",
    viewport: { width: 1280, height: 720 },
    loginClick: { x: 640, y: 384 },
    roomClick: { x: 1202, y: 668 },
    roomEmoteClick: { x: 832, y: 211 },
  },
  {
    name: "h5-mobile-landscape-world-base",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 209 },
  },
  {
    name: "h5-mobile-landscape-chat-keyboard-guard",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 209 },
    chatInputClick: { x: 300, y: 362 },
  },
  {
    name: "h5-mobile-landscape-name-reveal",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 209 },
    avatarClick: { x: 422, y: 210 },
  },
  {
    name: "h5-mobile-landscape-inventory-panel",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 209 },
    inventoryClick: { x: 750, y: 363 },
  },
  {
    name: "h5-mobile-landscape-room-panel",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 209 },
    roomClick: { x: 807, y: 363 },
  },
  {
    name: "h5-mobile-landscape-profile-card",
    viewport: { width: 844, height: 390 },
    panel: "profile",
    loginClick: { x: 422, y: 209 },
  },
  {
    name: "h5-mobile-landscape-profile-report",
    viewport: { width: 844, height: 390 },
    panel: "profile",
    loginClick: { x: 422, y: 209 },
    profileReportClick: { x: 785, y: 153 },
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
    loginClick: { x: 640, y: 384 },
    homeClick: { x: 1036, y: 668 },
    catalogClick: { x: 560, y: 650 },
    placeClick: { x: 520, y: 350 },
    selectPlacedClick: { x: 545, y: 374 },
  },
  {
    name: "h5-desktop-housing",
    viewport: { width: 1280, height: 720 },
    loginClick: { x: 640, y: 384 },
    homeClick: { x: 1036, y: 668 },
    catalogClick: { x: 560, y: 650 },
    placeClick: { x: 520, y: 350 },
    selectPlacedClick: { x: 545, y: 374 },
    moveClick: { x: 620, y: 374 },
  },
  {
    name: "h5-mobile-landscape-housing-selected",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 209 },
    homeClick: { x: 704, y: 363 },
    catalogClick: { x: 300, y: 374 },
    placeClick: { x: 260, y: 190 },
    selectPlacedClick: { x: 276, y: 210 },
  },
  {
    name: "h5-mobile-landscape-housing",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 209 },
    homeClick: { x: 704, y: 363 },
    catalogClick: { x: 300, y: 374 },
    placeClick: { x: 260, y: 190 },
    selectPlacedClick: { x: 276, y: 210 },
    moveClick: { x: 305, y: 210 },
  },
  {
    name: "h5-desktop-minigame-host",
    viewport: { width: 1280, height: 720 },
    loginClick: { x: 640, y: 384 },
    roomClick: { x: 1222, y: 668 },
    hostClick: { x: 910, y: 650 },
    castClick: { x: 330, y: 668 },
    expectSandboxTopBar: true,
  },
  {
    name: "h5-mobile-landscape-minigame-host",
    viewport: { width: 844, height: 390 },
    loginClick: { x: 422, y: 209 },
    roomClick: { x: 807, y: 363 },
    roomWaitMs: 4500,
    hostClick: { x: 648, y: 220 },
    hostClickConfirm: { x: 648, y: 220 },
    castClick: { x: 215, y: 363 },
    expectSandboxTopBar: true,
  },
  ...(process.env.PSW_H5_INCLUDE_BACKEND_OPS === "1" ? [{
    name: "h5-liveops-960x540-backend-ops",
    viewport: { width: 960, height: 540 },
    route: "liveops_console",
    backgroundWorldClient: {
      viewport: { width: 960, height: 540 },
      loginClick: { x: 480, y: 288 },
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
];
const selectedCase = process.env.PSW_H5_CASE || "";
const activeCases = selectedCase
  ? CASES.filter((testCase) => testCase.name === selectedCase)
  : CASES;

if (selectedCase && activeCases.length === 0) {
  throw new Error(`No H5 smoke case named ${selectedCase}`);
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
  const canvasSamples = testCase.expectSandboxTopBar
    ? await sampleCanvasPixels(page, [{ x: 20, y: 20, label: "sandbox-top-bar" }])
    : [];
  const screenshot = path.join(ARTIFACT_DIR, `${testCase.name}.png`);
  await page.screenshot({ path: screenshot, fullPage: true, timeout: 30000 });
  results.push({ name: testCase.name, canvasInfo, messages, canvasSamples, screenshot });
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
