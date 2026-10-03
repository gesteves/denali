import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Two environments, because the two kinds of JS in this repo don't run in the same place.
    // The frontend needs jsdom and the browser mocks in test/setup.js; the Cloudflare Workers
    // need node, whose Request/Response behave like workerd's — jsdom's Request silently drops
    // the method and headers of a Request passed as init, which the Workers rely on.
    projects: [
      {
        test: {
          name: 'frontend',
          environment: 'jsdom',
          globals: true,
          include: ['app/frontend/**/*.test.js'],
          setupFiles: ['app/frontend/test/setup.js']
        }
      },
      {
        test: {
          name: 'workers',
          environment: 'node',
          globals: true,
          include: ['cloudflare/**/*.test.js']
        }
      }
    ],
    coverage: {
      provider: 'v8',
      include: ['app/frontend/controllers/**/*.js', 'app/frontend/lib/**/*.js', 'app/frontend/observers/**/*.js'],
      exclude: ['app/frontend/packs/**/*.js', '**/*.test.js'],
      // A little under where coverage stands, so `npm run test:coverage` fails
      // when new code arrives untested rather than letting it drift.
      thresholds: {
        statements: 95,
        branches: 85,
        functions: 90,
        lines: 95
      }
    }
  }
});
