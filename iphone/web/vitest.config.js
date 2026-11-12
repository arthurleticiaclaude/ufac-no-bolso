import { defineConfig } from 'vitest/config';

// jsdom, como o Safari: o DOMParser não roda scripts nem baixa nada das páginas lidas.
export default defineConfig({
  test: { environment: 'jsdom', include: ['test/**/*.test.js'] },
});
