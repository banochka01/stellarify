import { useEffect, useId, useRef, useState } from "react";
import { Apple, ChevronDown, Download, Laptop, Monitor, Smartphone } from "lucide-react";
import { downloads, formatSize, type DownloadKey, type ReleaseInfo, type VisitorOs } from "../release";

type Installer = { key: DownloadKey; icon: typeof Monitor; name: string; kind: string; note?: string };

const installers: Installer[] = [
  { key: "windows", icon: Monitor, name: "Windows", kind: "Установщик EXE" },
  { key: "windowsPortable", icon: Monitor, name: "Windows Portable", kind: "ZIP без установки" },
  { key: "android", icon: Smartphone, name: "Android", kind: "APK" },
  { key: "ios", icon: Apple, name: "iOS", kind: "IPA без подписи", note: "Нужна своя подпись (AltStore, Sideloadly)" }
];

const preferred: Record<VisitorOs, DownloadKey> = {
  windows: "windows",
  windowsPortable: "windowsPortable",
  android: "android",
  ios: "ios",
  mac: "windows",
  linux: "windows"
};

const shortName: Record<DownloadKey, string> = {
  windows: "для Windows",
  windowsPortable: "для Windows",
  android: "для Android",
  ios: "для iOS"
};

/** Split button: the main part downloads for the visitor's system, the caret opens every installer. */
export function DownloadMenu({ os, release, compact = false }: { os: VisitorOs; release: ReleaseInfo; compact?: boolean }) {
  const [open, setOpen] = useState(false);
  const root = useRef<HTMLDivElement>(null);
  const menuId = useId();
  const main = preferred[os];

  useEffect(() => {
    if (!open) return;
    const onPointer = (event: PointerEvent) => {
      if (!root.current?.contains(event.target as Node)) setOpen(false);
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
        root.current?.querySelector<HTMLButtonElement>(".dl-toggle")?.focus();
      }
    };
    document.addEventListener("pointerdown", onPointer);
    document.addEventListener("keydown", onKey);
    root.current?.querySelector<HTMLAnchorElement>(".dl-item")?.focus();
    return () => {
      document.removeEventListener("pointerdown", onPointer);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <div className={`dl${compact ? " dl-compact" : ""}${open ? " dl-open" : ""}`} ref={root}>
      <div className="dl-split">
        <a className="dl-main" href={downloads[main]}>
          <Download size={compact ? 16 : 18} aria-hidden />
          {compact ? "Скачать" : `Скачать ${shortName[main]}`}
        </a>
        <button
          type="button"
          className="dl-toggle"
          aria-label="Все установщики"
          aria-haspopup="menu"
          aria-expanded={open}
          aria-controls={menuId}
          onClick={() => setOpen((value) => !value)}
        >
          <ChevronDown size={compact ? 16 : 18} aria-hidden />
        </button>
      </div>
      <div className="dl-menu" id={menuId} role="menu" hidden={!open}>
        <p className="dl-menu-head">
          {release.version ? `Resonance ${release.version}` : "Resonance"}
        </p>
        {installers.map(({ key, icon: Icon, name, kind, note }) => (
          <a key={key} className="dl-item" role="menuitem" href={downloads[key]} onClick={() => setOpen(false)}>
            <Icon size={18} aria-hidden />
            <span className="dl-item-text">
              <span className="dl-item-name">{name}{key === main ? <span className="dl-yours">ваша система</span> : null}</span>
              <span className="dl-item-meta">{[kind, formatSize(release.sizes[key])].filter(Boolean).join(" · ")}</span>
              {note ? <span className="dl-item-meta">{note}</span> : null}
            </span>
          </a>
        ))}
        <p className="dl-item dl-soon" aria-disabled="true">
          <Laptop size={18} aria-hidden />
          <span className="dl-item-text">
            <span className="dl-item-name">macOS и Linux</span>
            <span className="dl-item-meta">Сборки готовятся</span>
          </span>
        </p>
      </div>
    </div>
  );
}
