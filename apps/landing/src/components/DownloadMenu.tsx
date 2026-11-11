import { useEffect, useId, useRef, useState, type KeyboardEvent as ReactKeyboardEvent } from "react";
import { Apple, ChevronDown, Download, FlaskConical, Laptop, Monitor, Smartphone } from "lucide-react";
import {
  alphaVersion,
  downloadsFor,
  formatSize,
  useChannel,
  type Channel,
  type DownloadKey,
  type ReleaseInfo,
  type VisitorOs
} from "../release";

type Installer = { key: DownloadKey; icon: typeof Monitor; name: string; kind: string; note?: string };

const stableInstallers: Installer[] = [
  { key: "windows", icon: Monitor, name: "Windows", kind: "Установщик EXE" },
  { key: "windowsPortable", icon: Monitor, name: "Windows Portable", kind: "ZIP без установки" },
  { key: "android", icon: Smartphone, name: "Android", kind: "APK" },
  { key: "ios", icon: Apple, name: "iOS", kind: "IPA без подписи", note: "Нужна своя подпись: AltStore или Sideloadly" }
];

/** Resonance α: a separate app with the new interface, installed beside the stable one. */
const alphaInstallers: Installer[] = [
  { key: "windowsPortable", icon: Monitor, name: "Windows", kind: "ZIP без установки" },
  { key: "ios", icon: Apple, name: "iOS", kind: "IPA без подписи", note: "Ставится рядом со стабильной версией" }
];

const installersFor = (channel: Channel) => (channel === "alpha" ? alphaInstallers : stableInstallers);

/** Installer matching the visitor's system; none yet for macOS and Linux. */
const preferredStable: Record<VisitorOs, DownloadKey | null> = {
  windows: "windows",
  windowsPortable: "windowsPortable",
  android: "android",
  ios: "ios",
  mac: null,
  linux: null
};

const preferredAlpha: Record<VisitorOs, DownloadKey | null> = {
  windows: "windowsPortable",
  windowsPortable: "windowsPortable",
  android: null,
  ios: "ios",
  mac: null,
  linux: null
};

const preferredFor = (channel: Channel, os: VisitorOs) =>
  (channel === "alpha" ? preferredAlpha : preferredStable)[os];

const shortName: Record<DownloadKey, string> = {
  windows: "для Windows",
  windowsPortable: "для Windows",
  android: "для Android",
  ios: "для iOS"
};

const meta = (installer: Installer, release: ReleaseInfo, channel: Channel) =>
  [
    installer.kind,
    formatSize((channel === "alpha" ? release.alphaSizes : release.sizes)[installer.key])
  ].filter(Boolean).join(" · ");

/** Two-position lever: stable release or the Resonance α preview. */
export function ChannelSwitch({ compact = false }: { compact?: boolean }) {
  const [channel, setChannel] = useChannel();
  return (
    <div className={`channel${compact ? " channel-compact" : ""}`} role="radiogroup" aria-label="Версия приложения">
      {(["stable", "alpha"] as const).map((value) => (
        <button
          key={value}
          type="button"
          role="radio"
          aria-checked={channel === value}
          className={`channel-option${channel === value ? " channel-active" : ""}`}
          onClick={() => setChannel(value)}
        >
          {value === "stable" ? "Stable" : "Alpha α"}
        </button>
      ))}
    </div>
  );
}

/** Split button: the main part downloads for the visitor's system, the caret opens every installer. */
export function DownloadMenu({ os, release, compact = false }: { os: VisitorOs; release: ReleaseInfo; compact?: boolean }) {
  const [open, setOpen] = useState(false);
  const [channel] = useChannel();
  const root = useRef<HTMLDivElement>(null);
  const menuId = useId();
  const main = preferredFor(channel, os);
  const links = downloadsFor(channel);
  const installers = installersFor(channel);

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
  const icon = channel === "alpha"
    ? <FlaskConical size={compact ? 16 : 18} aria-hidden />
    : <Download size={compact ? 16 : 18} aria-hidden />;
  const product = channel === "alpha" ? "Resonance α" : "Resonance";

  return (
    <div className={`dl${compact ? " dl-compact" : ""}${open ? " dl-open" : ""}`} ref={root}>
      <div className="dl-split">
        {main && links[main] ? (
          <a className="dl-main" href={links[main]}>
            {icon}
            {compact ? "Скачать" : `Скачать${channel === "alpha" ? " альфу" : ""} ${shortName[main]}`}
          </a>
        ) : (
          <button type="button" className="dl-main" aria-haspopup="menu" aria-expanded={open} aria-controls={menuId} onClick={toggle}>
            {icon}
            {compact ? "Скачать" : `Скачать ${product}`}
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
      <div className="dl-menu" id={menuId} role="menu" aria-label={`Установщики ${product}`} hidden={!open} onKeyDown={onMenuKey}>
        <div className="dl-menu-top">
          <p className="dl-menu-head">
            {channel === "alpha"
              ? `Resonance α ${alphaVersion}`
              : release.version ? `Resonance ${release.version}` : "Resonance"}
          </p>
          <ChannelSwitch compact />
        </div>
        {channel === "alpha" ? (
          <p className="dl-menu-note">Новый интерфейс, ранняя версия. Аккаунт и медиатека — общие.</p>
        ) : null}
        {installers.map((installer) => {
          const { key, icon: Icon, name, note } = installer;
          return (
            <a key={key} className="dl-item" role="menuitem" href={links[key]} onClick={() => setOpen(false)}>
              <Icon size={18} aria-hidden />
              <span className="dl-item-text">
                <span className="dl-item-name">{name}{key === main ? <span className="dl-yours">ваша система</span> : null}</span>
                <span className="dl-item-meta">{meta(installer, release, channel)}</span>
                {note ? <span className="dl-item-meta">{note}</span> : null}
              </span>
            </a>
          );
        })}
        <p className="dl-item dl-soon">
          <Laptop size={18} aria-hidden />
          <span className="dl-item-text">
            <span className="dl-item-name">{channel === "alpha" ? "Android, macOS и Linux" : "macOS и Linux"}</span>
            <span className="dl-item-meta">Сборки готовятся</span>
          </span>
        </p>
      </div>
    </div>
  );
}

/** Every installer as a card; the visitor's own system is highlighted and listed first. */
export function DownloadGrid({ os, release }: { os: VisitorOs; release: ReleaseInfo }) {
  const [channel] = useChannel();
  const main = preferredFor(channel, os);
  const links = downloadsFor(channel);
  const installers = installersFor(channel);
  const ordered = main ? [...installers].sort((a, b) => Number(b.key === main) - Number(a.key === main)) : installers;

  return (
    <ul className="platform-grid">
      {ordered.map((installer) => {
        const { key, icon: Icon, name, note } = installer;
        const current = key === main;
        return (
          <li key={`${channel}-${key}`}>
            <a className={`platform-card${current ? " platform-current" : ""}`} href={links[key]}>
              <span className="platform-icon"><Icon size={22} aria-hidden /></span>
              <span className="platform-text">
                <span className="platform-name">
                  {name}
                  {channel === "alpha" ? <span className="alpha-badge">α {alphaVersion}</span> : null}
                  {current ? <span className="current-badge">ваша система</span> : null}
                </span>
                <span className="platform-meta">{meta(installer, release, channel)}</span>
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
            <span className="platform-name">{channel === "alpha" ? "Android, macOS и Linux" : "macOS и Linux"}</span>
            <span className="platform-meta">
              {channel === "alpha"
                ? "Альфа пока для Windows и iOS — на остальных используйте стабильную версию"
                : "Сборки готовятся — с тем же аккаунтом и медиатекой"}
            </span>
          </span>
          <span className="soon-badge">скоро</span>
        </div>
      </li>
    </ul>
  );
}
