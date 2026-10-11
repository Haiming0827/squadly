-- Supabase's pgTAP runner executes each .sql file in a fresh psql process.
-- Keep these ordered contracts in one TAP file so they share fixtures, then
-- roll all synthetic data back. The included scripts must never target staging.
BEGIN;
SELECT plan(7);

\ir parts/registration_contract.inc
SELECT pass('registration, invitation, conversation, card, and route contracts');

\ir parts/security_contract.inc
SELECT pass('API grants, RLS, and invitation denial contracts');

\ir parts/profile_nickname_contract.inc
SELECT pass('public nickname and private contact contracts');

\ir parts/notification_contract.inc
SELECT pass('message outbox and per-user push token contracts');

\ir parts/push_delivery_contract.inc
SELECT pass('server push lease, idempotency, and invalid-token contracts');

\ir parts/timeline_paging_contract.inc
SELECT pass('multi-page offline timeline contract');

\ir parts/conversation_card_limit_contract.inc
SELECT pass('conversation card selection limit contract');

SELECT * FROM finish();
ROLLBACK;
