import { Check, Link2, LoaderCircle, X } from "lucide-react";
import { useState } from "react";
import type { ImportedSource } from "./types";

type ImportModalProps = {
  apiUrl: string;
  onClose: () => void;
  onImported: (sources: ImportedSource[]) => void;
};

export function ImportModal({
  apiUrl,
  onClose,
  onImported
}: ImportModalProps) {
  const [value, setValue] = useState("");
  const [sources, setSources] = useState<ImportedSource[]>([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const preview = async () => {
    setLoading(true);
    setError("");
    try {
      const response = await fetch(`${apiUrl}/api/import/preview`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ value })
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "Не удалось проверить ссылки");
      setSources(data.sources);
    } catch (requestError) {
      setError(
        requestError instanceof Error
          ? requestError.message
          : "Сервер импорта недоступен"
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={onClose}>
      <section
        className="import-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="import-title"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <button className="icon-button modal-close" onClick={onClose} aria-label="Закрыть">
          <X size={19} />
        </button>
        <div className="modal-icon">
          <Link2 size={23} />
        </div>
        <p className="eyebrow">Умный импорт</p>
        <h2 id="import-title">Добавьте музыку ссылкой</h2>
        <p className="modal-copy">
          Вставьте одну или несколько ссылок. Stellarify определит площадку и
          подготовит библиотеку, не копируя аудиофайлы.
        </p>

        <textarea
          value={value}
          onChange={(event) => setValue(event.target.value)}
          placeholder={"https://open.spotify.com/playlist/...\nhttps://music.youtube.com/playlist?..."}
          autoFocus
        />

        {error && <p className="form-error">{error}</p>}

        {sources.length > 0 && (
          <div className="import-results">
            {sources.map((source, index) => (
              <div className="import-result" key={`${source.sourceUrl || source.label}-${index}`}>
                <span className={`provider-dot ${source.provider}`} />
                <div>
                  <strong>{source.label}</strong>
                  <small>{source.externalId || "Будет добавлено как поисковый запрос"}</small>
                </div>
                <Check size={17} />
              </div>
            ))}
          </div>
        )}

        <div className="modal-actions">
          {sources.length === 0 ? (
            <button className="primary-button wide" onClick={preview} disabled={!value.trim() || loading}>
              {loading ? <LoaderCircle className="spin" size={18} /> : <Link2 size={18} />}
              Проверить ссылки
            </button>
          ) : (
            <button
              className="primary-button wide"
              onClick={() => {
                onImported(sources);
                onClose();
              }}
            >
              <Check size={18} />
              Добавить {sources.length}
            </button>
          )}
        </div>
      </section>
    </div>
  );
}

