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
  if (testCase.map) {
    target.searchParams.set("psw_map", testCase.map);
  }
  if (testCase.facility) {
    target.searchParams.set("psw_facility", testCase.facility);
  }
  if (testCase.npc) {
    target.searchParams.set("psw_npc", testCase.npc);
  }
  if (testCase.ambienceNpc) {
    target.searchParams.set("psw_ambience_npc", testCase.ambienceNpc);
  }
  if (testCase.characterVariant) {
    target.searchParams.set("psw_character_variant", testCase.characterVariant);
  }
  if (testCase.avatarAction) {
    target.searchParams.set("psw_avatar_action", testCase.avatarAction);
  }
  if (testCase.avatarFacing) {
    target.searchParams.set("psw_avatar_facing", testCase.avatarFacing);
  }
  if (testCase.avatarEmote) {
    target.searchParams.set("psw_avatar_emote", testCase.avatarEmote);
  }
  if (testCase.remoteAvatar) {
    target.searchParams.set("psw_remote_avatar", testCase.remoteAvatar);
  }
  if (testCase.hotspot) {
    target.searchParams.set("psw_hotspot", testCase.hotspot);
  }
  if (testCase.firstSession) {
    target.searchParams.set("psw_first_session", testCase.firstSession);
  }
  if (testCase.activityRewards) {
    target.searchParams.set("psw_activity_rewards", testCase.activityRewards);
  }
  if (testCase.tradeSeed) {
    target.searchParams.set("psw_trade_seed", testCase.tradeSeed);
  }
  if (testCase.launchMinigame) {
    target.searchParams.set("psw_launch_minigame", testCase.launchMinigame);
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
  if (testCase.map) {
    await page.waitForFunction((map) => globalThis.__psw_debug_map === map, testCase.map, { timeout: 5000 });
  }
  if (testCase.facility) {
    await page.waitForFunction((facility) => globalThis.__psw_debug_facility === facility, testCase.facility, { timeout: 5000 });
  }
  if (testCase.npc) {
    await page.waitForFunction((npc) => globalThis.__psw_debug_npc === npc, testCase.npc, { timeout: 5000 });
  }
  if (testCase.ambienceNpc) {
    await page.waitForFunction(
      (npc) => globalThis.__psw_debug_npc_ambience?.npc === npc && globalThis.__psw_debug_npc_ambience?.ok === true,
      testCase.ambienceNpc,
      { timeout: 7000 },
    );
  }
  if (testCase.characterVariant) {
    await page.waitForFunction(
      (variant) => globalThis.__psw_debug_avatar_variant?.variant === variant && globalThis.__psw_debug_avatar_variant?.ok === true,
      testCase.characterVariant,
      { timeout: 7000 },
    );
  }
  if (testCase.remoteAvatar) {
    await page.waitForFunction(
      () => globalThis.__psw_debug_remote_avatars?.ok === true,
      null,
      { timeout: 7000 },
    );
  }
  if (testCase.hotspot) {
    await page.waitForFunction(
      (hotspot) => globalThis.__psw_debug_hotspot === hotspot,
      testCase.hotspot,
      { timeout: testCase.hotspotTimeoutMs || 7000 },
    );
  }
  if (testCase.firstSession) {
    await page.waitForFunction(
      (expected) => globalThis.__psw_debug_first_session === expected.state
        && globalThis.__psw_debug_coin_balance === expected.coins,
      { state: testCase.firstSession, coins: testCase.firstSessionRewardCoins || 30 },
      { timeout: 5000 },
    );
  }
  if (testCase.expectedOverlay) {
    await page.waitForFunction((overlay) => globalThis.__psw_debug_overlay === overlay, testCase.expectedOverlay, { timeout: 5000 });
  }
  if (testCase.expectedFocusedInput) {
    await page.waitForFunction((input) => globalThis.__psw_debug_focused_input === input, testCase.expectedFocusedInput, { timeout: 5000 });
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
  if (testCase.keyPress) {
    await page.keyboard.press(testCase.keyPress);
    await page.waitForTimeout(testCase.keyWaitMs || 900);
  }
}

const DEBUG_RECT_GLOBALS = {
  hostClick: "__psw_debug_room_host_fishing_button_rect",
};

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
    ["mapClick", testCase.mapWaitMs || 2500],
    ["socialClick", testCase.socialWaitMs || 2500],
    ["mapAtlasWildClick", 900],
    ["npcClick", testCase.npcWaitMs || 1400],
    ["avatarClick", 900],
    ["tapMoveClick", testCase.tapMoveWaitMs || 450],
    ["emoteClick", testCase.emoteWaitMs || 900],
    ["roomClick", testCase.roomWaitMs || 2500],
    ["roomEmoteClick", 700],
    ["roomInputClick", 900],
    ["profileReportClick", 1600],
    ["chatInputClick", 900],
    ["chatSubmitClick", 1200],
    ["privateInputClick", 900],
    ["tradePriceInputClick", 900],
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
	const point = await stepPoint(page, key, testCase[key]);
	if (moveBefore) {
		await page.mouse.move(point.x, point.y);
		await page.waitForTimeout(500);
  }
  if (key === "tapMoveClick") {
    await page.touchscreen.tap(point.x, point.y);
  } else {
    await page.mouse.click(point.x, point.y);
  }
  if (key === "chatInputClick" && testCase.chatText) {
    await page.keyboard.press("ControlOrMeta+A");
    await page.keyboard.press("Backspace");
    await page.keyboard.type(testCase.chatText);
  }
  if (key === "tradePriceInputClick" && testCase.tradePriceText) {
    await page.keyboard.press("ControlOrMeta+A");
    await page.keyboard.press("Backspace");
    await page.keyboard.type(testCase.tradePriceText);
  }
  if (confirmKey && testCase[confirmKey]) {
    await page.waitForTimeout(1500);
    const confirm = testCase[confirmKey];
    await page.mouse.click(confirm.x, confirm.y);
  }
	await page.waitForTimeout(waitMs);
}

async function stepPoint(page, key, fallback) {
  const globalName = DEBUG_RECT_GLOBALS[key];
  if (!globalName) {
    return fallback;
  }
  const rect = await page.evaluate((name) => globalThis[name] || null, globalName);
  if (!rect || rect.width <= 2 || rect.height <= 2) {
    return fallback;
  }
  return {
    x: Math.round(rect.x + rect.width * 0.5),
    y: Math.round(rect.y + rect.height * 0.5),
  };
}
