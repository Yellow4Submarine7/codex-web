import path from "node:path";
import {fileURLToPath} from "node:url";
import {defineConfig} from "vite";

const configDir = path.dirname(fileURLToPath(import.meta.url));
const preloadEntryPath = path.resolve(
  configDir,
  "scratch/asar/.vite/build/preload.js",
);
export default defineConfig({
  resolve: {
    alias: {
      electron: path.resolve(
          configDir,
          "src/bridge/electronModule.ts",
      ),
    },
  },
  build: {
    commonjsOptions: {
      include: [/scratch\/asar\/\.vite\/build\/preload\.js/, /node_modules/],
      requireReturnsDefault: "auto",
      transformMixedEsModules: true,
    },
    emptyOutDir: false,
    minify: false,
    outDir: "scratch/asar/webview/assets",
    sourcemap: true,
    lib: {
      entry: preloadEntryPath,
      fileName: () => "dev-bridge.js",
      formats: ["es"],
    },
    rollupOptions: {
      output: {
        entryFileNames: "dev-bridge.js",
      },
    },
  },
});
