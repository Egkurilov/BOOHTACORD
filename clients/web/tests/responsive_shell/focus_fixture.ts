import { createApp, h, ref } from 'vue'
import '../../src/style.css'
import { useWorkspaceDrawers } from '../../src/workspace/useWorkspaceDrawers'

const app = document.querySelector<HTMLDivElement>('#focus-app')
if (!app) throw new Error('Missing focus fixture root')

createApp({
  setup() {
    const activePanel = ref('none')
    const drawers = useWorkspaceDrawers(activePanel)
    return () => h('div', { class: 'app-frame' }, [
      h('div', { class: 'gc-shell' }, [
        h('aside', { class: ['sidebar', { 'is-open': drawers.navOpen.value }] }, [
          h('nav', {
            id: 'nav-sidebar',
            class: 'nav-drawer',
            style: { display: drawers.navOpen.value ? 'flex' : 'none' },
            role: drawers.modalDrawer.value === 'nav' ? 'dialog' : undefined,
            'aria-modal': drawers.modalDrawer.value === 'nav' ? 'true' : undefined,
            'aria-label': 'Навигация по каналам',
          }, [h('button', { class: 'channel-button', onClick: drawers.closeDrawersForNavigation }, 'Выбрать канал')]),
        ]),
        h('main', { id: 'main-region', tabindex: -1 }, [
          h('button', { class: 'workspace-header-toggle--nav', 'aria-label': 'Открыть навигацию', onClick: drawers.toggleNavigation }, 'Открыть навигацию'),
          h('button', { class: 'workspace-header-toggle--members', 'aria-label': 'Открыть участников', onClick: drawers.toggleMembers }, 'Открыть участников'),
          h('p', 'Канал: общий'),
        ]),
        h('aside', {
          id: 'members-panel',
          tabindex: -1,
          style: { display: drawers.membersOpen.value ? 'block' : 'none' },
          role: drawers.modalDrawer.value === 'members' ? 'dialog' : undefined,
          'aria-modal': drawers.modalDrawer.value === 'members' ? 'true' : undefined,
          'aria-label': 'Панель участников',
        }),
        h('aside', { id: 'search-aside-panel' }),
        h('button', {
          class: 'drawer-scrim',
          style: { display: drawers.navOpen.value || drawers.membersOpen.value ? 'block' : 'none' },
          'aria-label': 'Закрыть навигацию',
          onClick: drawers.closeDrawers,
        }),
      ]),
    ])
  },
}).mount(app)
