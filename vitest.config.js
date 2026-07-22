import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'jsdom',
    globals: true,
    include: ['app/frontend/**/*.test.js', 'cloudflare/**/*.test.js'],
    setupFiles: ['app/frontend/test/setup.js'],
    coverage: {
      provider: 'v8',
      include: ['app/frontend/controllers/**/*.js', 'app/frontend/lib/**/*.js'],
      exclude: ['app/frontend/packs/**/*.js']
    }
  }
});
