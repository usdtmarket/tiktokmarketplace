import {clients,body,json,options,requireUser,mapError} from "./_shared/http.ts";
Deno.serve(async(req)=>{
  if(req.method==="OPTIONS")return options();
  if(req.method!=="POST")return json({error:{code:"METHOD_NOT_ALLOWED",message:"POST required"}},405);
  try{
    const {userClient}=clients(req);const user=await requireUser(req,userClient);const b=await body(req);
    const listingId=String(b?.listing_id??"");const mediaType=b?.media_type==="video"?"video":"image";const mime=String(b?.mime_type??"");
    const allowed=mediaType==="video"?["video/mp4","video/quicktime","video/webm"]:["image/jpeg","image/png","image/webp"];
    if(!listingId||!mime||!allowed.includes(mime))return json({error:{code:"VALIDATION_ERROR",message:"listing_id and supported mime_type are required"}},422);
    const {data:listing,error:le}=await userClient.from("listings").select("id").eq("id",listingId).eq("owner_user_id",user.id).is("deleted_at",null).single();
    if(le||!listing)return json({error:{code:"FORBIDDEN",message:"Listing not owned by current user"}},403);
    const ext=mime.split("/")[1].replace("jpeg","jpg");const key="listings/"+listingId+"/"+user.id+"/"+crypto.randomUUID()+"."+ext;
    const {data,error}=await userClient.from("media_uploads").insert({owner_user_id:user.id,listing_id:listingId,storage_key:key,media_type:mediaType,mime_type:mime,file_size:b.file_size??null,status:"pending_upload"}).select().single();
    if(error)throw error;return json({upload_id:data.id,storage_key:key,status:data.status,next_step:"upload_to_storage_then_confirm"},201);
  }catch(e){return mapError(e)}
});