import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization,content-type","Access-Control-Allow-Methods":"POST,OPTIONS"};
const out=(x:any,status=200)=>new Response(JSON.stringify(x),{status,headers:{"Content-Type":"application/json",...cors}});
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return out({error:{code:"METHOD_NOT_ALLOWED",message:"POST required"}},405);
 try{
  const url=Deno.env.get("SUPABASE_URL")!,anon=Deno.env.get("SUPABASE_ANON_KEY")!,service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const token=(req.headers.get("Authorization")||"").replace(/^Bearer\s+/i,"");if(!token)return out({error:{code:"UNAUTHORIZED",message:"Authentication required"}},401);
  const auth=createClient(url,anon,{global:{headers:{Authorization:`Bearer ${token}`}}});const {data:{user},error:ue}=await auth.auth.getUser();if(ue||!user)return out({error:{code:"UNAUTHORIZED",message:"Invalid session"}},401);
  const admin=createClient(url,service);const b=await req.json().catch(()=>null);const listingId=String(b?.listing_id||"");if(!listingId)return out({error:{code:"VALIDATION_ERROR",message:"listing_id is required"}},422);
  const {data:l,error:le}=await admin.from("listings").select("id,owner_user_id,business_id,status,deleted_at").eq("id",listingId).maybeSingle();if(le)throw le;if(!l||l.status!=="published"||l.deleted_at)return out({error:{code:"NOT_FOUND",message:"Published listing not found"}},404);
  let target=l.owner_user_id;if(l.business_id){const {data:biz,error:be}=await admin.from("businesses").select("owner_user_id").eq("id",l.business_id).maybeSingle();if(be)throw be;if(biz?.owner_user_id)target=biz.owner_user_id;}if(target===user.id)return out({error:{code:"INVALID_TARGET",message:"Cannot contact yourself"}},422);
  const {data:existing,error:ee}=await admin.from("conversations").select("id").eq("listing_id",listingId).eq("type","listing");if(ee)throw ee;
  let cid:string|undefined;for(const c of existing||[]){const {data:m}=await admin.from("conversation_members").select("user_id").eq("conversation_id",c.id);const ids=(m||[]).map((x:any)=>x.user_id);if(ids.length===2&&ids.includes(user.id)&&ids.includes(target)){cid=c.id;break;}}
  if(!cid){const {data:c,error:ce}=await admin.from("conversations").insert({type:"listing",listing_id:listingId}).select("id").single();if(ce)throw ce;cid=c.id;const {error:me}=await admin.from("conversation_members").insert([{conversation_id:cid,user_id:user.id},{conversation_id:cid,user_id:target}]);if(me)throw me;}
  return out({conversation_id:cid,listing_id:listingId});
 }catch(e:any){return out({error:{code:"CONTACT_FAILED",message:e?.message||"Unable to start conversation"}},500)}
});