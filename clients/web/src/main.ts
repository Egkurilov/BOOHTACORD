import { createApp } from 'vue'
import { createPinia } from 'pinia'

import App from './App.vue'
import { initializeTracing } from './telemetry/initialize_tracing'
import './style.css'
import { useUpdateStore } from './updates/update_store'

initializeTracing()
const pinia = createPinia()
const app = createApp(App).use(pinia)
const updates = useUpdateStore(pinia)
window.addEventListener('vite:preloadError', (event) => { event.preventDefault(); updates.reportPreloadError() })
app.mount('#app')
