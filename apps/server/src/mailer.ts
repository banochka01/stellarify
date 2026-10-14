import nodemailer from "nodemailer";

export type MailMessage = {
  to: string;
  subject: string;
  text: string;
  html: string;
};

export interface Mailer {
  readonly enabled: boolean;
  send(message: MailMessage): Promise<void>;
}

/** No SMTP configured: account mail is skipped, everything else keeps working. */
export const disabledMailer: Mailer = {
  enabled: false,
  async send() {
    /* intentionally empty */
  }
};

/**
 * SMTP relay for account mail (password reset, email verification).
 * Reads RESONANCE_SMTP_* from the server environment; credentials never leave it.
 */
export function createMailer(env: NodeJS.ProcessEnv = process.env): Mailer {
  const host = env.RESONANCE_SMTP_HOST?.trim();
  const from = env.RESONANCE_MAIL_FROM?.trim() || "Resonance <noreply@webcordes.ru>";
  if (!host) return disabledMailer;
  const port = Number(env.RESONANCE_SMTP_PORT ?? 587);
  const transport = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    requireTLS: port !== 465,
    auth: env.RESONANCE_SMTP_USERNAME
      ? { user: env.RESONANCE_SMTP_USERNAME, pass: env.RESONANCE_SMTP_PASSWORD ?? "" }
      : undefined,
    connectionTimeout: 15_000,
    socketTimeout: 20_000
  });
  return {
    enabled: true,
    async send(message) {
      await transport.sendMail({ from, ...message });
    }
  };
}

const escapeHtml = (value: string) => value.replace(/[&<>"']/gu, (char) => `&#${char.charCodeAt(0)};`);

function layout(title: string, body: string) {
  return `<!doctype html><html lang="ru"><body style="margin:0;background:#f6f3ec;font-family:Segoe UI,Roboto,Arial,sans-serif;color:#171512">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:32px 16px">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#fff;border-radius:16px;padding:32px">
<tr><td><p style="margin:0 0 4px;font-size:13px;letter-spacing:.08em;text-transform:uppercase;color:#e2553f;font-weight:700">Resonance</p>
<h1 style="margin:0 0 16px;font-size:22px">${escapeHtml(title)}</h1>${body}
<p style="margin:24px 0 0;font-size:12px;color:#8a857c">Это автоматическое письмо, отвечать на него не нужно.</p></td></tr></table>
</td></tr></table></body></html>`;
}

const codeBlock = (code: string) =>
  `<p style="margin:16px 0;font-size:32px;font-weight:700;letter-spacing:.3em;font-family:Consolas,monospace">${code}</p>`;

export function resetCodeMail(to: string, code: string): MailMessage {
  return {
    to,
    subject: `Код для сброса пароля Resonance: ${code}`,
    text: `Код для сброса пароля Resonance: ${code}\n\nКод действует 15 минут. Если вы не запрашивали сброс, просто проигнорируйте письмо — пароль не изменится.`,
    html: layout("Сброс пароля", `<p style="margin:0">Введите этот код в приложении:</p>${codeBlock(code)}
<p style="margin:0;color:#5c5850">Код действует 15 минут. Если вы не запрашивали сброс, проигнорируйте письмо — пароль не изменится.</p>`)
  };
}

export function verifyCodeMail(to: string, code: string): MailMessage {
  return {
    to,
    subject: `Подтвердите почту в Resonance: ${code}`,
    text: `Код подтверждения почты Resonance: ${code}\n\nКод действует 24 часа. Если вы не регистрировались в Resonance, проигнорируйте письмо.`,
    html: layout("Подтверждение почты", `<p style="margin:0">Код подтверждения:</p>${codeBlock(code)}
<p style="margin:0;color:#5c5850">Код действует 24 часа. Если вы не регистрировались в Resonance, проигнорируйте письмо.</p>`)
  };
}

export function passwordChangedMail(to: string): MailMessage {
  return {
    to,
    subject: "Пароль Resonance изменён",
    text: "Пароль вашего аккаунта Resonance только что изменён, все остальные устройства вышли из аккаунта.\n\nЕсли это были не вы, сразу сбросьте пароль через «Забыли пароль?» в приложении.",
    html: layout("Пароль изменён", `<p style="margin:0">Пароль вашего аккаунта только что изменён, остальные устройства вышли из аккаунта.</p>
<p style="margin:16px 0 0;color:#5c5850">Если это были не вы, сразу сбросьте пароль через «Забыли пароль?» в приложении.</p>`)
  };
}
