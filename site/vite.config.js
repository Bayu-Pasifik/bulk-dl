import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Served from https://bayu-pasifik.github.io/bulk-dl/
export default defineConfig({ base: '/bulk-dl/', plugins: [react()] });
