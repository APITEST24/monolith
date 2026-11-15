import { defineConfig } from "vite";

export default defineConfig({
  base: "/",
  build: {
    outDir: "dist",
    assetsDir: "assets",
    cssCodeSplit: false,
    sourcemap: false,
  },
  server: { port: 5173, strictPort: true },
});
