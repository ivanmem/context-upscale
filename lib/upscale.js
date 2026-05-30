/**
 * Чистая логика апскейла изображений через локальный GPU-сервер.
 * Не зависит от API браузера или расширения.
 */

/**
 * Проверяет доступность сервера апскейла.
 * @param {string} serverUrl
 */
export async function checkServerHealth(serverUrl) {
  const resp = await fetch(`${serverUrl}/health`);

  if (!resp.ok) {
    throw new Error(`Server not available (HTTP ${resp.status})`);
  }
}

/**
 * Отправляет изображение на апскейл и возвращает URL результата.
 * Изображение передаётся как binary data (multipart/form-data),
 * чтобы избежать двойной загрузки и проблем с RKN.
 *
 * @param {{ serverUrl: string, imageBlob: Blob, fileName?: string }} options
 * @returns {Promise<{ resultUrl: string }>}
 */
export async function upscaleImage({ serverUrl, imageBlob, fileName = "image.png" }) {
  if (imageBlob.size === 0) {
    throw new Error("Image blob is empty");
  }

  const formData = new FormData();
  formData.append("file", imageBlob, fileName);

  const resp = await fetch(`${serverUrl}/upscale`, {
    method: "POST",
    body: formData,
  });

  if (!resp.ok) {
    const errText = await resp.text();
    let detail = errText;

    try {
      detail = JSON.parse(errText).detail;
    } catch (_) {
      // Игнорируем ошибку парсинга, используем сырой текст
    }

    throw new Error(detail);
  }

  const { id } = await resp.json();

  return { resultUrl: `${serverUrl}/result/${id}` };
}
