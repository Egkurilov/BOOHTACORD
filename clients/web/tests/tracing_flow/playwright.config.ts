import config from '../delivery_uncertainty/playwright.config'
import { defineConfig } from '@playwright/test'
export default defineConfig({...config,testDir:'.',timeout:150000,
 outputDir:'../../../../.out/tracing-browser-results',projects:[{name:'chromium',use:{viewport:{width:1440,height:900}}}],
 webServer:{...config.webServer as object,url:'http://127.0.0.1:4807/tests/tracing_flow/fixture.html'},
})
