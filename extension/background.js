import { checkServerHealth, upscaleImage } from "../lib/upscale.js";

const SERVER_URL = "http://127.0.0.1:7869";

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "upscale-image",
    title: "Апскейлнуть",
    contexts: ["image"],
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== "upscale-image" || !info.srcUrl) {
    return;
  }

  try {
    await checkServerHealth(SERVER_URL);

    const imgResp = await fetch(info.srcUrl);

    if (!imgResp.ok) {
      throw new Error(`Failed to fetch image: HTTP ${imgResp.status}`);
    }

    const blob = await imgResp.blob();
    const { resultUrl } = await upscaleImage({
      serverUrl: SERVER_URL,
      imageBlob: blob,
    });

    chrome.tabs.create({ url: resultUrl, index: tab.index + 1 });
  } catch (err) {
    let message = err instanceof Error ? err.message : String(err);

    if (message.includes("Server not available") || message.includes("Failed to fetch")) {
      message = "Сервер апскейла не запущен. Запустите server/start.bat";
    }

    chrome.tabs.sendMessage(tab.id, { type: "upscale-error", message: "⚠️ Апскейл: " + message });
  }
});
