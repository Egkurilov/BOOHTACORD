import type { Ref } from 'vue'

export async function copyAdminResetLink(
  url: string,
  writeText: (value: string) => Promise<void>,
  status: Ref<string | null>,
  error: Ref<string | null>,
): Promise<void> {
  status.value = null
  error.value = null
  try { await writeText(url); status.value = 'Одноразовая ссылка скопирована.' }
  catch { error.value = 'Не удалось скопировать ссылку. Скопируйте её из поля вручную.' }
}
