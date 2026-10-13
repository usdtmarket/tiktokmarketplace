import {clients,body,json,options,requireUser,mapError} from "./_shared/http.ts";
Deno.serve(async(req)=>{
  if(req.method==="OPTIONS")return options();
  if(req.method!=="POST")return json({error:{code:"METHOD_NOT_ALLOWED",message:"POST required"}},405);
  try{
    const {userClient,adminClient}=clients(req);const user=await requireUser(req,userClient);const b=await body(req);const id=String(b?.upload_id??"");
    if(!id)return json({error:{code:"VALIDATION_ERROR",message:"upload_id is required"}},422);
    const {data,error}=await userClient.from("media_uploads").select("*").eq("id",id).eq("owner_user_id",user.id).single();
    if(error||!data)return json({error:{code:"NOT_FOUND",message:"Upload not found"}},404);
    if(data.status!=="pending_upload")return json({upload_id:id,status:data.status});
    const parts=String(data.storage_key).split("/");
    if(parts.length<4||parts[0]!=="listings"||parts[2]!==user.id)return json({error:{code:"INVALID_STORAGE_KEY",message:"Invalid upload storage key"}},422);
    const folder=parts.slice(0,-1).join("/");const filename=parts[parts.length-1];
    const {data:objects,error:se}=await adminClient.storage.from("cityflow-media").list(folder,{limit:100,search:filename});
    if(se)throw se;const exists=Array.isArray(objects)&&objects.some((o:any)=>o.name===filename);
    if(!exists)return json({error:{code:"OBJECT_NOT_FOUND",message:"Uploaded object was not found in storage"},upload_id:id,status:data.status},409);
    const {data:u,error:ue}=await userClient.from("media_uploads").update({status:"pending_moderation"}).eq("id",id).eq("owner_user_id",user.id).eq("status","pending_upload").select().single();
    if(ue)throw ue;return json({upload_id:u.id,status:u.status,next_step:"moderation"});
  }catch(e){return mapError(e)}
});