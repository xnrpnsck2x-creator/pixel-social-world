import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const DEFAULT_PLAYWRIGHT_MODULE = "../.tools/browser-smoke/node_modules/playwright/index.mjs";
const URL = process.env.PSW_H5_URL || "http://127.0.0.1:18888/index.html";
const ARTIFACT_DIR = path.resolve(process.env.PSW_H5_ARTIFACT_DIR || ".tools/artifacts");

const ignoredConsolePatterns = [
  /GL Driver Message.*ReadPixels/,
  /WebGL: CONTEXT_LOST_WEBGL/,
];

const playwright = await importPlaywright();
const browser = await playwright.chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
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

await page.route("**/runtime_config.json", async (route) => {
  await route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify({
      schema_version: 1,
      maintenance: { enabled: true, message_key: "" },
      min_client_version: "0.1.0",
      web_build: "maintenance-smoke",
    }),
  });
});

await page.goto(URL, { waitUntil: "domcontentloaded" });
await page.waitForFunction(() => !!document.querySelector("canvas"));
await page.waitForTimeout(5500);

const screenshot = path.join(ARTIFACT_DIR, "h5-runtime-gate-maintenance.png");
await page.screenshot({ path: screenshot, fullPage: true });
const result = await page.evaluate(() => {
  const canvas = document.querySelector("canvas");
  if (!canvas) {
    return { canvasInfo: null, sample: null };
  }
  const buffer = document.createElement("canvas");
  buffer.width = canvas.width;
  buffer.height = canvas.height;
  const context = buffer.getContext("2d", { willReadFrequently: true });
  if (!context) {
    return { canvasInfo: null, sample: null };
  }
  context.drawImage(canvas, 0, 0);
  const data = context.getImageData(640, 440, 1, 1).data;
  return {
    canvasInfo: {
      width: canvas.width,
      height: canvas.height,
      cssWidth: canvas.clientWidth,
      cssHeight: canvas.clientHeight,
    },
    sample: { r: data[0], g: data[1], b: data[2], a: data[3] },
  };
});

await browser.close();

const failures = [];
if (!result.canvasInfo) {
  failures.push("canvas not found");
}
if (!result.sample || result.sample.r < 90 || result.sample.g < 70 || result.sample.b > 150 || result.sample.a < 200) {
  failures.push(`runtime gate panel sample did not look like the Image2 parchment panel: ${JSON.stringify(result.sample)}`);
}
for (const message of messages) {
  failures.push(message);
}

console.log(JSON.stringify({ ...result, screenshot, messages }, null, 2));
if (failures.length > 0) {
  for (const failure of failures) {
    console.error(failure);
  }
  process.exit(1);
}

async function importPlaywright() {
  const modulePath = process.env.PLAYWRIGHT_MODULE || DEFAULT_PLAYWRIGHT_MODULE;
  const baseDir = path.dirname(fileURLToPath(import.meta.url));
  const resolvedPath = path.resolve(baseDir, modulePath);
  return import(pathToFileURL(resolvedPath).href);
}
