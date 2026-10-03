import js from '@eslint/js';
import globals from 'globals';

// Correctness rules only (eslint:recommended); formatting is left alone.
export default [
  {
    ignores: ['app/assets/builds/**', 'coverage/**', 'node_modules/**', 'public/**', 'tmp/**', 'vendor/**']
  },
  js.configs.recommended,
  {
    files: ['app/frontend/**/*.js'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: { ...globals.browser }
    }
  },
  {
    files: ['**/*.test.js', 'app/frontend/test/**/*.js'],
    languageOptions: {
      globals: { ...globals.node, ...globals.vitest }
    }
  },
  {
    files: ['cloudflare/**/*.js'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: { ...globals.serviceworker, ...globals.node }
    }
  },
  {
    // k6 load test scripts run in k6's own runtime.
    files: ['k6/**/*.js'],
    languageOptions: {
      sourceType: 'module',
      globals: { __ENV: 'readonly', __VU: 'readonly', __ITER: 'readonly', console: 'readonly' }
    }
  },
  {
    files: ['*.config.js', '*.config.mjs'],
    languageOptions: { sourceType: 'module', globals: { ...globals.node } }
  }
];
