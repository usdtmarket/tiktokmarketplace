/** CITYFLOW CMI adapter boundary.
 * Intentionally provider-neutral until CMI merchant integration kit is supplied.
 * No CMI hashing/signature algorithm is guessed here.
 */
export type CmiMode = "test" | "live";
export interface CmiConfig { mode:CmiMode; merchantId:string; storeKey:string; gatewayUrl:string; signatureAlgorithm:string; }
export interface CmiCheckoutRequest { paymentId:string; amount:string; currency:string; orderReference:string; successUrl:string; failureUrl:string; callbackUrl:string; customerEmail?:string; metadata?:Record<string,string>; }
export interface CmiCheckoutPayload { merchantId:string; gatewayUrl:string; fields:Record<string,string>; }
export function loadCmiConfig(env=Deno.env):CmiConfig {
 const mode=(env.get("CMI_MODE")??"test") as CmiMode; const merchantId=env.get("CMI_MERCHANT_ID")??""; const storeKey=env.get("CMI_STORE_KEY")??""; const gatewayUrl=env.get("CMI_GATEWAY_URL")??""; const signatureAlgorithm=env.get("CMI_SIGNATURE_ALGORITHM")??"";
 if(!merchantId||!storeKey||!gatewayUrl||!signatureAlgorithm)throw new Error("CMI_PROVIDER_NOT_CONFIGURED");
 if(mode!=="test"&&mode!=="live")throw new Error("CMI_INVALID_MODE"); return {mode,merchantId,storeKey,gatewayUrl,signatureAlgorithm};
}
export function buildCmiCheckoutPayload(config:CmiConfig,req:CmiCheckoutRequest):CmiCheckoutPayload {
 if(!/^[A-Z]{3}$/.test(req.currency))throw new Error("CMI_INVALID_CURRENCY");
 if(!/^\d+(\.\d{1,2})?$/.test(req.amount))throw new Error("CMI_INVALID_AMOUNT");
 if(!req.paymentId||!req.orderReference)throw new Error("CMI_INVALID_REFERENCE");
 return {merchantId:config.merchantId,gatewayUrl:config.gatewayUrl,fields:{payment_id:req.paymentId,amount:req.amount,currency:req.currency,order_reference:req.orderReference,success_url:req.successUrl,failure_url:req.failureUrl,callback_url:req.callbackUrl,...(req.customerEmail?{customer_email:req.customerEmail}:{}),...(req.metadata?{metadata:JSON.stringify(req.metadata)}:{})}};
}
export function assertCmiWebhookReady(config:CmiConfig):void { if(!config.signatureAlgorithm||!config.storeKey)throw new Error("CMI_WEBHOOK_CRYPTO_NOT_CONFIGURED"); }