import type { NextFunction, Request, Response } from "express";

/**
 * Last-resort Express error handler. Without it, body-parser failures (bad
 * JSON, oversized bodies) and stray throws are answered with Express' HTML
 * page, which includes the stack trace and server file paths outside production.
 */
export function jsonErrorHandler(error: unknown, _request: Request, response: Response, next: NextFunction) {
  if (response.headersSent) {
    next(error);
    return;
  }
  const status = httpStatus(error);
  if (status >= 500) console.error("Unhandled request error", error instanceof Error ? error.message : error);
  const code =
    status === 413 ? "PAYLOAD_TOO_LARGE" :
    status === 415 ? "UNSUPPORTED_MEDIA_TYPE" :
    status < 500 ? "INVALID_REQUEST" : "INTERNAL_ERROR";
  const message =
    status === 413 ? "Request body is too large" :
    status < 500 ? "Malformed request" : "Internal server error";
  response.status(status).json({ error: { code, message } });
}

function httpStatus(error: unknown) {
  const raw = (error as { status?: unknown; statusCode?: unknown } | null)?.status ??
    (error as { statusCode?: unknown } | null)?.statusCode;
  return typeof raw === "number" && raw >= 400 && raw < 600 ? raw : 500;
}
