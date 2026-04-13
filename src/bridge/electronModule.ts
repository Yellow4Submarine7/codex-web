/* eslint-disable no-console */

type IpcListener = (event: unknown, ...args: unknown[]) => void;

type SharedObjectSetMessage = {
  key: string;
  type: "shared-object-set";
  value: unknown;
};

const LOG_PREFIX = "[electron-stub]";

const getSentryInitOptionsChannel = "codex_desktop:get-sentry-init-options";
const getBuildFlavorChannel = "codex_desktop:get-build-flavor";
const getSystemThemeVariantChannel = "codex_desktop:get-system-theme-variant";
const getSharedObjectSnapshotChannel =
  "codex_desktop:get-shared-object-snapshot";
const getFastModeRolloutMetricsChannel =
  "codex_desktop:get-fast-mode-rollout-metrics";
const viewToMainMessageChannel = "codex_desktop:message-from-view";
const mainToViewMessageChannel = "codex_desktop:message-for-view";

function log(method: string, payload?: unknown): void {
  if (payload === undefined) {
    console.info(`${LOG_PREFIX} ${method}`);
    return;
  }
  console.info(`${LOG_PREFIX} ${method}`, payload);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isSharedObjectSetMessage(
  value: unknown,
): value is SharedObjectSetMessage {
  return (
    isRecord(value) &&
    value.type === "shared-object-set" &&
    typeof value.key === "string"
  );
}

function workerMessageForViewChannel(workerName: string): string {
  return `codex_desktop:worker:${workerName}:for-view`;
}

function workerNameFromFromViewChannel(channel: string): string | null {
  const match = channel.match(/^codex_desktop:worker:(.+):from-view$/);
  if (!match) {
    return null;
  }
  return match[1];
}

class IpcRendererStub {
  private readonly listenersByChannel = new Map<string, Set<IpcListener>>();
  private readonly sharedObjectSnapshot: Record<string, unknown> = {};

  on(channel: string, listener: IpcListener): this {
    debugger;
    log("ipcRenderer.on", { channel });
    let listeners = this.listenersByChannel.get(channel);
    if (!listeners) {
      listeners = new Set<IpcListener>();
      this.listenersByChannel.set(channel, listeners);
    }
    listeners.add(listener);
    return this;
  }

  removeListener(channel: string, listener: IpcListener): this {
    debugger;
    log("ipcRenderer.removeListener", { channel });
    const listeners = this.listenersByChannel.get(channel);
    if (!listeners) {
      return this;
    }
    listeners.delete(listener);
    if (listeners.size === 0) {
      this.listenersByChannel.delete(channel);
    }
    return this;
  }

  send(channel: string, ...args: unknown[]): void {
    debugger;
    log("ipcRenderer.send", { args, channel });
  }

  sendSync(channel: string, ...args: unknown[]): unknown {
    debugger;
    log("ipcRenderer.sendSync", { args, channel });

    switch (channel) {
      case getSentryInitOptionsChannel:
        return {
          codexAppSessionId: "stub-session-id",
        };
      case getBuildFlavorChannel:
        return "dev";
      case getSharedObjectSnapshotChannel:
        return { ...this.sharedObjectSnapshot };
      case getSystemThemeVariantChannel:
        return "light";
      default:
        return undefined;
    }
  }

  async invoke(channel: string, ...args: unknown[]): Promise<unknown> {
    debugger;
    log("ipcRenderer.invoke", { args, channel });

    const payload = args[0];
    if (
      channel === viewToMainMessageChannel &&
      isSharedObjectSetMessage(payload)
    ) {
      this.sharedObjectSnapshot[payload.key] = payload.value;
      this.emit(mainToViewMessageChannel, {
        key: payload.key,
        type: "shared-object-updated",
        value: payload.value,
      });
      return undefined;
    }

    const workerName = workerNameFromFromViewChannel(channel);
    if (workerName) {
      this.emit(workerMessageForViewChannel(workerName), payload);
      return undefined;
    }

    if (channel === getFastModeRolloutMetricsChannel) {
      return {
        enabled: false,
        source: "electron-stub",
      };
    }

    return undefined;
  }

  private emit(channel: string, ...args: unknown[]): void {
    const listeners = this.listenersByChannel.get(channel);
    if (!listeners) {
      return;
    }

    listeners.forEach((listener) => {
      listener({ sender: "electron-stub" }, ...args);
    });
  }
}

export const ipcRenderer = new IpcRendererStub();

export const contextBridge = {
  exposeInMainWorld(key: string, api: unknown): void {
    debugger;
    log("contextBridge.exposeInMainWorld", { key });
    Reflect.set(window, key, api);
  },
};

export const webUtils = {
  getPathForFile(file: File): string | null {
    debugger;
    const candidate = (file as File & { path?: unknown }).path;
    const resolvedPath = typeof candidate === "string" ? candidate : null;
    log("webUtils.getPathForFile", {
      fileName: file.name,
      resolvedPath,
    });
    return resolvedPath;
  },
};
