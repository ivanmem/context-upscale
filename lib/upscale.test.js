import { describe, it, expect, vi, beforeEach } from "vitest";

import { checkServerHealth, upscaleImage } from "./upscale.js";

describe("checkServerHealth", () => {
  beforeEach(() => {
    globalThis.fetch = vi.fn();
  });

  it("не выбрасывает ошибку при успешном ответе", async () => {
    globalThis.fetch.mockResolvedValue({ ok: true });

    await expect(checkServerHealth("http://localhost:7869")).resolves.toBeUndefined();
    expect(globalThis.fetch).toHaveBeenCalledWith("http://localhost:7869/health");
  });

  it("выбрасывает ошибку при недоступном сервере", async () => {
    globalThis.fetch.mockResolvedValue({ ok: false, status: 503 });

    await expect(checkServerHealth("http://localhost:7869"))
      .rejects.toThrow("Server not available (HTTP 503)");
  });
});

describe("upscaleImage", () => {
  beforeEach(() => {
    globalThis.fetch = vi.fn();
  });

  it("отправляет изображение и возвращает URL результата", async () => {
    const blob = new Blob(["fake-image-data"], { type: "image/png" });

    globalThis.fetch.mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ id: "abc123" }),
    });

    const result = await upscaleImage({
      serverUrl: "http://localhost:7869",
      imageBlob: blob,
    });

    expect(result).toEqual({ resultUrl: "http://localhost:7869/result/abc123" });
    expect(globalThis.fetch).toHaveBeenCalledWith(
      "http://localhost:7869/upscale",
      expect.objectContaining({ method: "POST" }),
    );
  });

  it("выбрасывает ошибку при пустом блобе", async () => {
    const emptyBlob = new Blob([], { type: "image/png" });

    await expect(
      upscaleImage({ serverUrl: "http://localhost:7869", imageBlob: emptyBlob }),
    ).rejects.toThrow("Image blob is empty");

    expect(globalThis.fetch).not.toHaveBeenCalled();
  });

  it("выбрасывает ошибку с detail из JSON-ответа сервера", async () => {
    const blob = new Blob(["data"], { type: "image/png" });

    globalThis.fetch.mockResolvedValue({
      ok: false,
      text: () => Promise.resolve(JSON.stringify({ detail: "Model not loaded" })),
    });

    await expect(
      upscaleImage({ serverUrl: "http://localhost:7869", imageBlob: blob }),
    ).rejects.toThrow("Model not loaded");
  });

  it("выбрасывает сырой текст при не-JSON ошибке сервера", async () => {
    const blob = new Blob(["data"], { type: "image/png" });

    globalThis.fetch.mockResolvedValue({
      ok: false,
      text: () => Promise.resolve("Internal Server Error"),
    });

    await expect(
      upscaleImage({ serverUrl: "http://localhost:7869", imageBlob: blob }),
    ).rejects.toThrow("Internal Server Error");
  });
});
