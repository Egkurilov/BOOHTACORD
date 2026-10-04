export interface EmojiEntry { emoji: string; name: string; group: string }
export const quickEmoji = ['😀', '👍', '🎮', '❤️', '🎉', '🤝'] as const

const groups: Record<string, string> = {
  'Лица': '😀 улыбка|😃 радость|😄 смех|😁 сияет|😆 смеётся|😅 неловко|🤣 хохот|😂 слёзы радости|🙂 приятно|🙃 наоборот|😉 подмигивание|😊 румянец|😇 ангел|🥰 влюблён|😍 глаза сердца|🤩 восторг|😘 поцелуй|😋 вкусно|😜 шутка|🤪 безумие|😎 круто|🥳 праздник|😏 ухмылка|😐 нейтрально|😑 без эмоций|😶 молчание|🤔 думаю|🤨 сомнение|😕 растерянность|🙁 грусть|😢 плач|😭 рыдания|😤 злость|😠 сердится|😡 ярость|😱 ужас|😴 сон|🤒 болеет|🤯 взрыв мозга',
  'Жесты': '👍 большой палец вверх|👍🏽 большой палец средний тон|👎 большой палец вниз|👏 аплодисменты|🙌 ура|👋 привет|🤝 рукопожатие|🙏 спасибо|👌 отлично|✌️ победа|🤞 удача|🤟 люблю|🤘 рок|💪 сила|🫶 сердце руками|👀 глаза',
  'Сердца': '❤️ красное сердце|🧡 оранжевое сердце|💛 жёлтое сердце|💚 зелёное сердце|💙 синее сердце|💜 фиолетовое сердце|🖤 чёрное сердце|🤍 белое сердце|💔 разбитое сердце|💕 два сердца|💖 сияющее сердце|💯 сто баллов',
  'Игры': '🎮 игра геймпад|🕹️ джойстик|🎲 кубик|♟️ шахматы|🎯 цель|🏆 кубок|🥇 медаль|⚽ футбол|🏀 баскетбол|🎸 гитара|🎧 наушники|🎵 музыка',
  'События': '🎉 конфетти праздник|🎊 праздник шар|🎂 день рождения|🎁 подарок|🎈 шарик|✨ искры|⭐ звезда|🔥 огонь|💥 взрыв|🌈 радуга|☀️ солнце|🌙 луна',
  'Природа': '🐈 кот|🐕 собака|🦊 лиса|🐻 медведь|🐼 панда|🐸 лягушка|🦄 единорог|🌻 подсолнух|🌷 тюльпан|🌳 дерево|🍀 клевер|🍕 пицца|🍔 бургер|☕ кофе',
  'Символы': '✅ готово|❌ нет|⚠️ внимание|❓ вопрос|❗ восклицание|💬 сообщение|📌 закреплено|🔔 уведомление|🔒 замок|🚀 ракета|💡 идея|📝 заметка',
}

export const emojiCatalog: EmojiEntry[] = Object.entries(groups).flatMap(([group, entries]) => entries.split('|').map((entry) => {
  const divider = entry.indexOf(' ')
  return { emoji: entry.slice(0, divider), name: entry.slice(divider + 1), group }
}))

export function searchEmoji(query: string, entries: EmojiEntry[] = emojiCatalog): EmojiEntry[] {
  const term = query.trim().toLocaleLowerCase('ru-RU')
  return term ? entries.filter(({ emoji, name, group }) => `${emoji} ${name} ${group}`.toLocaleLowerCase('ru-RU').includes(term)) : entries
}

export function mergeEmojiNames(entries: EmojiEntry[]): EmojiEntry[] {
  const russianNames = new Map(emojiCatalog.map(({ emoji, name }) => [emoji, name]))
  return entries.map((entry) => ({ ...entry, name: [russianNames.get(entry.emoji), entry.name].filter(Boolean).join(' · ') }))
}

export function updateRecentEmoji(current: string[], selected: string): string[] {
  return [selected, ...current.filter((emoji) => emoji !== selected)].slice(0, 12)
}
