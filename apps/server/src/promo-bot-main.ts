import "dotenv/config";
import { SubscriptionStore } from "./subscriptions.js";
import { botConfiguration, runPromoBot } from "./promo-bot.js";

// Validate before opening the database; no partially configured direct-network fallback.
try { botConfiguration(process.env); } catch { console.error("Promo bot configuration is missing or invalid. See deploy/SUBSCRIPTIONS.md."); process.exit(1); }
const store = new SubscriptionStore(process.env.AUTH_DB_PATH || "./data/resonance.sqlite");
const controller = new AbortController();
process.once("SIGTERM", () => controller.abort());
process.once("SIGINT", () => controller.abort());
try { await runPromoBot(store, process.env, controller.signal); }
catch { console.error("Promo bot stopped: Telegram/proxy unavailable; no direct fallback"); process.exitCode = 1; }
finally { store.close(); }
