export function mapBrowserPathToInitialRoute(pathname: string): string {
  const match = pathname.match(/^\/thread\/([^/]+)$/);
  if (!match) {
    return "/";
  }

  try {
    return `/local/${decodeURIComponent(match[1])}`;
  } catch {
    return "/";
  }
}

export function mapMemoryPathToBrowserPath(pathname: string) {
  if (pathname === "/") {
    return { path: "/", titleChange: "Codex" };
  }

  const match = pathname.match(/^\/local\/([^/?#]+)$/);
  if (!match) {
    return null;
  }

  return { path: `/thread/${encodeURIComponent(match[1])}` };
}

export function dispatchNavigateToRoute(path: string): void {
  window.dispatchEvent(
    new MessageEvent("message", {
      data: {
        type: "navigate-to-route",
        path,
      },
    }),
  );
}

window.addEventListener("popstate", () => {
  dispatchNavigateToRoute(
    mapBrowserPathToInitialRoute(window.location.pathname),
  );
});
