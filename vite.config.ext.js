import { defineConfig } from "vite";
import { resolve } from "node:path";
import { copyFileSync, mkdirSync } from "node:fs";

/**
 * Vite-конфиг для сборки Chrome-расширения.
 * Собирает background.js и content.js как отдельные entry-points,
 * копирует manifest.json в выходную папку extension/dist.
 */

export default defineConfig({
  build: {
    outDir: resolve(__dirname, "extension/dist"),
    emptyOutDir: true,
    minify: false,
    rollupOptions: {
      input: {
        background: resolve(__dirname, "extension/background.js"),
        content: resolve(__dirname, "extension/content.js"),
      },
      output: {
        entryFileNames: "[name].js",
        chunkFileNames: "chunks/[name]-[hash].js",
        format: "es",
      },
    },
  },
  plugins: [
    {
      name: "copy-manifest",
      closeBundle() {
        const distDir = resolve(__dirname, "extension/dist");
        mkdirSync(distDir, { recursive: true });
        copyFileSync(
          resolve(__dirname, "extension/manifest.json"),
          resolve(distDir, "manifest.json"),
        );
      },
    },
  ],
});
