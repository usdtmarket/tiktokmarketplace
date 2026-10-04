import { createClient, type SupabaseClient, type User } from "npm:@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, idempotency-key",
  "Access-Control-Allow-Methods": "GET,POST,PATCH,DELETE,OPTIONS",
};

export function json(data: unknown, status = 200, extra: Record<string,string> = {}) {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, "Content-Type": "application/json", ...extra } });
}
export function error(code: string, message: string, status = 400, details?: unknown) { return json({ error: { code, message, details: details ?? null } }, status); }
export function options() { return new Response("ok", { headers: corsHeaders }); }
export function clients(req: Request) {
  const url = Deno.env.get("SUPABASE_URL")!;
  const publishableKeys = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}");
  const secretKeys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
  const publishable = publishableKeys.default; const secret = secretKeys.default;
  if (!publishable || !secret) throw new Error("SUPABASE_KEYS_NOT_CONFIGURED");
  const auth = req.headers.get("Authorization") ?? "";
  const userClient = createClient(url, publishable, { global: { headers: { Authorization: auth } } });
  const adminClient = createClient(url, secret); return { userClient, adminClient };
}
export async function requireUser(req: Request, client: SupabaseClient): Promise<User> {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) throw new Error("AUTH_REQUIRED");
  const { data, error: authError } = await client.auth.getUser(token);
  if (authError || !data.user) throw new Error("AUTH_INVALID"); return data.user;
}
export async function body(req: Request) { try { return await req.json(); } catch { throw new Error("INVALID_JSON"); } }
export function mapError(e: unknown) {
  const message = e instanceof Error ? e.message : String(e);
  if (message === "AUTH_REQUIRED") return error("AUTH_REQUIRED", "Authentication required", 401);
  if (message === "AUTH_INVALID") return error("AUTH_INVALID", "Invalid authentication", 401);
  if (message === "INVALID_JSON") return error("INVALID_JSON", "Invalid JSON body", 400);
  if (message === "SUPABASE_KEYS_NOT_CONFIGURED") return error("SERVER_MISCONFIGURED", "Server authentication keys are not configured", 503);
  return error("INTERNAL_ERROR", "Unexpected server error", 500);
}