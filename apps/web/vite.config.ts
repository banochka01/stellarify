import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";

/** Stamps dist/sw.js with a hash of the emitted bundle so each build gets fresh caches. */
function serviceWorkerVersion(): Plugin {
  let outDir = "dist";
  let buildId = "dev";
  return {
    name: "resonance-sw-version",
    apply: "build",
    configResolved(config) {
      outDir = resolve(config.root, config.build.outDir);
    },
    generateBundle(_options, bundle) {
      const hash = createHash("sha256");
      for (const name of Object.keys(bundle).sort()) hash.update(name);
      buildId = hash.digest("hex").slice(0, 12);
    },
    closeBundle() {
      const file = resolve(outDir, "sw.js");
      const source = readFileSync(file, "utf8");
      writeFileSync(file, source.replaceAll("__BUILD_ID__", buildId));
    }
  };
}

export default defineConfig({
  plugins: [react(), serviceWorkerVersion()],
  server: {
    host: "0.0.0.0",
    port: 5173,
    strictPort: true
  },
  clearScreen: false
});
