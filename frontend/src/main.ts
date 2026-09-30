import { createApp } from 'vue'
import { createPinia } from 'pinia'

import App from './App.vue'
import { initializeTracing } from './telemetry/initialize_tracing'
import './style.css'

initializeTracing()
createApp(App).use(createPinia()).mount('#app')
