import assert from "node:assert/strict";
import test from "node:test";
import { scrubReport, scrubReportText } from "./client-reports.js";

test("client reports strip URLs, e-mails and token-like values", () => {
  const text = scrubReportText(
    "GET https://api.vk.com/method/audio.get?access_token=abc123&v=5 failed for me@example.com " +
    "Authorization: Bearer y0_AgAAAABkZXZlbG9wZXJ0b2tlbnZhbHVlMTIzNDU2Nzg5 token=short1"
  );
  assert.doesNotMatch(text, /vk\.com|abc123|me@example|y0_Ag|short1/u);
  assert.match(text, /\[url\]/u);
  assert.match(text, /\[email\]/u);
});

test("client reports scrub stack and context string values", () => {
  const report = scrubReport({
    kind: "network",
    message: "boom\u0007",
    stack: "at file:///C:/Users/alice/app.dart:1",
    context: { url: "https://cdn.example/stream.mp3?sig=zzz", attempts: 3 }
  });
  assert.equal(report.message, "boom");
  assert.equal(report.stack, "at [url]");
  assert.deepEqual(report.context, { url: "[url]", attempts: 3 });
});
