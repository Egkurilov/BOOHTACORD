import type { TextMessage } from '../message_client'
import { chronologicalDatedMessages } from '../history_dates'
import { groupChronologicalMessages } from '../message_grouping'
import { historyRowGap, type HistoryRow } from './window'

export interface TimelineMessage extends HistoryRow { kind: 'message'; message: TextMessage; grouped: boolean }
export interface TimelineDate extends HistoryRow { kind: 'date'; dateTime: string; dateLabel: string; showStart: boolean }
export type TimelineEntry = TimelineMessage | TimelineDate

export function buildTimeline(messages: readonly TextMessage[], loaded: boolean, hasOlder: boolean, compact: boolean): TimelineEntry[] {
  const dated = groupChronologicalMessages(chronologicalDatedMessages(messages)), rows: TimelineEntry[] = []
  dated.forEach((entry, index) => {
    if (entry.dateLabel && entry.dateTime) {
      const date: TimelineDate = { key: `date:${entry.dateTime}`, kind: 'date', dateTime: entry.dateTime, dateLabel: entry.dateLabel,
        showStart: loaded && !hasOlder && index === 0, estimate: 24, gap: 0 }
      date.gap = historyRowGap('date', rows.at(-1), false, compact); rows.push(date)
    }
    const message: TimelineMessage = { key: `message:${entry.message.id}`, kind: 'message', message: entry.message, messageId: entry.message.id,
      grouped: entry.grouped, hasAttachments: entry.message.attachments.length > 0, estimate: 96, gap: 0 }
    message.gap = historyRowGap('message', rows.at(-1), entry.grouped, compact); rows.push(message)
  })
  return rows
}
