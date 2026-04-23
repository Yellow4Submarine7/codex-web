type MemoryNavigationChange = {
    action: "POP" | "PUSH" | "REPLACE";
    delta: number;
    location: {
        hash: string;
        key: string;
        pathname: string;
        search: string;
        state: unknown;
    };
};

type ElectronShimState = {
    initialRoute?: string;
    initialSidebarState?: boolean;
    closeSidebar?: () => void;
    onMemoryNavigationChanged?: (navigation: MemoryNavigationChange) => void;
};

declare global {
    interface Window {
        __ELECTRON_SHIM__?: ElectronShimState;
    }
}
