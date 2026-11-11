import { useEffect, useId, useRef, useState, type KeyboardEvent as ReactKeyboardEvent } from "react";
import { Apple, ChevronDown, Download, Laptop, Monitor, Smartphone } from "lucide-react";
import { downloads, formatSize, type DownloadKey, type ReleaseInfo, type VisitorOs } from "../release";

type Installer = { key: DownloadKey; icon: typeof Monitor; name: string; kind: string; note?: string };

const installers: Installer[] = [
  { key: "windows", icon: Monitor, name: "Windows", kind: "Установщик EXE" },
  { key: "windowsPortable", icon: Monitor, name: "Windows Portable", kind: "ZIP без установки" },
  { key: "android", icon: Smartphone, name: "Android", kind: "APK" },
  { key: "ios", icon: Apple, name: "iOS", kind: "IPA без подписи", note: "Нужна своя подпись: AltStore или Sideloadly" }
];

/** Installer matching the visitor's system; none yet for macOS and Linux. */
const preferred: Record<VisitorOs, DownloadKey | null> = {
  windows: "windows",
  windowsPortable: "windowsPortable",
  android: "android",
  ios: "ios",
  mac: null,
  linux: null
};

const shortName: Record<DownloadKey, string> = {
  windows: "для Windows",
  windowsPortable: "для Windows",
  android: "для Android",
  ios: "для iOS"
};

const meta = (installer: Installer, release: ReleaseInfo) =>
  [installer.kind, formatSize(release.sizes[installer.key])].filter(Boolean).join(" · ");

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
    const onFocus = (event: FocusEvent) => {
      if (!root.current?.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener("pointerdown", onPointer);
    document.addEventListener("keydown", onKey);
    document.addEventListener("focusin", onFocus);
    root.current?.querySelector<HTMLAnchorElement>("a.dl-item")?.focus();
    return () => {
      document.removeEventListener("pointerdown", onPointer);
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("focusin", onFocus);
    };
  }, [open]);

  const onMenuKey = (event: ReactKeyboardEvent<HTMLDivElement>) => {
    const items = Array.from(event.currentTarget.querySelectorAll<HTMLAnchorElement>("a.dl-item"));
    const index = items.indexOf(document.activeElement as HTMLAnchorElement);
    let next = index;
    if (event.key === "ArrowDown") next = (index + 1) % items.length;
    else if (event.key === "ArrowUp") next = (index - 1 + items.length) % items.length;
    else if (event.key === "Home") next = 0;
    else if (event.key === "End") next = items.length - 1;
    else return;
    event.preventDefault();
    items[next]?.focus();
  };

  const toggle = () => setOpen((value) => !value);
  const icon = <Download size={compact ? 16 : 18} aria-hidden />;

  return (
    <div className={`dl${compact ? " dl-compact" : ""}${open ? " dl-open" : ""}`} ref={root}>
      <div className="dl-split">
        {main ? (
          <a className="dl-main" href={downloads[main]}>
            {icon}
            {compact ? "Скачать" : `Скачать ${shortName[main]}`}
          </a>
        ) : (
          <button type="button" className="dl-main" aria-haspopup="menu" aria-expanded={open} aria-controls={menuId} onClick={toggle}>
            {icon}
            {compact ? "Скачать" : "Скачать Resonance"}
          </button>
        )}
        <button
          type="button"
          className="dl-toggle"
          aria-label="Все установщики"
          aria-haspopup="menu"
          aria-expanded={open}
          aria-controls={menuId}
          onClick={toggle}
        >
          <ChevronDown size={compact ? 16 : 18} aria-hidden />
        </button>
      </div>
      <div className="dl-menu" id={menuId} role="menu" aria-label="Установщики Resonance" hidden={!open} onKeyDown={onMenuKey}>
        <p className="dl-menu-head">
          {release.version ? `Resonance ${release.version}` : "Resonance"}
        </p>
        {installers.map((installer) => {
          const { key, icon: Icon, name, note } = installer;
          return (
            <a key={key} className="dl-item" role="menuitem" href={downloads[key]} onClick={() => setOpen(false)}>
              <Icon size={18} aria-hidden />
              <span className="dl-item-text">
                <span className="dl-item-name">{name}{key === main ? <span className="dl-yours">ваша система</span> : null}</span>
                <span className="dl-item-meta">{meta(installer, release)}</span>
                {note ? <span className="dl-item-meta">{note}</span> : null}
              </span>
            </a>
          );
        })}
        <p className="dl-item dl-soon">
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

/** Every installer as a card; the visitor's own system is highlighted and listed first. */
export function DownloadGrid({ os, release }: { os: VisitorOs; release: ReleaseInfo }) {
  const main = preferred[os];
  const ordered = main ? [...installers].sort((a, b) => Number(b.key === main) - Number(a.key === main)) : installers;

  return (
    <ul className="platform-grid">
      {ordered.map((installer) => {
        const { key, icon: Icon, name, note } = installer;
        const current = key === main;
        return (
          <li key={key}>
            <a className={`platform-card${current ? " platform-current" : ""}`} href={downloads[key]}>
              <span className="platform-icon"><Icon size={22} aria-hidden /></span>
              <span className="platform-text">
                <span className="platform-name">
                  {name}
                  {current ? <span className="current-badge">ваша система</span> : null}
                </span>
                <span className="platform-meta">{meta(installer, release)}</span>
                {note ? <span className="platform-meta">{note}</span> : null}
              </span>
              <span className="platform-action" aria-hidden><Download size={18} /></span>
            </a>
          </li>
        );
      })}
      <li>
        <div className="platform-card platform-soon">
          <span className="platform-icon"><Laptop size={22} aria-hidden /></span>
          <span className="platform-text">
            <span className="platform-name">macOS и Linux</span>
            <span className="platform-meta">Сборки готовятся — с тем же аккаунтом и медиатекой</span>
          </span>
          <span className="soon-badge">скоро</span>
        </div>
      </li>
    </ul>
  );
}
