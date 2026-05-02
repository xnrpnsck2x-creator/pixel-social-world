import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export async function importPlaywright(modulePath, metaUrl) {
  const baseDir = path.dirname(fileURLToPath(metaUrl));
  const resolvedPath = path.resolve(baseDir, modulePath);
  return import(pathToFileURL(resolvedPath).href);
}

export function caseUrl(appUrl, testCase) {
  const target = new URL(appUrl);
  if (testCase.route) {
    target.searchParams.set("psw_route", testCase.route);
  }
  if (testCase.panel) {
    target.searchParams.set("psw_panel", testCase.panel);
  }
  return target.href;
}

export async function runCaseSteps(page, testCase) {
  await page.waitForFunction(() => !!document.querySelector("canvas"));
  await page.waitForTimeout(4500);
  if (testCase.route) {
    await page.waitForFunction((route) => globalThis.__psw_debug_route === route, testCase.route, { timeout: 5000 });
  }
  for (const step of interactionSteps(testCase)) {
    await runStep(page, testCase, step);
  }
  if (testCase.adminToken) {
    await page.mouse.click(testCase.adminTokenClick.x, testCase.adminTokenClick.y);
    await page.keyboard.press("ControlOrMeta+A");
    await page.keyboard.press("Backspace");
    await page.keyboard.type(testCase.adminToken);
    await page.waitForTimeout(250);
    await page.mouse.click(testCase.adminRefreshClick.x, testCase.adminRefreshClick.y);
    await page.waitForTimeout(testCase.adminWaitMs || 6000);
  }
  if (testCase.wheelY) {
    await page.mouse.move(testCase.viewport.width * 0.5, testCase.viewport.height * 0.5);
    await page.mouse.wheel(0, testCase.wheelY);
    await page.waitForTimeout(1000);
  }
  if (testCase.scrollDrag) {
    await page.mouse.move(testCase.scrollDrag.from.x, testCase.scrollDrag.from.y);
    await page.mouse.down();
    await page.mouse.move(testCase.scrollDrag.to.x, testCase.scrollDrag.to.y, { steps: 8 });
    await page.mouse.up();
    await page.waitForTimeout(1000);
  }
}

export async function sampleCanvasPixels(page, points) {
  return page.evaluate((samplePoints) => {
    const canvas = document.querySelector("canvas");
    if (!canvas) {
      return samplePoints.map((point) => ({ ...point, error: "canvas not found" }));
    }
    const buffer = document.createElement("canvas");
    buffer.width = canvas.width;
    buffer.height = canvas.height;
    const context = buffer.getContext("2d", { willReadFrequently: true });
    if (!context) {
      return samplePoints.map((point) => ({ ...point, error: "2d context unavailable" }));
    }
    try {
      context.drawImage(canvas, 0, 0);
      return samplePoints.map((point) => {
        const data = context.getImageData(point.x, point.y, 1, 1).data;
        return { ...point, r: data[0], g: data[1], b: data[2], a: data[3] };
      });
    } catch (error) {
      return samplePoints.map((point) => ({ ...point, error: String(error) }));
    }
  }, points);
}

function interactionSteps(testCase) {
  return [
    ["loginClick", 3500],
    ["avatarClick", 900],
    ["roomClick", testCase.roomWaitMs || 2500],
    ["roomEmoteClick", 700],
    ["profileReportClick", 1600],
    ["chatInputClick", 900],
    ["privateInputClick", 900],
    ["inventoryClick", 2500],
    ["homeClick", 3000],
    ["catalogClick", 500],
    ["placeClick", 1000, true],
    ["selectPlacedClick", 500],
    ["moveClick", 1000],
    ["liveopsTabClick", 900],
    ["hostClick", 4500, false, "hostClickConfirm"],
    ["castClick", 2500],
  ].filter(([key]) => testCase[key]);
}

async function runStep(page, testCase, step) {
  const [key, waitMs, moveBefore, confirmKey] = step;
  const point = testCase[key];
  if (moveBefore) {
    await page.mouse.move(point.x, point.y);
    await page.waitForTimeout(500);
  }
  await page.mouse.click(point.x, point.y);
  if (confirmKey && testCase[confirmKey]) {
    await page.waitForTimeout(1500);
    const confirm = testCase[confirmKey];
    await page.mouse.click(confirm.x, confirm.y);
  }
  await page.waitForTimeout(waitMs);
}
