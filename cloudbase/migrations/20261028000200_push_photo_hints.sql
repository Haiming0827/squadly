-- Versioned claim projection for content-free photo synchronization hints.
-- Keep V1 available for rollback; only the server worker may execute V2.
CREATE FUNCTION public.claim_push_deliveries_v2(
 p_limit int DEFAULT 20,p_provider text DEFAULT 'apns'
) RETURNS TABLE (
 delivery_id bigint,claim_id uuid,message_id uuid,squad_id uuid,
 provider text,token text,message_kind text
) LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT c.delivery_id,c.claim_id,c.message_id,c.squad_id,c.provider,c.token,m.kind
 FROM public.claim_push_deliveries(p_limit,p_provider) c
 JOIN public.squad_messages m ON m.id=c.message_id AND m.squad_id=c.squad_id;
$$;
REVOKE ALL ON FUNCTION public.claim_push_deliveries_v2(int,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_push_deliveries_v2(int,text) TO service_role;
