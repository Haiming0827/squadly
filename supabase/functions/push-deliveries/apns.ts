export type PushOutcome = "sent" | "retry" | "dead";

const encoder = new TextEncoder();

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

export async function createApnsJwt(
  teamId: string,
  keyId: string,
  privateKeyPem: string,
  issuedAtSeconds: number = Math.floor(Date.now() / 1000),
): Promise<string> {
  const der = atob(
    privateKeyPem.replace(/\\n/g, "\n")
      .replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, ""),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(der, (character) => character.charCodeAt(0)),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const header = base64url(encoder.encode(JSON.stringify({ alg: "ES256", kid: keyId })));
  const claims = base64url(encoder.encode(JSON.stringify({ iss: teamId, iat: issuedAtSeconds })));
  const input = `${header}.${claims}`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(input),
  );
  return `${input}.${base64url(new Uint8Array(signature))}`;
}

export function apnsRequest(
  token: string,
  jwt: string,
  bundleId: string,
  environment: "sandbox" | "production",
): { url: string; init: RequestInit } {
  if (!/^[0-9a-fA-F]+$/.test(token)) throw new Error("Invalid APNs token");
  const host = environment === "sandbox"
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";
  return {
    url: `https://${host}/3/device/${token}`,
    init: {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-expiration": "0",
        "content-type": "application/json",
      },
      // Deliberately omit message text, card, health, route, and member names.
      body: JSON.stringify({ aps: { alert: { title: "小分队", body: "你的小队有新消息" } } }),
    },
  };
}

export function classifyApnsResponse(status: number, reason: string | null): PushOutcome {
  if (status === 200) return "sent";
  if (reason === "BadDeviceToken" || reason === "Unregistered" ||
      reason === "DeviceTokenNotForTopic") return "dead";
  return "retry";
}
