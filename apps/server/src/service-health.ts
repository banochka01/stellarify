export type HealthState = "ok" | "degraded" | "down" | "unconfigured";

export interface HealthProbe {
  /** Stable id, e.g. a provider name or "lyrics". */
  id: string;
  label: string;
  configured: boolean;
  /** Resolves when the dependency answers; rejects on failure. */
  check(signal: AbortSignal): Promise<unknown>;
}

export interface ServiceHealth {
  id: string;
  label: string;
  state: HealthState;
  latencyMs?: number;
  checkedAt: string;
  error?: string;
}

export interface ServiceHealthOptions {
  timeoutMs?: number;
  /** Results are reused for this long so the endpoint cannot hammer providers. */
  cacheMs?: number;
  slowMs?: number;
  now?: () => number;
}

export class ServiceHealthMonitor {
  private cached?: { at: number; services: ServiceHealth[] };
  private inflight?: Promise<ServiceHealth[]>;
  private readonly timeoutMs: number;
  private readonly cacheMs: number;
  private readonly slowMs: number;
  private readonly now: () => number;

  constructor(private readonly probes: HealthProbe[], options: ServiceHealthOptions = {}) {
    this.timeoutMs = options.timeoutMs ?? 6_000;
    this.cacheMs = options.cacheMs ?? 60_000;
    this.slowMs = options.slowMs ?? 2_500;
    this.now = options.now ?? Date.now;
  }

  async snapshot(): Promise<{ checkedAt: string; overall: HealthState; services: ServiceHealth[] }> {
    const services = await this.services();
    return {
      checkedAt: services[0]?.checkedAt ?? new Date(this.now()).toISOString(),
      overall: overallState(services),
      services
    };
  }

  private async services(): Promise<ServiceHealth[]> {
    if (this.cached && this.now() - this.cached.at < this.cacheMs) return this.cached.services;
    if (!this.inflight) {
      this.inflight = Promise.all(this.probes.map((probe) => this.run(probe)))
        .then((services) => {
          this.cached = { at: this.now(), services };
          return services;
        })
        .finally(() => {
          this.inflight = undefined;
        });
    }
    return this.inflight;
  }

  private async run(probe: HealthProbe): Promise<ServiceHealth> {
    const checkedAt = new Date(this.now()).toISOString();
    const base = { id: probe.id, label: probe.label, checkedAt };
    if (!probe.configured) return { ...base, state: "unconfigured" };
    const controller = new AbortController();
    const started = this.now();
    let timer: NodeJS.Timeout | undefined;
    try {
      await Promise.race([
        probe.check(controller.signal),
        new Promise((_, reject) => {
          timer = setTimeout(() => {
            controller.abort();
            reject(new Error("timeout"));
          }, this.timeoutMs);
        })
      ]);
      const latencyMs = Math.max(0, this.now() - started);
      return { ...base, state: latencyMs > this.slowMs ? "degraded" : "ok", latencyMs };
    } catch (error) {
      const message = error instanceof Error ? error.message : "error";
      return {
        ...base,
        state: "down",
        latencyMs: Math.max(0, this.now() - started),
        // Short, sanitized reason only: upstream messages may contain URLs or tokens.
        error: message === "timeout" ? "timeout" : "unavailable"
      };
    } finally {
      if (timer) clearTimeout(timer);
    }
  }
}

export function overallState(services: ServiceHealth[]): HealthState {
  const active = services.filter((service) => service.state !== "unconfigured");
  if (active.length === 0) return "unconfigured";
  if (active.every((service) => service.state === "down")) return "down";
  if (active.some((service) => service.state !== "ok")) return "degraded";
  return "ok";
}
