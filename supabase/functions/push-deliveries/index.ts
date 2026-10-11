import { apnsRequest, classifyApnsResponse, createApnsJwt } from "./apns.ts";
import { classifyMiPushResponse, miPushRequest } from "./mipush.ts";

type Claim = {
  delivery_id: number;
  claim_id: string;
  provider: "apns" | "mipush";
  token: string;
};

function required(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function matchesSecret(provided: string | null, expected: string): boolean {
  if (provided === null || provided.length !== expected.length) return false;
  let difference = 0;
  for (let index = 0; index < expected.length; index++) {
    difference |= provided.charCodeAt(index) ^ expected.charCodeAt(index);
  }
  return difference === 0;
}

async function rpc<T>(name: string, body: Record<string, unknown>): Promise<T> {
  const response = await fetch(`${required("SUPABASE_URL")}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: required("SUPABASE_SERVICE_ROLE_KEY"),
      authorization: `Bearer ${required("SUPABASE_SERVICE_ROLE_KEY")}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`RPC ${name} returned ${response.status}`);
  return await response.json() as T;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  const expectedSecret = Deno.env.get("PUSH_WORKER_SECRET");
  if (!expectedSecret || expectedSecret.length < 32) {
    return Response.json({ error: "push_worker_unavailable" }, { status: 503 });
  }
  if (!matchesSecret(request.headers.get("x-squadly-worker-secret"), expectedSecret)) {
    return new Response(null, { status: 401 });
  }
  try {
    const apnsSettings = [
      Deno.env.get("APNS_ENVIRONMENT"),
      Deno.env.get("APNS_TEAM_ID"),
      Deno.env.get("APNS_KEY_ID"),
      Deno.env.get("APNS_PRIVATE_KEY"),
      Deno.env.get("APNS_BUNDLE_ID"),
    ];
    const apnsConfigured = apnsSettings.every(Boolean);
    if (apnsSettings.some(Boolean) && !apnsConfigured) {
      throw new Error("APNs configuration is incomplete");
    }
    let accepted = 0;
    let failed = 0;
    let apnsConfiguration: {
      environment: "sandbox" | "production";
      jwt: string;
    } | null = null;
    const dispatch = async (
      provider: "apns" | "mipush",
      providerClaims: Claim[],
    ) => {
      for (const claim of providerClaims) {
        let outcome: "sent" | "retry" | "dead" = "retry";
        let reason: string | null = null;
        try {
          let push: { url: string; init: RequestInit };
          if (provider === "apns") {
            if (!apnsConfiguration) throw new Error("APNs is not configured");
            push = apnsRequest(
              claim.token,
              apnsConfiguration.jwt,
              required("APNS_BUNDLE_ID"),
              apnsConfiguration.environment,
            );
          } else {
            push = miPushRequest(
                claim.token,
                required("MIPUSH_APP_SECRET"),
                required("MIPUSH_PACKAGE_NAME"),
                required("MIPUSH_CHANNEL_ID"),
            );
          }
          const response = await fetch(push.url, push.init);
          if (provider === "mipush") {
            const value: unknown = await response.json().catch(() => null);
            const parsed = value && typeof value === "object"
              ? value as {
                  code?: unknown;
                  invalid_target?: unknown;
                  data?: { invalid_target?: unknown };
                }
              : null;
            outcome = classifyMiPushResponse(response.status, parsed);
            const invalidTarget = parsed?.invalid_target ?? parsed?.data?.invalid_target;
            if (
              outcome === "dead" && typeof invalidTarget === "number" &&
              invalidTarget > 0
            ) {
              reason = "InvalidRegId";
            } else if (parsed?.code !== 0 && typeof parsed?.code === "number") {
              reason = `MiPushCode${parsed.code}`;
            }
          } else {
            if (!response.ok) {
              const value: unknown = await response.json().catch(() => null);
              if (
                value && typeof value === "object" && "reason" in value &&
                typeof value.reason === "string"
              ) reason = value.reason.slice(0, 100);
            }
            outcome = classifyApnsResponse(response.status, reason);
          }
        } catch (_) {
          reason = "transport_error";
        }
        await rpc<boolean>("complete_push_delivery", {
          p_delivery_id: claim.delivery_id,
          p_claim_id: claim.claim_id,
          p_outcome: outcome,
          p_error_code: reason,
          p_token: outcome === "dead" ? claim.token : null,
        });
        if (outcome === "sent") accepted++;
        else failed++;
      }
    };
    const miPushSettings = [
      Deno.env.get("MIPUSH_APP_SECRET"),
      Deno.env.get("MIPUSH_PACKAGE_NAME"),
      Deno.env.get("MIPUSH_CHANNEL_ID"),
    ];
    const miPushConfigured = miPushSettings.every(Boolean);
    if (miPushSettings.some(Boolean) && !miPushConfigured) {
      throw new Error("Mi Push configuration is incomplete");
    }
    if (!apnsConfigured && !miPushConfigured) {
      throw new Error("No push provider is configured");
    }

    if (apnsConfigured) {
      const environment = required("APNS_ENVIRONMENT");
      if (environment !== "sandbox" && environment !== "production") {
        throw new Error("Invalid APNS_ENVIRONMENT");
      }
      apnsConfiguration = {
        environment,
        jwt: await createApnsJwt(
          required("APNS_TEAM_ID"),
          required("APNS_KEY_ID"),
          required("APNS_PRIVATE_KEY"),
        ),
      };
    }
    let apnsClaims: Claim[] = [];
    if (apnsConfigured) {
      apnsClaims = await rpc<Claim[]>("claim_push_deliveries", {
        p_limit: 20,
        p_provider: "apns",
      });
      await dispatch("apns", apnsClaims);
    }

    let miPushClaims: Claim[] = [];
    if (miPushConfigured) {
      miPushClaims = await rpc<Claim[]>("claim_push_deliveries", {
        p_limit: 20,
        p_provider: "mipush",
      });
      await dispatch("mipush", miPushClaims);
    }
    return Response.json({
      claimed: apnsClaims.length + miPushClaims.length,
      accepted,
      failed,
      apns_configured: apnsConfigured,
      mipush_configured: miPushConfigured,
    });
  } catch (_) {
    // Never log device tokens, key material, message IDs or request bodies.
    return Response.json({ error: "push_worker_unavailable" }, { status: 503 });
  }
});
