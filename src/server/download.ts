import { createReadStream } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import type { FastifyInstance } from "fastify";

type DownloadQuery = {
  path?: string;
};

function parseDownloadPath(query: unknown): string {
  if (!query || typeof query !== "object") {
    throw new Error("missing file path");
  }

  const rawPath = (query as DownloadQuery).path;
  if (typeof rawPath !== "string" || rawPath.trim().length === 0) {
    throw new Error("missing file path");
  }

  return path.resolve(rawPath);
}

function quoteHeaderValue(value: string): string {
  return value.replace(/["\\]/g, "\\$&");
}

export function contentDispositionForPath(filePath: string): string {
  return `attachment; filename="${quoteHeaderValue(path.basename(filePath))}"`;
}

export function registerDownloadRoute(app: FastifyInstance): void {
  app.get("/__backend/download", async (request, reply) => {
    let filePath: string;
    try {
      filePath = parseDownloadPath(request.query);
    } catch (error) {
      return reply.code(400).send({ error: errorMessage(error) });
    }

    const stat = await fs.stat(filePath).catch((error: unknown) => {
      throw Object.assign(new Error(errorMessage(error)), { statusCode: 404 });
    });

    if (!stat.isFile()) {
      return reply.code(400).send({ error: "path is not a file" });
    }

    return reply
      .header("content-disposition", contentDispositionForPath(filePath))
      .header("content-length", String(stat.size))
      .header("content-type", "application/octet-stream")
      .send(createReadStream(filePath));
  });
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}
