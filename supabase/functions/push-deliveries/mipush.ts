export type MiPushOutcome = "sent" | "retry" | "dead";

export type MiPushResponse = {
  code?: unknown;
  invalid_target?: unknown;
  data?: { invalid_target?: unknown } | null;
};

export function miPushRequest(
  registrationId: string,
  appSecret: string,
  packageName: string,
  channelId: string,
): { url: string; init: RequestInit } {
  if (!registrationId || registrationId.length > 512) {
    throw new Error("Invalid Mi Push registration ID");
  }
  if (!appSecret || !packageName || !channelId) {
    throw new Error("Mi Push server configuration is incomplete");
  }

  const form = new URLSearchParams({
    registration_id: registrationId,
    restricted_package_name: packageName,
    title: "小分队",
    description: "你的小队有新消息",
    payload: JSON.stringify({ type: "sync" }),
    time_to_live: "86400",
  });
  form.set("extra.channel_id", channelId);

  return {
    url: "https://api.xmpush.xiaomi.com/v2/message/regid",
    init: {
      method: "POST",
      headers: {
        Authorization: `key=${appSecret}`,
        "content-type": "application/x-www-form-urlencoded; charset=utf-8",
      },
      body: form.toString(),
    },
  };
}

export function classifyMiPushResponse(
  status: number,
  response: MiPushResponse | null,
): MiPushOutcome {
  if (status < 200 || status >= 300 || response?.code !== 0) return "retry";
  const invalidTarget = response.invalid_target ?? response.data?.invalid_target;
  if (typeof invalidTarget === "number" && invalidTarget > 0) return "dead";
  return "sent";
}
