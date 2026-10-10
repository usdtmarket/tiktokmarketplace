import { createClient } from "npm:@supabase/supabase-js@2";

const origin = Deno.env.get("CITYFLOW_ALLOWED_ORIGIN")?.trim() || "*";
const MAX_BODY_BYTES = 1024 * 1024;
const h = {
  "Access-Control-Allow-Origin": origin,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
  "Vary": "Origin",
};
const j = (d: unknown, s = 200) =>
  new Response(JSON.stringify(d), { status: s, headers: { ...h, "Content-Type": "application/json" } });

async function readJson(req: Request) {
  const length = Number(req.headers.get("content-length") ?? "0");
  if (Number.isFinite(length) && length > MAX_BODY_BYTES) throw new Error("PAYLOAD_TOO_LARGE");
  const text = await req.text();
  if (new TextEncoder().encode(text).byteLength > MAX_BODY_BYTES) throw new Error("PAYLOAD_TOO_LARGE");
  try { return JSON.parse(text); } catch { throw new Error("INVALID_JSON"); }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: h });
  if (req.method !== "POST") return j({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);

  try {
    const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
    if (!token) return j({ error: { code: "AUTH_REQUIRED" } }, 401);

    const url = Deno.env.get("SUPABASE_URL");
    const secret = Deno.env.get("SUPABASE_SECRET_KEYS");
    if (!url || !secret) return j({ error: { code: "SERVER_MISCONFIGURED" } }, 503);

    let key: string;
    try { key = JSON.parse(secret).default; } catch { return j({ error: { code: "SERVER_MISCONFIGURED" } }, 503); }
    if (!key) return j({ error: { code: "SERVER_MISCONFIGURED" } }, 503);

    const admin = createClient(url, key);
    const { data: authData } = await admin.auth.getUser(token);
    if (!authData.user) return j({ error: { code: "AUTH_INVALID" } }, 401);

    const { data: roles, error: roleError } = await admin
      .from("user_roles")
      .select("role,expires_at")
      .eq("user_id", authData.user.id);
    if (roleError) return j({ error: { code: "ROLE_LOOKUP_FAILED" } }, 500);

    const activeRoles = roles?.filter((x: { expires_at: string | null }) =>
      !x.expires_at || new Date(x.expires_at).getTime() > Date.now()
    ) ?? [];
    if (!activeRoles.some((x: { role: string }) => ["admin", "super_admin", "moderator"].includes(x.role))) {
      return j({ error: { code: "FORBIDDEN" } }, 403);
    }

    const body = await readJson(req);
    const uploadId = typeof body?.upload_id === "string" ? body.upload_id.trim() : "";
    const decision = body?.decision;
    if (!uploadId || !["approve", "reject"].includes(decision)) {
      return j({ error: { code: "VALIDATION_ERROR" } }, 422);
    }

    const reason = typeof body.reason === "string" ? body.reason.trim() : "";
    if (decision === "reject" && reason.length < 8) {
      return j({ error: { code: "REASON_REQUIRED_MIN_8_CHARS" } }, 422);
    }
    const actorType = activeRoles.some((x: { role: string }) => ["admin", "super_admin"].includes(x.role))
      ? "admin"
      : "moderator";
    const { data, error } = await admin.rpc("cityflow_moderate_media_audited", {
      p_upload_id: uploadId,
      p_decision: decision,
      p_quality_score: body.quality_score ?? null,
      p_content_score: body.content_score ?? null,
      p_reason: reason || null,
      p_actor_id: authData.user.id,
      p_actor_type: actorType,
    });
    if (error) return j({ error: { code: "MODERATION_FAILED" } }, 400);

    return j(data);
  } catch (e) {
    const message = e instanceof Error ? e.message : "";
    if (message === "PAYLOAD_TOO_LARGE") return j({ error: { code: "PAYLOAD_TOO_LARGE" } }, 413);
    if (message === "INVALID_JSON") return j({ error: { code: "INVALID_JSON" } }, 400);
    return j({ error: { code: "INTERNAL_ERROR" } }, 500);
  }
});