import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import Fastify from "fastify";
import { registerDownloadRoute } from "../src/server/download.js";

test("download route streams a requested file with attachment headers", async () => {
  const tmp = await mkdtemp(path.join(os.tmpdir(), "codex-web-download-test-"));
  const filePath = path.join(tmp, "sample report.txt");
  await writeFile(filePath, "hello download", "utf8");

  const app = Fastify({ logger: false });
  registerDownloadRoute(app);

  try {
    const response = await app.inject({
      method: "GET",
      url: `/__backend/download?path=${encodeURIComponent(filePath)}`,
    });

    assert.equal(response.statusCode, 200);
    assert.equal(response.payload, "hello download");
    assert.match(
      response.headers["content-disposition"],
      /attachment; filename="sample report\.txt"/,
    );
  } finally {
    await app.close();
    await rm(tmp, { force: true, recursive: true });
  }
});

test("download route rejects missing paths", async () => {
  const app = Fastify({ logger: false });
  registerDownloadRoute(app);

  try {
    const response = await app.inject({
      method: "GET",
      url: "/__backend/download",
    });

    assert.equal(response.statusCode, 400);
  } finally {
    await app.close();
  }
});
