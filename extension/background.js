const SERVER_URL = "http://127.0.0.1:7869";

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "upscale-image",
    title: "Апскейлнуть",
    contexts: ["image"],
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== "upscale-image" || !info.srcUrl) return;

  try {
    const healthResp = await fetch(`${SERVER_URL}/health`);
    if (!healthResp.ok) throw new Error(`Server not available (HTTP ${healthResp.status})`);

    const imgResp = await fetch(info.srcUrl);
    if (!imgResp.ok) throw new Error(`Failed to fetch image: HTTP ${imgResp.status}`);
    const blob = await imgResp.blob();
    if (blob.size === 0) throw new Error("Fetched image is empty");

    const formData = new FormData();
    formData.append("file", blob, "image.png");

    const upscaleResp = await fetch(`${SERVER_URL}/upscale`, {
      method: "POST",
      body: formData,
    });

    if (!upscaleResp.ok) {
      const errText = await upscaleResp.text();
      let detail = errText;
      try { detail = JSON.parse(errText).detail; } catch (_) {}
      throw new Error(detail);
    }

    const { id } = await upscaleResp.json();
    chrome.tabs.create({ url: `${SERVER_URL}/result/${id}`, index: tab.index + 1 });
  } catch (err) {
    let message = err.message || String(err);
    if (message.includes("Server not available") || message.includes("Failed to fetch")) {
      message = "Сервер апскейла не запущен. Запустите server/start.bat";
    }
    chrome.tabs.sendMessage(tab.id, { type: "upscale-error", message: "⚠️ Апскейл: " + message });
  }
});
