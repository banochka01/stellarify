import { createHash, randomBytes, randomUUID } from "node:crypto";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";

export const dayMs = 86_400_000;
export const plans = ["base", "plus", "family"] as const;
export type Plan = typeof plans[number];
export type Tier = Plan | "guest" | "none";
const rank: Record<Plan, number> = { base: 1, plus: 2, family: 3 };
export const hashSecret = (value: string) => createHash("sha256").update(value).digest("hex");
export const normalizePromo = (value: string) => value.toUpperCase().replace(/[\s-]/g, "");

export class SubscriptionError extends Error {
  constructor(readonly code: string, message: string, readonly status = 403) { super(message); }
}

export function capabilities(tier: Tier) {
  const paid = plans.includes(tier as Plan);
  const premium = tier === "plus" || tier === "family";
  return {
    "playback.soundcloud": tier !== "none",
    "playback.yandex": paid,
    "library.cloudSync": paid,
    "library.import": paid,
    "wave.standard": tier !== "none",
    "wave.personalized": premium,
    "rooms.join": paid,
    "rooms.create": premium,
    "family.manage": tier === "family",
  };
}
export type Capability = keyof ReturnType<typeof capabilities>;
export interface AccessSnapshot {
  tier: Tier;
  expiresAt: string | null;
  capabilities: ReturnType<typeof capabilities>;
  providers: string[];
  deviceLimit: number;
  familyOwnerId: string | null;
  scheduled: { plan: Plan; startsAt: string; expiresAt: string }[];
}
type Period = { id: string; plan: Plan; starts_at: number; ends_at: number };

/** Independent connection to the same durable account database; all grants use IMMEDIATE transactions. */
export class SubscriptionStore {
  private readonly db: DatabaseSync;
  constructor(path: string, private readonly now: () => number = Date.now) {
    mkdirSync(dirname(path), { recursive: true });
    this.db = new DatabaseSync(path);
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS access_guests (token_hash TEXT PRIMARY KEY, expires_at INTEGER NOT NULL, bound_user TEXT UNIQUE, wave_items INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE IF NOT EXISTS access_periods (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, plan TEXT NOT NULL, starts_at INTEGER NOT NULL, ends_at INTEGER NOT NULL);
      CREATE INDEX IF NOT EXISTS access_period_user ON access_periods(user_id, ends_at);
      CREATE TABLE IF NOT EXISTS access_promos (id TEXT PRIMARY KEY, code_hash TEXT NOT NULL UNIQUE, plan TEXT NOT NULL, days INTEGER NOT NULL, expires_at INTEGER NOT NULL, created_by TEXT NOT NULL, request_id TEXT NOT NULL UNIQUE, redeemed_by TEXT, redeemed_at INTEGER, revoked_at INTEGER);
      CREATE TABLE IF NOT EXISTS access_audit (id TEXT PRIMARY KEY, actor TEXT NOT NULL, action TEXT NOT NULL, target TEXT NOT NULL, at INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS access_devices (user_id TEXT NOT NULL, device_id TEXT NOT NULL, seen_at INTEGER NOT NULL, PRIMARY KEY(user_id, device_id));
      CREATE TABLE IF NOT EXISTS access_family (member_id TEXT PRIMARY KEY, owner_id TEXT NOT NULL);
      CREATE INDEX IF NOT EXISTS access_family_owner ON access_family(owner_id);
      CREATE TABLE IF NOT EXISTS access_invites (token_hash TEXT PRIMARY KEY, owner_id TEXT NOT NULL, expires_at INTEGER NOT NULL, used_by TEXT);
      CREATE TABLE IF NOT EXISTS access_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    `);
  }
  close() { this.db.close(); }
  transaction<T>(action: () => T): T {
    this.db.exec("BEGIN IMMEDIATE");
    try { const value = action(); this.db.exec("COMMIT"); return value; }
    catch (error) { this.db.exec("ROLLBACK"); throw error; }
  }
  private audit(actor: string, action: string, target: string) {
    this.db.prepare("INSERT INTO access_audit VALUES (?, ?, ?, ?, ?)").run(randomUUID(), actor, action, target, this.now());
  }
  /** Client-generated 256-bit installation secret, not a hardware identifier. Retrying never resets time. */
  guest(token: string) {
    if (!/^[A-Za-z0-9_-]{40,128}$/.test(token)) throw new SubscriptionError("INVALID_GUEST", "Некорректная гостевая сессия", 400);
    const key = hashSecret(token);
    this.db.prepare("INSERT OR IGNORE INTO access_guests(token_hash, expires_at) VALUES (?, ?)").run(key, this.now() + dayMs);
    return this.snapshot(undefined, token);
  }
  bindGuest(userId: string, token: string | undefined) {
    if (!token) return;
    this.transaction(() => {
      const incoming = hashSecret(token);
      const existing = this.db.prepare("SELECT token_hash FROM access_guests WHERE bound_user = ?").get(userId) as { token_hash: string } | undefined;
      if (existing) {
        // A reinstall/new anonymous token must not give the same account a second
        // usable trial after logout. Never touch a token already bound elsewhere.
        if (existing.token_hash !== incoming) {
          this.db.prepare("DELETE FROM access_guests WHERE token_hash = ? AND bound_user IS NULL").run(incoming);
        }
        return;
      }
      this.db.prepare("UPDATE access_guests SET bound_user = ? WHERE token_hash = ? AND bound_user IS NULL").run(userId, incoming);
    });
  }
  snapshot(userId?: string, guestToken?: string): AccessSnapshot {
    const now = this.now();
    let periods = userId ? this.periods(userId) : [];
    let active = periods.find(p => p.starts_at <= now && p.ends_at > now);
    let familyOwnerId: string | null = null;
    if (userId && !active) {
      const member = this.db.prepare("SELECT owner_id FROM access_family WHERE member_id = ?").get(userId) as { owner_id: string } | undefined;
      if (member) {
        active = this.periods(member.owner_id).find(p => p.plan === "family" && p.starts_at <= now && p.ends_at > now);
        if (active) familyOwnerId = member.owner_id;
      }
    }
    let tier: Tier = active?.plan ?? "none";
    let expiry = active?.ends_at;
    if (!active) {
      const guest = userId
        ? this.db.prepare("SELECT expires_at FROM access_guests WHERE bound_user = ?").get(userId)
        : guestToken ? this.db.prepare("SELECT expires_at FROM access_guests WHERE token_hash = ? AND bound_user IS NULL").get(hashSecret(guestToken)) : undefined;
      if (guest && Number(guest.expires_at) > now) { tier = "guest"; expiry = Number(guest.expires_at); }
    }
    const rights = capabilities(tier);
    if (familyOwnerId) rights["family.manage"] = false;
    return {
      tier, expiresAt: expiry ? new Date(expiry).toISOString() : null,
      capabilities: rights, providers: tier === "none" ? [] : tier === "guest" ? ["soundcloud"] : ["soundcloud", "yandex"],
      deviceLimit: tier === "base" ? 2 : tier === "plus" || tier === "family" ? 10 : 1,
      familyOwnerId,
      scheduled: periods.filter(p => p.starts_at > now).map(p => ({ plan: p.plan, startsAt: new Date(p.starts_at).toISOString(), expiresAt: new Date(p.ends_at).toISOString() })),
    };
  }
  require(right: Capability, userId?: string, guestToken?: string) {
    const snapshot = this.snapshot(userId, guestToken);
    if (!snapshot.capabilities[right]) throw new SubscriptionError("SUBSCRIPTION_REQUIRED", "Для этой функции нужна действующая подписка. Откройте раздел «Подписка».");
    return snapshot;
  }
  private periods(userId: string): Period[] {
    return this.db.prepare("SELECT id, plan, starts_at, ends_at FROM access_periods WHERE user_id = ? AND ends_at > ? ORDER BY starts_at").all(userId, this.now()) as unknown as Period[];
  }
  createPromo(plan: Plan, days: number, validityDays: number, actor: string, requestId: string, code: string) {
    if (!plans.includes(plan) || !Number.isInteger(days) || days < 1 || days > 3660 || !Number.isInteger(validityDays) || validityDays < 1 || validityDays > 365) {
      throw new SubscriptionError("INVALID_PROMO", "Тариф: base/plus/family; срок 1–3660 дней; активация в течение 1–365 дней", 400);
    }
    return this.transaction(() => {
      const previous = this.db.prepare("SELECT id FROM access_promos WHERE request_id = ?").get(requestId);
      if (previous) return String(previous.id);
      const id = randomUUID();
      this.db.prepare("INSERT INTO access_promos(id, code_hash, plan, days, expires_at, created_by, request_id) VALUES (?, ?, ?, ?, ?, ?, ?)")
        .run(id, hashSecret(normalizePromo(code)), plan, days, this.now() + validityDays * dayMs, actor, requestId);
      this.audit(actor, "promo.created", id);
      return id;
    });
  }
  promoStatus(id: string) {
    const row = this.db.prepare("SELECT id, plan, days, expires_at, redeemed_at, revoked_at FROM access_promos WHERE id = ?").get(id);
    if (!row) throw new SubscriptionError("PROMO_NOT_FOUND", "Код не найден", 404);
    return row;
  }
  revokePromo(id: string, actor: string) {
    this.transaction(() => {
      const result = this.db.prepare("UPDATE access_promos SET revoked_at = ? WHERE id = ? AND redeemed_at IS NULL AND revoked_at IS NULL").run(this.now(), id);
      if (!result.changes) throw new SubscriptionError("PROMO_UNAVAILABLE", "Код уже использован, отозван или не найден", 409);
      this.audit(actor, "promo.revoked", id);
    });
  }
  redeem(userId: string, code: string) {
    this.transaction(() => {
      const promo = this.db.prepare("SELECT * FROM access_promos WHERE code_hash = ?").get(hashSecret(normalizePromo(code))) as {
        id: string; plan: Plan; days: number; expires_at: number; redeemed_by: string | null; revoked_at: number | null;
      } | undefined;
      if (!promo || promo.revoked_at || promo.expires_at <= this.now() || (promo.redeemed_by && promo.redeemed_by !== userId)) {
        throw new SubscriptionError("PROMO_UNAVAILABLE", "Код недействителен, истёк или уже использован", 400);
      }
      if (promo.redeemed_by === userId) return; // Lost response retries never grant twice.
      if (this.db.prepare("SELECT 1 FROM access_family WHERE member_id = ?").get(userId)) {
        throw new SubscriptionError("FAMILY_MEMBER", "Сначала выйдите из семейной группы: её доступ не расходует личный промокод", 409);
      }
      const periods = this.periods(userId);
      const start = Math.max(this.now(), ...periods.filter(p => rank[p.plan] >= rank[promo.plan]).map(p => p.ends_at));
      const duration = promo.days * dayMs;
      // Higher tiers start immediately; remaining lower-tier time is moved, never discarded.
      for (const period of periods.filter(p => p.ends_at > start)) {
        this.db.prepare("UPDATE access_periods SET starts_at = ?, ends_at = ? WHERE id = ?")
          .run(Math.max(start, period.starts_at) + duration, period.ends_at + duration, period.id);
      }
      this.db.prepare("INSERT INTO access_periods VALUES (?, ?, ?, ?, ?)").run(randomUUID(), userId, promo.plan, start, start + duration);
      this.db.prepare("UPDATE access_promos SET redeemed_by = ?, redeemed_at = ? WHERE id = ?").run(userId, this.now(), promo.id);
      this.audit(userId, "promo.redeemed", promo.id);
    });
    return this.snapshot(userId);
  }
  touchDevice(userId: string, deviceId: string) {
    if (!/^[A-Za-z0-9_-]{20,128}$/.test(deviceId)) throw new SubscriptionError("DEVICE_REQUIRED", "Обновите клиент Resonance", 400);
    this.transaction(() => {
      this.db.prepare("DELETE FROM access_devices WHERE seen_at < ?").run(this.now() - 30 * dayMs);
      const existing = this.db.prepare("SELECT 1 FROM access_devices WHERE user_id = ? AND device_id = ?").get(userId, deviceId);
      const count = this.db.prepare("SELECT count(*) AS n FROM access_devices WHERE user_id = ?").get(userId)!;
      const limit = this.snapshot(userId).deviceLimit;
      const permitted = this.db.prepare("SELECT device_id FROM access_devices WHERE user_id = ? ORDER BY seen_at DESC, device_id LIMIT ?").all(userId, limit);
      if ((!existing && Number(count.n) >= limit) || (existing && !permitted.some(d => d.device_id === deviceId))) throw new SubscriptionError("DEVICE_LIMIT", "Достигнут лимит устройств. Отключите старое в разделе «Подписка».");
      this.db.prepare("INSERT INTO access_devices VALUES (?, ?, ?) ON CONFLICT(user_id, device_id) DO UPDATE SET seen_at = excluded.seen_at").run(userId, deviceId, this.now());
    });
  }
  devices(userId: string) { return this.db.prepare("SELECT device_id AS id, seen_at AS lastSeenAt FROM access_devices WHERE user_id = ? ORDER BY seen_at DESC").all(userId); }
  removeDevice(userId: string, deviceId: string) { this.db.prepare("DELETE FROM access_devices WHERE user_id = ? AND device_id = ?").run(userId, deviceId); }
  consumeGuestWave(userId?: string, token?: string) {
    if (this.snapshot(userId, token).tier !== "guest") return;
    const condition = userId ? "bound_user = ?" : "token_hash = ? AND bound_user IS NULL";
    const result = this.db.prepare(`UPDATE access_guests SET wave_items = wave_items + 1 WHERE ${condition} AND wave_items < 3 AND expires_at > ?`).run(userId ?? hashSecret(token ?? ""), this.now());
    if (!result.changes) throw new SubscriptionError("GUEST_WAVE_LIMIT", "Гостевая Wave: до трёх подборок за пробные сутки. Обычный поиск доступен до конца суток.");
  }
  invite(userId: string) {
    this.require("family.manage", userId);
    const token = randomBytes(24).toString("base64url");
    this.db.prepare("DELETE FROM access_invites WHERE owner_id = ?").run(userId);
    this.db.prepare("INSERT INTO access_invites VALUES (?, ?, ?, NULL)").run(hashSecret(token), userId, this.now() + dayMs);
    return token;
  }
  joinFamily(userId: string, token: string) {
    this.transaction(() => {
      const invite = this.db.prepare("SELECT owner_id FROM access_invites WHERE token_hash = ? AND used_by IS NULL AND expires_at > ?").get(hashSecret(token), this.now());
      if (!invite) throw new SubscriptionError("INVITE_INVALID", "Приглашение истекло или использовано", 400);
      const owner = String(invite.owner_id);
      this.require("family.manage", owner);
      if (owner === userId || this.periods(userId).length || this.db.prepare("SELECT 1 FROM access_family WHERE member_id = ? OR owner_id = ?").get(userId, userId)) throw new SubscriptionError("FAMILY_CONFLICT", "У аккаунта уже есть подписка или семейная группа", 409);
      if (Number(this.db.prepare("SELECT count(*) AS n FROM access_family WHERE owner_id = ?").get(owner)!.n) >= 4) throw new SubscriptionError("FAMILY_FULL", "В группе уже пять человек", 409);
      this.db.prepare("INSERT INTO access_family VALUES (?, ?)").run(userId, owner);
      this.db.prepare("UPDATE access_invites SET used_by = ? WHERE token_hash = ?").run(userId, hashSecret(token));
      this.audit(userId, "family.joined", owner);
    });
  }
  family(userId: string) { return this.db.prepare("SELECT member_id AS id FROM access_family WHERE owner_id = ?").all(userId); }
  leaveFamily(userId: string, memberId = userId) {
    this.db.prepare("DELETE FROM access_family WHERE member_id = ? AND (owner_id = ? OR member_id = ?)").run(memberId, userId, userId);
  }
  botOffset() { return Number(this.db.prepare("SELECT value FROM access_meta WHERE key = 'bot_offset'").get()?.value ?? 0); }
  setBotOffset(offset: number) { this.db.prepare("INSERT INTO access_meta VALUES ('bot_offset', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value").run(String(offset)); }
}
