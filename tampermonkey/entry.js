/**
 * Точка входа для сборки Tampermonkey-скрипта через Vite.
 * Импортирует общую логику из lib/upscale.js без дублирования.
 */

import { upscaleImage } from "../lib/upscale.js";

const SERVER_URL = "http://127.0.0.1:7869";

// --- UI helpers (same as extension content.js) ---

function showToast(text, bg) {
  const existing = document.getElementById("upscale-toast");
  if (existing) {
    existing.remove();
  }

  const el = document.createElement("div");
  el.id = "upscale-toast";
  Object.assign(el.style, {
    position: "fixed",
    top: "16px",
    right: "16px",
    zIndex: "2147483647",
    background: bg || "#d32f2f",
    color: "#fff",
    padding: "12px 20px",
    borderRadius: "8px",
    fontSize: "14px",
    fontFamily: "system-ui, sans-serif",
    boxShadow: "0 4px 12px rgba(0,0,0,.3)",
    maxWidth: "450px",
    wordBreak: "break-word",
    cursor: "pointer",
    transition: "opacity .3s",
  });
  el.textContent = text;
  el.addEventListener("click", () => el.remove());
  document.body.appendChild(el);

  setTimeout(() => {
    el.style.opacity = "0";
    setTimeout(() => el.remove(), 300);
  }, 6000);
}

// --- Server health check via GM_xmlhttpRequest (bypasses CORS for localhost) ---

function gmCheckHealth() {
  return new Promise((resolve, reject) => {
    GM_xmlhttpRequest({
      method: "GET",
      url: `${SERVER_URL}/health`,
      timeout: 5000,
      onload: (resp) => {
        if (resp.status >= 200 && resp.status < 300) {
          resolve();
        } else {
          reject(new Error(`Server not available (HTTP ${resp.status})`));
        }
      },
      onerror: () => reject(new Error("Failed to fetch")),
      ontimeout: () => reject(new Error("Failed to fetch")),
    });
  });
}

async function imgToBlob(img) {
  try {
    const resp = await fetch(img.src);
    if (!resp.ok) {
      throw new Error(`HTTP ${resp.status}`);
    }
    return await resp.blob();
  } catch (e) {
    throw new Error(`Не удалось получить изображение: ${e.message}`);
  }
}

// --- Track last hovered image ---

let lastHoveredImg = null;
document.addEventListener("mouseover", (e) => {
  if (e.target instanceof HTMLImageElement && e.target.src) {
    lastHoveredImg = e.target;
  }
}, true);

// --- Menu command ---

GM_registerMenuCommand("Увеличить изображение под курсором", async () => {
  const img = lastHoveredImg;

  if (!img || !img.src) {
    showToast("⚠️ Увеличение: Наведите курсор на изображение перед вызовом команды", "#d32f2f");
    return;
  }

  try {
    await gmCheckHealth();

    const blob = await imgToBlob(img);

    if (!blob || blob.size === 0) {
      throw new Error("Fetched image is empty");
    }

    const { resultUrl } = await upscaleImage({
      serverUrl: SERVER_URL,
      imageBlob: blob,
    });

    GM_openInTab(resultUrl, { active: true, insert: true });
  } catch (err) {
    let message = err instanceof Error ? err.message : String(err);

    if (message.includes("Server not available") || message.includes("Failed to fetch")) {
      message = "Сервер увеличения не запущен. Запустите manage.bat start";
    }

    showToast("⚠️ Увеличение: " + message, "#d32f2f");
  }
});
