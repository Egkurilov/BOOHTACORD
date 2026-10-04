const avatarDimension = 128
const maxAvatarBytes = 2 * 1024 * 1024
const maxAvatarSourceDimension = 4096

export async function normalizeAvatarImage(file: File): Promise<Blob> {
  if (!['image/png', 'image/jpeg'].includes(file.type) || file.size === 0 || file.size > maxAvatarBytes) {
    throw new Error('Выберите PNG или JPEG до 2 MiB.')
  }

  let bitmap: ImageBitmap
  try {
    bitmap = await createImageBitmap(file)
  } catch {
    throw new Error('Не удалось прочитать изображение.')
  }

  try {
    if (bitmap.width < 1 || bitmap.height < 1 || bitmap.width > maxAvatarSourceDimension || bitmap.height > maxAvatarSourceDimension) {
      throw new Error('Размер изображения слишком большой.')
    }
    const side = Math.min(bitmap.width, bitmap.height)
    const sourceX = Math.floor((bitmap.width - side) / 2)
    const sourceY = Math.floor((bitmap.height - side) / 2)
    const canvas = document.createElement('canvas')
    canvas.width = avatarDimension
    canvas.height = avatarDimension
    const context = canvas.getContext('2d')
    if (!context) throw new Error('Не удалось обработать изображение.')
    context.drawImage(bitmap, sourceX, sourceY, side, side, 0, 0, avatarDimension, avatarDimension)

    const normalized = await new Promise<Blob>((resolve, reject) => {
      canvas.toBlob((blob) => blob ? resolve(blob) : reject(new Error('Не удалось обработать изображение.')), 'image/png')
    })
    if (normalized.size === 0 || normalized.size > maxAvatarBytes) throw new Error('Не удалось обработать изображение.')
    return normalized
  } finally {
    bitmap.close()
  }
}
