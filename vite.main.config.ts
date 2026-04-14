import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";

const configDir = path.dirname(fileURLToPath(import.meta.url));
const mainBuildDir = path.resolve(configDir, "scratch/asar/.vite/build");
const localBetterSqlite3Entry = path.resolve(
  configDir,
  "node_modules/better-sqlite3/lib/index.js",
);

function resolveMainEntryPath(): string {
  const candidates = fs
    .readdirSync(mainBuildDir)
    .filter((fileName) => /^main-.*\.js$/.test(fileName))
    .sort();

  if (candidates.length !== 1) {
    throw new Error(
      `Expected exactly one main-*.js in ${mainBuildDir}, found: ${candidates.join(", ") || "(none)"}`,
    );
  }

  return path.join(mainBuildDir, candidates[0]);
}

const mainEntryPath = resolveMainEntryPath();

export default defineConfig({
  resolve: {
    alias: {
      "better-sqlite3": localBetterSqlite3Entry,
      electron: path.resolve(configDir, "src/bridge/electronMainModule.ts"),
    },
  },
  build: {
    ssr: mainEntryPath,
    commonjsOptions: {
      include: [/scratch\/asar\/\.vite\/build\/main-.*\.js/, /node_modules/],
      requireReturnsDefault: "auto",
      transformMixedEsModules: true,
    },
    emptyOutDir: false,
    minify: false,
    outDir: mainBuildDir,
    sourcemap: true,
    rollupOptions: {
      external: [/node_modules\/better-sqlite3\/lib\/index\.js$/],
      output: {
        entryFileNames: "dev-main.js",
        format: "cjs",
      },
    },
  },
});
