export interface SearchDateRange { createdFrom?: string; createdBefore?: string }

function calendarDay(value: string): Date {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new Error('Выберите корректную дату.')
  const [year, month, day] = value.split('-').map(Number)
  // setFullYear avoids Date's special treatment of years 0..99.
  const date = new Date(0)
  date.setFullYear(year, month - 1, day)
  date.setHours(0, 0, 0, 0)
  if (year < 1 || date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
    throw new Error('Выберите корректную дату.')
  }
  return date
}

/** Date inputs include both selected calendar days in the browser's local zone. */
export function searchDateRange(from: string, to: string): SearchDateRange {
  const start = from ? calendarDay(from) : undefined
  const lastDay = to ? calendarDay(to) : undefined
  if (start && lastDay && start > lastDay) throw new Error('Дата окончания должна быть не раньше даты начала.')
  if (lastDay) {
    lastDay.setDate(lastDay.getDate() + 1)
    if (lastDay.getFullYear() > 9999) throw new Error('Выберите более раннюю дату окончания.')
  }
  return {
    ...(start ? { createdFrom: start.toISOString() } : {}),
    ...(lastDay ? { createdBefore: lastDay.toISOString() } : {}),
  }
}
