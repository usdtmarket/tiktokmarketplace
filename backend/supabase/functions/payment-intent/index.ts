import { clients, body, json, options, requireUser, mapError } from "../_shared/http.ts";
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return options();
 if(req.method!=="POST")return json({error:{code:"METHOD_NOT_ALLOWED",message:"POST required"}},405);
 try{
  const {userClient,adminClient}=clients(req); const user=await requireUser(req,userClient); const b=await body(req);
  if((!b.booking_id&&!b.order_id)||(b.booking_id&&b.order_id))return json({error:{code:"VALIDATION_ERROR",message:"Exactly one transaction reference is required"}},422);
  const {data,error}=await adminClient.rpc("cityflow_create_payment_record",{p_user_id:user.id,p_booking_id:b.booking_id??null,p_order_id:b.order_id??null});
  if(error)throw error;
  return json({payment:data,provider:"cmi",status:"pending_provider_configuration",next_step:"redirect_to_cmi_checkout_after_merchant_credentials_are_configured"},201);
 }catch(e){return mapError(e);}
});