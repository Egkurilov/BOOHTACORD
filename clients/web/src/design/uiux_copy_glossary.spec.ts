import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(...parts: string[]): string { return readFileSync(new URL(`../../../../${parts.join('/')}`, import.meta.url), 'utf8') }

describe('UI/UX copy glossary across clients', () => {
  it('calls channel groups sections in Web and Flutter navigation', () => {
    const web = source('clients/web/src/channel/ChannelNavigation.vue')
    const flutter = source('clients/flutter/lib/src/widgets/topology_actions/buttons.dart')

    expect(web).toContain('aria-label="Разделы и каналы"')
    expect(web).toContain('Создать канал в разделе')
    expect(flutter).toContain('Создать раздел или канал')
    expect(flutter).toContain('Создать канал в разделе')
    expect(web).not.toContain('Категории и каналы')
    expect(flutter).not.toContain('Создать категорию или канал')
  })

  it('uses the same section names for role permissions and audit actions', () => {
    const webRoles = source('clients/web/src/admin/role_permissions/AdminRolePermissions.vue')
    const flutterRoles = source('clients/flutter/lib/src/features/admin/role_permissions/lifecycle/context.dart')
    const webAudit = source('clients/web/src/admin/audit/audit_event_display.ts')
    const flutterAudit = source('clients/flutter/lib/src/features/admin/audit/event_labels/presentation.dart')

    expect(webRoles).toContain('Создавать разделы')
    expect(webRoles).toContain('Удалять пустые разделы')
    expect(flutterRoles).toContain('Создавать разделы')
    expect(flutterRoles).toContain('Удалять пустые разделы')
    expect(webAudit).toContain('Создан раздел')
    expect(flutterAudit).toContain('Создан раздел')
    expect(webAudit).not.toContain('Создана категория')
    expect(flutterAudit).not.toContain('Создана категория')
  })
})
