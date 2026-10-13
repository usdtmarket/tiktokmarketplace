import {clients,body,json,options,mapError} from "./_shared/http.ts";
Deno.serve(async(req)=>{
  if(req.method==="OPTIONS")return options();
  if(req.method!=="POST")return json({error:{code:"METHOD_NOT_ALLOWED",message:"POST required"}},405);
  try{
    const admin=clients();const b=await body(req);const listingId=String(b?.listing_id??"");
    if(!listingId)return json({error:{code:"VALIDATION_ERROR",message:"listing_id is required"}},422);
    const {data:listing,error:le}=await admin.from("listings").select("id,status,deleted_at").eq("id",listingId).maybeSingle();
    if(le)throw le;if(!listing||listing.status!=="published"||listing.deleted_at)return json({error:{code:"NOT_FOUND",message:"Published listing not found"}},404);
    const {data:rows,error:re}=await admin.from("listing_media").select("id,media_type,sort_order,is_primary,media_assets!inner(id,storage_key,mime_type,status)").eq("listing_id",listingId).eq("media_assets.status","ready").order("is_primary",{ascending:false}).order("sort_order",{ascending:true}).limit(12);
    if(re)throw re;const media=[];
    for(const row of rows??[]){const asset=(row as any).media_assets;if(!asset?.storage_key)continue;const{data:signed,error:se}=await admin.storage.from("cityflow-media").createSignedUrl(asset.storage_key,600);if(se||!signed?.signedUrl)continue;media.push({id:row.id,media_type:row.media_type,mime_type:asset.mime_type,url:signed.signedUrl});}
    return json({listing_id:listingId,media,expires_in:600});
  }catch(e){return mapError(e)}
});