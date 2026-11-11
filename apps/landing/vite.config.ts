import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Dev and preview read release data (version, changelog, installer sizes) from the local API server (npm run dev:server) unless RESONANCE_API_URL points elsewhere.
const api = process.env.RESONANCE_API_URL ?? "http://localhost:8787";
const proxy = {
  "/api": { target: api, changeOrigin: true },
  "/downloads": { target: api, changeOrigin: true }
};

export default defineConfig({
  plugins: [react()],
  server: {
    host: "0.0.0.0",
    port: 4173,
    strictPort: true,
    allowedHosts: ["terminal.local"],
    proxy
  },
  preview: { proxy },
  clearScreen: false
});
