import { defineConfig } from "vite";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

/**
 * Vite-конфиг для сборки Tampermonkey-скрипта.
 * Собирает entry.js + lib/upscale.js в один IIFE-файл
 * и добавляет UserScript-заголовок.
 */

const USERSCRIPT_HEADER = `// ==UserScript==
// @name         Увеличить изображение
// @namespace    context-upscale
// @version      1.0.0
// @description  Увеличение изображений через контекстное меню Tampermonkey с помощью локального GPU-сервера
// @match        *://*/*
// @grant        GM_registerMenuCommand
// @grant        GM_xmlhttpRequest
// @grant        GM_openInTab
// @connect      127.0.0.1
// @run-at       document-idle
// ==/UserScript==
`;

export default defineConfig({
  build: {
    lib: {
      entry: resolve(__dirname, "tampermonkey/entry.js"),
      name: "UpscaleTM",
      formats: ["iife"],
      fileName: () => "upscale.user.js",
    },
    outDir: resolve(__dirname, "tampermonkey/dist"),
    emptyOutDir: true,
    minify: false,
  },
  plugins: [
    {
      name: "userscript-header",
      generateBundle(_, bundle) {
        for (const chunk of Object.values(bundle)) {
          if (chunk.type === "chunk" && chunk.fileName === "upscale.user.js") {
            chunk.code = USERSCRIPT_HEADER + "\n" + chunk.code;
          }
        }
      },
    },
  ],
});
