import { describe, expect, it } from 'vitest'
import { readScreenProfilePreference, saveScreenProfilePreference, screenProfileMode, screenSampleAge, screenShareLayerBudget } from './profile'

function storage() {
  const values = new Map<string, string>()
  return {
    values,
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => { values.set(key, value) },
  }
}

describe('screen profile intent and diagnostics labels', () => {
  it('maps the motion/text scenarios to supported legacy profile rates', () => {
    expect(screenProfileMode('P1080_60')).toBe('motion')
    expect(screenProfileMode('P1440_30')).toBe('text')
  })

  it('adds the simulcast layer caps and labels the result as an estimate input', () => {
    expect(screenShareLayerBudget('P1080_60')).toEqual({ primaryBps: 8_000_000, secondaryBps: 500_000, totalBps: 8_500_000 })
  })

  it('scopes profile preferences by account and origin and ignores corrupt values', () => {
    const store = storage()
    saveScreenProfilePreference(store, 'https://one.example', 'account-a', 'P720_60')
    saveScreenProfilePreference(store, 'https://two.example', 'account-a', 'P1080_30')
    saveScreenProfilePreference(store, 'https://one.example', 'account-b', 'P1440_30')
    expect(readScreenProfilePreference(store, 'https://one.example', 'account-a')).toBe('P720_60')
    expect(readScreenProfilePreference(store, 'https://two.example', 'account-a')).toBe('P1080_30')
    expect(readScreenProfilePreference(store, 'https://one.example', 'account-b')).toBe('P1440_30')
    store.setItem('boohtacord.screen-share.v1:https%3A%2F%2Fone.example:account-a', 'P999_60')
    expect(readScreenProfilePreference(store, 'https://one.example', 'account-a')).toBeUndefined()
  })

  it('reports sample freshness without presenting old receiver data as current', () => {
    expect(screenSampleAge(null, 20_000)).toBe('Нет свежих данных')
    expect(screenSampleAge(19_000, 20_000)).toBe('Обновлено только что')
    expect(screenSampleAge(10_000, 20_000)).toBe('Обновлено 10 с назад')
    expect(screenSampleAge(1_000, 20_000)).toBe('Данные устарели · 19 с назад')
  })
})
