import { clients, json, options, mapError } from "./_shared/http.ts";
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return options();
  if (req.method !== "GET") return json({error:{code:"METHOD_NOT_ALLOWED",message:"GET required"}},405);
  try {
    const {userClient}=clients(req); const u=new URL(req.url);
    const raw=(u.searchParams.get("q")??"").trim().replace(/[^\p{L}\p{N}\s._-]/gu," ").slice(0,120);
    const q=raw.replace(/\\/g,"\\\\").replace(/%/g,"\\%").replace(/_/g,"\\_");
    const category=u.searchParams.get("category_id"); const limit=Math.min(Math.max(Number(u.searchParams.get("limit")??30),1),50);
    if(!q&&!category)return json({items:[],query:raw});
    let query=userClient.from("listings").select("id,title,description,price,currency,listing_type,transaction_type,availability_status,verification_status,trust_score,category_id,city_id,business_id,location_id,published_at,categories(name,slug),locations(address,latitude,longitude),businesses(name,trust_score)").eq("status","published").is("deleted_at",null).limit(limit);
    if(q)query=query.or(`title.ilike.%${q}%,description.ilike.%${q}%`); if(category)query=query.eq("category_id",category);
    const {data,error}=await query.order("trust_score",{ascending:false}); if(error)throw error;
    const items=(data??[]).map((x:any)=>({...x,category:x.categories?.name??"Autre",category_slug:x.categories?.slug??null,location:x.locations??null,business:x.businesses?.name??null,business_score:x.businesses?.trust_score??null}));
    return json({query:raw,items});
  }catch(e){return mapError(e)}
});