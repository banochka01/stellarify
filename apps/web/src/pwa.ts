import { useEffect, useState } from "react";

type InstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
};

/** True inside the Tauri shell: PWA features are disabled there. */
export function isTauri(): boolean {
  return typeof window !== "undefined" && ("__TAURI_INTERNALS__" in window || "__TAURI__" in window);
}

let waitingWorker: ServiceWorker | null = null;
const UPDATE_EVENT = "resonance-sw-update";

function announce(worker: ServiceWorker) {
  waitingWorker = worker;
  window.dispatchEvent(new Event(UPDATE_EVENT));
}

export function registerServiceWorker(): void {
  if (!import.meta.env.PROD || isTauri() || !("serviceWorker" in navigator)) return;
  window.addEventListener("load", () => {
    navigator.serviceWorker
      .register("/sw.js", { scope: "/" })
      .then((registration) => {
        if (registration.waiting && navigator.serviceWorker.controller) announce(registration.waiting);
        registration.addEventListener("updatefound", () => {
          const worker = registration.installing;
          worker?.addEventListener("statechange", () => {
            // Only an update (there is already a controller), not the first install.
            if (worker.state === "installed" && navigator.serviceWorker.controller) announce(worker);
          });
        });
      })
      .catch((error: unknown) => {
        console.warn("Service worker registration failed", error);
      });
    let reloading = false;
    navigator.serviceWorker.addEventListener("controllerchange", () => {
      if (reloading) return;
      reloading = true;
      window.location.reload();
    });
  });
}

/** «Доступно обновление → Обновить»: true when a new worker is waiting. */
export function useServiceWorkerUpdate() {
  const [ready, setReady] = useState(waitingWorker !== null);
  useEffect(() => {
    const onUpdate = () => setReady(true);
    window.addEventListener(UPDATE_EVENT, onUpdate);
    return () => window.removeEventListener(UPDATE_EVENT, onUpdate);
  }, []);
  const apply = () => waitingWorker?.postMessage("skip-waiting");
  return { updateReady: ready, applyUpdate: apply };
}

/** Exposes the browser install prompt when available. */
export function useInstallPrompt() {
  const [promptEvent, setPromptEvent] = useState<InstallPromptEvent | null>(null);

  useEffect(() => {
    if (isTauri()) return;
    const onPrompt = (event: Event) => {
      event.preventDefault();
      setPromptEvent(event as InstallPromptEvent);
    };
    const onInstalled = () => setPromptEvent(null);
    window.addEventListener("beforeinstallprompt", onPrompt);
    window.addEventListener("appinstalled", onInstalled);
    return () => {
      window.removeEventListener("beforeinstallprompt", onPrompt);
      window.removeEventListener("appinstalled", onInstalled);
    };
  }, []);

  const install = async () => {
    if (!promptEvent) return;
    await promptEvent.prompt();
    await promptEvent.userChoice.catch(() => undefined);
    setPromptEvent(null);
  };

  return { canInstall: promptEvent !== null, install };
}
