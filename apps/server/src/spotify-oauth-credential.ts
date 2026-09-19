const prefix = "spotify-refresh-v1.";

export function encodeSpotifyCredential(refreshToken: string) {
  const value = refreshToken.trim();
  if (!value || value.length > 4096 || /[\r\n]/.test(value)) {
    throw new Error("Invalid Spotify refresh token");
  }
  return `${prefix}${Buffer.from(value, "utf8").toString("base64url")}`;
}

export function decodeSpotifyCredential(value: string) {
  if (!value.startsWith(prefix)) return undefined;
  try {
    const token = Buffer.from(value.slice(prefix.length), "base64url").toString("utf8").trim();
    return token && token.length <= 4096 && !/[\r\n]/.test(token) ? token : undefined;
  } catch {
    return undefined;
  }
}
