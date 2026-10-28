-- Keep balances ledger-derived and fund metadata captain-managed.
-- Preserve existing rows; these grants apply only to future client writes.
REVOKE INSERT, UPDATE ON public.public_funds FROM authenticated;
GRANT INSERT (id, squad_id, name, fund_type, target_amount, created_by)
  ON public.public_funds TO authenticated;
GRANT UPDATE (name, fund_type, target_amount)
  ON public.public_funds TO authenticated;

DROP POLICY IF EXISTS public_funds_insert ON public.public_funds;
DROP POLICY IF EXISTS public_funds_update ON public.public_funds;
CREATE POLICY public_funds_insert ON public.public_funds
  FOR INSERT TO authenticated WITH CHECK (
    public.is_squad_captain(squad_id) AND created_by = auth.uid()
  );
CREATE POLICY public_funds_update ON public.public_funds
  FOR UPDATE TO authenticated USING (public.is_squad_captain(squad_id))
  WITH CHECK (public.is_squad_captain(squad_id));

-- Members may append their own ledger entries; approval identity is never
-- accepted from a client. The existing SECURITY DEFINER balance trigger keeps
-- its owner privileges and executes atomically with each ledger insert.
REVOKE INSERT ON public.fund_transactions FROM authenticated;
GRANT INSERT (id, fund_id, user_id, amount, description, transaction_date)
  ON public.fund_transactions TO authenticated;
