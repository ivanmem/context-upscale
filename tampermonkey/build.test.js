import { describe, it, expect } from "vitest";

import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const distPath = resolve(import.meta.dirname, "dist", "upscale.user.js");

describe("tampermonkey build output", () => {
  it("файл сборки существует (запустите npm run build:tm)", () => {
    expect(existsSync(distPath)).toBe(true);
  });

  it("содержит UserScript-заголовок", () => {
    if (!existsSync(distPath)) return;

    const content = readFileSync(distPath, "utf-8");

    expect(content).toContain("// ==UserScript==");
    expect(content).toContain("// ==/UserScript==");
  });

  it("содержит необходимые @grant директивы", () => {
    if (!existsSync(distPath)) return;

    const content = readFileSync(distPath, "utf-8");

    expect(content).toContain("@grant        GM_registerMenuCommand");
    expect(content).toContain("@grant        GM_xmlhttpRequest");
    expect(content).toContain("@grant        GM_openInTab");
  });

  it("содержит код из lib/upscale.js (не дублирование)", () => {
    if (!existsSync(distPath)) return;

    const content = readFileSync(distPath, "utf-8");

    // upscaleImage из lib/upscale.js должна присутствовать в сборке
    // checkServerHealth не включается — entry.js использует gmCheckHealth вместо неё
    expect(content).toContain("upscaleImage");
  });
});
