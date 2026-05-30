import { describe, it, expect } from "vitest";

import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const manifest = JSON.parse(
  readFileSync(resolve(import.meta.dirname, "manifest.json"), "utf-8"),
);

describe("extension/manifest.json", () => {
  it("имеет корректный manifest_version", () => {
    expect(manifest.manifest_version).toBe(3);
  });

  it("содержит обязательные поля", () => {
    expect(manifest.name).toBeTruthy();
    expect(manifest.version).toMatch(/^\d+\.\d+\.\d+$/);
    expect(manifest.description).toBeTruthy();
  });

  it("имеет необходимые permissions", () => {
    expect(manifest.permissions).toContain("contextMenus");
  });

  it("указывает service_worker как background", () => {
    expect(manifest.background?.service_worker).toBe("background.js");
    expect(manifest.background?.type).toBe("module");
  });

  it("имеет content_scripts с matches", () => {
    expect(manifest.content_scripts).toBeDefined();
    expect(manifest.content_scripts[0].matches).toContain("<all_urls>");
  });

  it("host_permissions указывает на локальный сервер", () => {
    expect(manifest.host_permissions).toEqual(
      expect.arrayContaining([expect.stringContaining("127.0.0.1")]),
    );
  });
});
