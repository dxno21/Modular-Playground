import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

// Modul-Daten und Schemas liegen eine Ebene höher (gemeinsam mit Tool 1).
export default defineConfig({
  base: './',
  plugins: [react()],
  server: { fs: { allow: ['..'] } },
  test: { environment: 'node' },
});
