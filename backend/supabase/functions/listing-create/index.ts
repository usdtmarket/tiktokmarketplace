import { clients, body, json, options, requireUser, mapError } from "../_shared/http.ts";
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return options();
  if (req.method !== "POST") return json({ error:{code:"METHOD_NOT_ALLOWED",message:"POST required"} },405);
  try {
    const { userClient } = clients(req); const user = await requireUser(req,userClient); const b = await body(req);
    const required = ["city_id","category_id","title","slug","listing_type","transaction_type"];
    for (const k of required) if (!b?.[k]) return json({error:{code:"VALIDATION_ERROR",message:`${k} is required`}},422);
    const payload = { business_id:b.business_id ?? null, owner_user_id:user.id, city_id:b.city_id, category_id:b.category_id, location_id:b.location_id ?? null, title:b.title, slug:b.slug, description:b.description ?? null, listing_type:b.listing_type, transaction_type:b.transaction_type, price:b.price ?? null, currency:b.currency ?? "MAD", price_unit:b.price_unit ?? null, status:"pending_review", verification_status:"unverified", availability_status:b.availability_status ?? "available", inventory_quantity:b.inventory_quantity ?? null };
    const { data,error } = await userClient.from("listings").insert(payload).select().single();
    if (error) throw error; return json(data,201);
  } catch(e){ return mapError(e); }
});