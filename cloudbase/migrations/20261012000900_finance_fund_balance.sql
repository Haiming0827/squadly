-- Keep the denormalized public_funds balance in sync with its append-only
-- ledger. PostgreSQL applies the trigger in the same transaction as the row.
CREATE OR REPLACE FUNCTION update_public_fund_balance_from_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public_funds
  SET current_amount = current_amount + NEW.amount
  WHERE id = NEW.fund_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fund not found';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION update_public_fund_balance_from_transaction() FROM PUBLIC;

CREATE TRIGGER fund_transactions_update_balance
  AFTER INSERT ON fund_transactions
  FOR EACH ROW
  EXECUTE FUNCTION update_public_fund_balance_from_transaction();
