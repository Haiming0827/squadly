-- CloudBase requires explicit GRANTs in addition to the RLS policies copied
-- from the legacy schema. Keep user-facing writes limited to feature tables
-- whose policies enforce squad membership or ownership.
GRANT USAGE ON SCHEMA public TO authenticated, service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.workout_plans,
  public.daily_tasks,
  public.check_ins,
  public.public_funds,
  public.fund_transactions,
  public.private_assets,
  public.shared_expenses,
  public.watchlist_items,
  public.travel_plans,
  public.food_spots,
  public.food_votes
TO authenticated;

-- The trusted delivery worker uses a server-only API Key mapped to
-- service_role. This key must never be included in a Flutter build.
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;
