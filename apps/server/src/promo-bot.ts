import { createHmac } from "node:crypto";
import { writeFileSync } from "node:fs";
import { ProxyAgent, fetch } from "undici";
import { z } from "zod";
import { SubscriptionError, SubscriptionStore, plans, type Plan } from "./subscriptions.js";

const updateSchema = z.object({ update_id: z.number().int().nonnegative(), message: z.object({
  from: z.object({ id: z.number().int(), is_bot: z.boolean().optional() }).optional(),
  chat: z.object({ id: z.number().int(), type: z.string() }), text: z.string().max(4096).optional(),
}).optional() });
export type BotUpdate = z.infer<typeof updateSchema>;
export const botHelp = "Промокоды Resonance (только администраторы)\n/promo base|plus|family дни [срок_активации_дней]\n/status UUID\n/revoke UUID\nПример: /promo plus 30 90\nКод одноразовый. Оплата проверяется администратором вне бота. Бот не принимает оплату.";

export function processPromoCommand(store: SubscriptionStore, update: BotUpdate, admins: Set<string>, secret: string): string | undefined {
  const message = update.message;
  if (!message?.from || message.from.is_bot || message.chat.type !== "private" || message.chat.id !== message.from.id || !admins.has(String(message.from.id))) return;
  const words = message.text?.trim().split(/\s+/) ?? [];
  const command = words[0]?.split("@")[0];
  const actor = `telegram:${message.from.id}`;
  try {
    if (command === "/promo") {
      if ((words.length !== 3 && words.length !== 4) || !plans.includes(words[1] as Plan) || !/^\d+$/.test(words[2] ?? "") || (words[3] && !/^\d+$/.test(words[3]))) return botHelp;
      // Deterministic per Telegram update makes restart/redelivery safe without storing plaintext codes.
      const raw = createHmac("sha256", secret).update(`resonance-promo:${update.update_id}`).digest("hex").slice(0, 40).toUpperCase();
      const code = `RSN-${raw.match(/.{1,5}/g)!.join("-")}`;
      const id = store.createPromo(words[1] as Plan, Number(words[2]), Number(words[3] ?? 90), actor, `telegram:${update.update_id}`, code);
      return `${words[1]} · ${words[2]} дней\nАктивация: ${words[3] ?? 90} дней\nID: ${id}\nКод: ${code}\nПередайте покупателю лично. Код даёт доступ Resonance, не подписку музыкального источника.`;
    }
    if (command === "/status" || command === "/revoke") {
      const id = z.string().uuid().parse(words[1]);
      if (command === "/revoke") { store.revokePromo(id, actor); return "Неиспользованный код отозван."; }
      const status = store.promoStatus(id);
      return `${status.plan} · ${status.days} дней\nСтатус: ${status.revoked_at ? "отозван" : status.redeemed_at ? "использован" : Number(status.expires_at) <= Date.now() ? "истёк" : "готов к активации"}\nID: ${status.id}`;
    }
    return botHelp;
  } catch (error) { return error instanceof SubscriptionError ? error.message : "Некорректная команда. /help"; }
}

export function botConfiguration(env: NodeJS.ProcessEnv) {
  const token = env.PROMO_BOT_TOKEN?.trim();
  const codeSecret = env.PROMO_CODE_SECRET?.trim();
  const rawProxy = env.PROMO_BOT_PROXY_URL?.trim();
  const admins = new Set((env.PROMO_BOT_ADMIN_IDS ?? "").split(",").map(x => x.trim()).filter(Boolean));
  if (!token || !/^\d+:[A-Za-z0-9_-]{20,}$/.test(token) || !codeSecret || codeSecret.length < 32 || !rawProxy || !admins.size || [...admins].some(x => !/^[1-9]\d{0,15}$/.test(x))) throw new Error("Configure PROMO_BOT_TOKEN, PROMO_CODE_SECRET, PROMO_BOT_ADMIN_IDS and PROMO_BOT_PROXY_URL; bot cannot start without them");
  let proxy: URL;
  try { proxy = new URL(rawProxy); } catch { throw new Error("PROMO_BOT_PROXY_URL must be an absolute HTTP(S) CONNECT proxy URL"); }
  if (!["http:", "https:"].includes(proxy.protocol) || !proxy.hostname || proxy.hash || proxy.search) throw new Error("PROMO_BOT_PROXY_URL must be an HTTP(S) CONNECT proxy URL");
  return { token, codeSecret, admins, proxy: proxy.toString() };
}

export async function runPromoBot(store: SubscriptionStore, env: NodeJS.ProcessEnv, signal: AbortSignal, request: typeof fetch = fetch, heartbeat: () => void = () => { writeFileSync('/tmp/promo-bot-health', 'ok'); }) {
  const config = botConfiguration(env);
  const agent = new ProxyAgent(config.proxy);
  const call = async (method: string, body: object) => {
    const response = await request(`https://api.telegram.org/bot${config.token}/${method}`, {
      method: "POST", dispatcher: agent, redirect: "error",
      headers: { "content-type": "application/json" }, body: JSON.stringify(body),
      signal: AbortSignal.any([signal, AbortSignal.timeout(40_000)]),
    });
    if (!response.ok) throw new Error("Telegram request failed");
    const result = z.object({ ok: z.literal(true), result: z.unknown() }).parse(await response.json());
    return result.result;
  };
  try {
    await call("getMe", {});
    console.info("Promo bot connected through configured proxy");
    while (!signal.aborted) {
      try {
        const raw = await call("getUpdates", { offset: store.botOffset(), timeout: 25, limit: 20, allowed_updates: ["message"] });
        heartbeat();
        for (const update of z.array(updateSchema).parse(raw)) {
          const reply = processPromoCommand(store, update, config.admins, config.codeSecret);
          if (reply) await call("sendMessage", { chat_id: update.message!.chat.id, text: reply, protect_content: true });
          store.setBotOffset(update.update_id + 1);
        }
      } catch {
        if (signal.aborted) break;
        // Never log fetch errors: they can contain the bot token or proxy credentials.
        console.warn("Promo bot request failed; retrying through proxy only");
        await new Promise<void>(resolve => {
          const done = () => { clearTimeout(timer); signal.removeEventListener("abort", done); resolve(); };
          const timer = setTimeout(done, 5_000); signal.addEventListener("abort", done, { once: true });
        });
      }
    }
  } finally { await agent.close(); }
}
