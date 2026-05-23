chrome.runtime.onMessage.addListener((msg) => {
  if (msg.type === "upscale-error") {
    showToast(msg.message, "#d32f2f");
  } else if (msg.type === "show-upscaled") {
    showUpscaledImage(msg.base64, msg.originalName);
  }
});

function showToast(text, bg) {
  const existing = document.getElementById("upscale-toast");
  if (existing) existing.remove();

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

function showUpscaledImage(base64, originalName) {
  // Replace entire page content with the upscaled image
  document.documentElement.innerHTML = `
    <head><title>Upscaled: ${originalName}</title>
    <style>
      body { margin: 0; background: #1a1a1a; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
      img { max-width: 100%; max-height: 100vh; object-fit: contain; }
    </style></head>
    <body><img src="data:image/png;base64,${base64}" alt="Upscaled"></body>
  `;
}
