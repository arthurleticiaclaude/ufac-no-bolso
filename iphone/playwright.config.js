import { defineConfig, devices } from '@playwright/test';

// Emula um iPhone no WebKit (motor do Safari) e testa o build de produção (com service worker).
export default defineConfig({
  testDir: './e2e',
  timeout: 30000,
  use: { ...devices['iPhone 15 Pro'], baseURL: 'http://localhost:4173', locale: 'pt-BR', timezoneId: 'America/Rio_Branco', serviceWorkers: 'allow' },
  projects: [{ name: 'iphone-webkit', use: { browserName: 'webkit' } }],
  workers: 1, // o Worker falso guarda o estado do login
  webServer: [
    { command: 'VITE_WORKER_URL=http://localhost:8787 VITE_GOOGLE_CLIENT_ID=cliente-teste npm run build -w web -- --outDir dist-e2e && npm run preview -w web -- --outDir dist-e2e', url: 'http://localhost:4173', reuseExistingServer: true, timeout: 120000 },
    { command: 'node e2e/worker-falso.mjs', url: 'http://localhost:8787/__reset', reuseExistingServer: false },
  ],
});
