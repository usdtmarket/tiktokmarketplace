import { clients, json, options, mapError } from "./_shared/http.ts";
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return options();
  try {
    const { userClient } = clients(req); const u = new URL(req.url);
    const limit = Math.min(Math.max(Number(u.searchParams.get("limit") ?? 20), 1), 50); const city = u.searchParams.get("city") ?? "Martil";
    const {data,error}=await userClient.from("listings").select("id,title,description,listing_type,transaction_type,price,currency,price_unit,status,verification_status,availability_status,trust_score,published_at,city_id,category_id,location_id,business_id,owner_user_id,categories(name,slug),locations(address,latitude,longitude),businesses(name,trust_score),videos(id,caption,views_count,likes_count,quality_score,content_score,published_at,media_assets(thumbnail_url))").eq("status","published").is("deleted_at",null).order("published_at",{ascending:false}).limit(limit);
    if(error)throw error;
    const items=(data??[]).map((x:any)=>({...x,category:x.categories?.name??"Autre",category_slug:x.categories?.slug??null,location:x.locations??null,business:x.businesses?.name??null,business_score:x.businesses?.trust_score??null}));
    return json({city,items,next_cursor:null});
  }catch(e){return mapError(e)}
});