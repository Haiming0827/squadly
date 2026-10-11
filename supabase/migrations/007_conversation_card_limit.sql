-- Enforce the same 1–6 authored-message limit as the card composer, including
-- on databases that already applied 003 before its RPC validation was fixed.
-- Preserve any immutable historical seven/eight-message cards rather than
-- blocking the migration; NOT VALID still checks every new row.
ALTER TABLE public.card_snapshots
  ADD CONSTRAINT card_conversation_message_count CHECK (
    CASE WHEN kind = 'conversation' THEN
      CASE WHEN jsonb_typeof(snapshot -> 'selected_message_ids') = 'array'
        THEN jsonb_array_length(snapshot -> 'selected_message_ids') BETWEEN 1 AND 6
        ELSE false
      END
    ELSE true END
  ) NOT VALID;
